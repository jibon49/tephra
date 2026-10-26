// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/platform_providers.dart';
import '../core/platform/share_intent_service.dart';
import '../explorer/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import '../vault/vault_session.dart';
import 'capture_screen.dart';
import 'providers.dart';
import 'share_intake.dart';

/// Coordinates incoming share intents from other applications on Android,
/// routing them to [CaptureScreen] or queueing them until a vault opens.
final class ShareIntakeCoordinator {
  ShareIntakeCoordinator(this.ref);

  final Ref ref;
  StreamSubscription<List<SharedItem>>? _sub;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    final shareService = ref.read(shareIntentServiceProvider);

    // Initial share on startup
    shareService.initialShare().then((items) {
      if (items.isNotEmpty) {
        _handleIncomingShare(items, standaloneLaunch: true);
        shareService.markHandled();
      }
    });

    // Subsequent shares while app is running
    _sub = shareService.shares.listen((items) {
      if (items.isNotEmpty) {
        _handleIncomingShare(items, standaloneLaunch: false);
      }
    });

    // Listen for vault session opening to flush pending items
    ref.listen<VaultSession?>(vaultSessionProvider, (prev, next) {
      if (prev == null && next != null) {
        _flushPendingIfAny();
      }
    });
  }

  void _handleIncomingShare(
    List<SharedItem> items, {
    required bool standaloneLaunch,
  }) {
    final session = ref.read(vaultSessionProvider);
    if (session == null) {
      // Keep shared items in memory until a vault opens
      ref.read(pendingSharedItemsProvider.notifier).add(items);

      final smKey = ref.read(scaffoldMessengerKeyProvider);
      final context = smKey.currentContext;
      final msg = context != null
          ? AppLocalizations.of(context).captureNoVault
          : 'Open or create a vault first';
      smKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    _openCaptureScreen(items, standaloneLaunch: standaloneLaunch);
  }

  void _flushPendingIfAny() {
    final pending = ref.read(pendingSharedItemsProvider);
    if (pending.isNotEmpty) {
      ref.read(pendingSharedItemsProvider.notifier).clear();
      _openCaptureScreen(pending, standaloneLaunch: false);
    }
  }

  void _openCaptureScreen(
    List<SharedItem> items, {
    required bool standaloneLaunch,
  }) {
    final draft = draftFromShare(items);
    final navKey = ref.read(rootNavigatorKeyProvider);
    final context =
        navKey.currentContext ??
        ref.read(scaffoldMessengerKeyProvider).currentContext;
    if (context == null) return;

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    if (isDesktop) {
      showDialog<void>(
        context: context,
        builder: (_) => CaptureScreen(
          initialDraft: draft,
          isShare: true,
          standaloneLaunch: standaloneLaunch,
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CaptureScreen(
            initialDraft: draft,
            isShare: true,
            standaloneLaunch: standaloneLaunch,
          ),
        ),
      );
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
