// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../explorer/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../stickies/board/sticky_board_screen.dart';
import '../../stickies/providers.dart';
import '../../vault/note_tools/providers.dart';
import '../../vault/providers.dart';
import '../../vault/vault_opener.dart';
import '../../workspace/providers.dart';
import '../providers.dart';
import 'deep_link.dart';

final _logger = Logger('deep_links.router');

/// Consumes incoming deep links across platform services and dispatches them
/// to active vault workspace views and commands.
class DeepLinkRouter {
  DeepLinkRouter(this.ref);

  final Ref ref;
  final List<DeepLink> _pendingLinks = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _initialized = false;

  /// Optional hooks for testing or UI delegation.
  VoidCallback? onNewSticky;
  VoidCallback? onOpenBoard;
  VoidCallback? onCapture;

  /// Initializes deep link listeners across AppLinks, HomeWidget, notifications, and shortcuts.
  void init({AppLinks? appLinks}) {
    if (_initialized) return;
    _initialized = true;

    // Listen for when a vault session opens to flush any queued deep links.
    ref.listen<Object?>(vaultSessionProvider, (prev, next) {
      if (next != null && _pendingLinks.isNotEmpty) {
        _flushPending();
      }
    });

    // 1. AppLinks (Android and desktop URI streams)
    if (!kIsWeb) {
      final al = appLinks ?? AppLinks();
      _subscriptions.add(
        al.uriLinkStream.listen(
          (uri) => handleUri(uri),
          onError: (Object e) =>
              _logger.warning('AppLinks uriLinkStream error: $e'),
        ),
      );
      al
          .getInitialLink()
          .then((uri) {
            if (uri != null) handleUri(uri);
          })
          .catchError((Object e) {
            _logger.warning('AppLinks getInitialLink error: $e');
          });
    }

    // 2. HomeWidgetService launches
    final homeWidgetService = ref.read(homeWidgetServiceProvider);
    _subscriptions.add(
      homeWidgetService.widgetLaunches.listen(
        (uri) => handleUri(uri),
        onError: (Object e) =>
            _logger.warning('HomeWidget widgetLaunches error: $e'),
      ),
    );
    homeWidgetService
        .initialWidgetLaunch()
        .then((uri) {
          if (uri != null) handleUri(uri);
        })
        .catchError((Object e) {
          _logger.warning('HomeWidget initialWidgetLaunch error: $e');
        });

    // 3. NotificationService notification taps
    final notificationService = ref.read(notificationServiceProvider);
    _subscriptions.add(
      notificationService.taps.listen(
        (payload) => handlePayload(payload),
        onError: (Object e) =>
            _logger.warning('NotificationService taps error: $e'),
      ),
    );
    notificationService
        .launchPayload()
        .then((payload) {
          if (payload != null) handlePayload(payload);
        })
        .catchError((Object e) {
          _logger.warning('NotificationService launchPayload error: $e');
        });

    // 4. AppShortcutService
    final shortcutService = ref.read(appShortcutServiceProvider);
    try {
      shortcutService
          .init((shortcutId) async {
            switch (shortcutId) {
              case 'new-sticky':
                await route(const NewStickyLink());
                break;
              case 'daily':
                await route(const DailyLink());
                break;
              case 'new-note':
                final session = ref.read(vaultSessionProvider);
                if (session != null) {
                  final path = await ref
                      .read(noteCreatorProvider)
                      .createUntitled();
                  ref
                      .read(workspaceProvider.notifier)
                      .openPath(path, newTab: true);
                }
                break;
            }
          })
          .catchError((Object e) {
            _logger.fine('AppShortcutService init note: $e');
          });
    } catch (e) {
      _logger.fine('AppShortcutService init synchronous note: $e');
    }
  }

  /// Parses and routes a string payload from notifications or widgets.
  void handlePayload(String payload) {
    final uri = Uri.tryParse(payload.trim());
    if (uri != null) {
      handleUri(uri);
    }
  }

  /// Parses and routes a URI.
  void handleUri(Uri uri) {
    final link = DeepLink.parse(uri);
    if (link != null) {
      route(link);
    }
  }

  /// Routes [link] to the appropriate workspace view or command, queueing if no vault is open.
  Future<void> route(DeepLink link) async {
    final session = ref.read(vaultSessionProvider);
    if (session == null) {
      _pendingLinks.add(link);
      return;
    }

    final targetVault = link.vaultId;
    if (targetVault != null && targetVault != session.vaultId) {
      final opened = await _tryOpenRecentVault(targetVault);
      if (!opened) {
        _showVaultNotOnDeviceMessage();
        return;
      }
    }

    await _dispatch(link);
  }

  Future<bool> _tryOpenRecentVault(String vaultId) async {
    final appSettings = ref.read(appSettingsProvider);
    for (final recent in appSettings.recentVaults) {
      final file = File(p.join(recent.path, '.tephra', 'vault.json'));
      if (file.existsSync()) {
        try {
          final decoded = jsonDecode(file.readAsStringSync());
          if (decoded is Map && decoded['id'] == vaultId) {
            await VaultOpener(ref).open(recent.path);
            return true;
          }
        } catch (_) {}
      }
    }
    return false;
  }

  void _showVaultNotOnDeviceMessage() {
    final smKey = ref.read(scaffoldMessengerKeyProvider);
    final context = smKey.currentContext;
    final message = context != null
        ? AppLocalizations.of(context).vaultNotOnDevice
        : 'This note belongs to a vault that is not on this device.';
    smKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _flushPending() {
    final links = List<DeepLink>.from(_pendingLinks);
    _pendingLinks.clear();
    for (final link in links) {
      route(link);
    }
  }

  Future<void> _dispatch(DeepLink link) async {
    BuildContext? context;
    try {
      final smKey = ref.read(scaffoldMessengerKeyProvider);
      context = smKey.currentContext;
    } catch (_) {}

    switch (link) {
      case OpenNoteLink(:final path):
        ref.read(workspaceProvider.notifier).openPath(path, newTab: true);
        break;

      case CaptureLink():
        onCapture?.call();
        break;

      case NewStickyLink():
        if (onNewSticky != null) {
          onNewSticky!();
        } else {
          final repo = ref.read(stickyRepositoryProvider);
          final sticky = await repo.create();
          ref
              .read(workspaceProvider.notifier)
              .openPath(sticky.path, newTab: true);
        }
        break;

      case DailyLink():
        final clock = ref.read(clockProvider);
        await ref.read(dailyNotesServiceProvider).openOrCreate(clock.now());
        break;

      case BoardLink():
        if (onOpenBoard != null) {
          onOpenBoard!();
        } else if (context != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const StickyBoardScreen()),
          );
        }
        break;

      case WidgetConfigLink():
        // Handled in step 04.13 for sticky picker
        break;
    }
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}

final deepLinkRouterProvider = Provider<DeepLinkRouter>((ref) {
  final router = DeepLinkRouter(ref);
  ref.onDispose(() => router.dispose());
  return router;
});
