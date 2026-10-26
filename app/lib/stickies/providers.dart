// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/headless_config.dart';
import '../core/providers.dart';
import '../core/sync/sync_messages.dart';
import '../core/sync/sync_worker_client.dart';
import '../explorer/providers.dart';
import '../l10n/app_localizations.dart';
import '../links/link_rename_service.dart';
import '../search/providers.dart';
import '../vault/providers.dart';
import 'android/overlay_bridge.dart';
import 'android/sticky_widget_sync.dart';
import 'board/board_controller.dart';
import 'data/open_note_bridge.dart';
import 'data/sticky_archiver.dart';
import 'data/sticky_edit_applier.dart';
import 'data/sticky_positions_store.dart';
import 'data/sticky_repository.dart';
import 'model/sticky.dart';
import 'model/sticky_color.dart';
import 'reminders/reminder_ledger.dart';
import 'reminders/reminder_scheduler.dart';
import 'windows/sticky_desktop_integration.dart';
import 'windows/sticky_hub.dart';
import 'windows/text_merger.dart';
import 'windows/window_bus.dart';

/// State of all active and archived stickies in the open vault.
final class StickiesState {
  const StickiesState({this.all = const [], this.archived = const []});

  /// Active sticky notes (not archived).
  final List<Sticky> all;

  /// Archived sticky notes.
  final List<Sticky> archived;

  /// Filters active stickies by [color].
  List<Sticky> byColor(StickyColor color) =>
      all.where((s) => s.meta.color == color).toList();

  /// Filters active stickies containing [tag].
  List<Sticky> byTag(String tag) =>
      all.where((s) => s.tags.contains(tag)).toList();
}

/// Riverpod Notifier broadcasting current stickies state.
final class StickiesNotifier extends Notifier<StickiesState> {
  @override
  StickiesState build() {
    final repo = ref.watch(stickyRepositoryProvider);
    final sub = repo.changes.listen((_) {
      state = StickiesState(all: repo.all, archived: repo.archived);
    });
    ref.onDispose(sub.cancel);
    return StickiesState(all: repo.all, archived: repo.archived);
  }
}

/// Provider supplying the [OpenNoteBridge] for the open vault.
final openNoteBridgeProvider = Provider<OpenNoteBridge>((ref) {
  final store = ref.watch(noteDocumentStoreProvider);
  final bridge = AppOpenNoteBridge(store);
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Provider supplying the [StickyRepository] instance for the open vault.
final stickyRepositoryProvider = Provider<StickyRepository>((ref) {
  final fs = ref.watch(vaultFsProvider);
  final search = ref.watch(searchEngineProvider);
  final vaultSettings = ref.watch(vaultSettingsProvider);
  final clock = ref.watch(clockProvider);
  final openNotes = ref.watch(openNoteBridgeProvider);

  final repo = StickyRepository(
    fs: fs,
    search: search,
    settings: StickySettingsView.fromVaultSettings(vaultSettings),
    openNotes: openNotes,
    clock: clock,
  );
  unawaited(repo.start());
  ref.onDispose(() => unawaited(repo.dispose()));
  return repo;
});

/// Provider exposing [StickiesState] with all/archived stickies and filter helpers.
final stickiesProvider = NotifierProvider<StickiesNotifier, StickiesState>(
  StickiesNotifier.new,
);

/// Provider supplying the [BoardController] and [BoardState] for the open vault.
final boardControllerProvider = NotifierProvider<BoardController, BoardState>(
  BoardController.new,
);

/// Provider supplying the [WindowBus] instance.
final windowBusProvider = Provider<WindowBus>((ref) {
  return const NoopWindowBus();
});

/// Provider supplying the [StickyPositionsStore] for the open vault and current device.
final stickyPositionsStoreProvider = Provider<StickyPositionsStore>((ref) {
  final fs = ref.watch(vaultFsProvider);
  final deviceId = ref.watch(appSettingsProvider).deviceId;
  final store = StickyPositionsStore(fs: fs, deviceId: deviceId);
  unawaited(store.load());
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
});

/// Provider supplying the [StickyHub] single writer instance for desktop.
final stickyHubProvider = Provider<StickyHub>((ref) {
  final bus = ref.watch(windowBusProvider);
  final repo = ref.watch(stickyRepositoryProvider);
  final openNotes = ref.watch(openNoteBridgeProvider);
  final positions = ref.watch(stickyPositionsStoreProvider);
  final clock = ref.watch(clockProvider);
  final appSettings = ref.watch(appSettingsProvider);

  final hub = StickyHub(
    bus: bus,
    repo: repo,
    openNotes: openNotes,
    merger: const SyncTextMerger(),
    positions: positions,
    conflictNamer: (path) => VaultPath(
      conflictCopyName(
        path,
        clock.now(),
        appSettings.deviceName,
        (p) => repo.byPath(p) != null,
      ),
    ),
    clock: clock,
    getAppSettings: () => ref.read(appSettingsProvider),
    updateAppSettings: (s) async {
      ref.read(appSettingsProvider.notifier).update((_) => s);
    },
    onNotify: (msg) {
      final key = ref.read(scaffoldMessengerKeyProvider);
      key.currentState?.showSnackBar(SnackBar(content: Text(msg)));
    },
  );

  unawaited(hub.start());
  ref.onDispose(() => unawaited(hub.dispose()));
  return hub;
});

/// Provider supplying the [StickyDesktopIntegration] instance for Windows desktop.
final stickyDesktopIntegrationProvider = Provider<StickyDesktopIntegration?>((
  ref,
) {
  if (kIsWeb || !Platform.isWindows) {
    return null;
  }

  final hotkey = ref.watch(globalHotkeyServiceProvider);
  final tray = ref.watch(trayServiceProvider);
  final hub = ref.watch(stickyHubProvider);
  final repo = ref.watch(stickyRepositoryProvider);
  final positions = ref.watch(stickyPositionsStoreProvider);
  final window = ref.watch(windowServiceProvider);
  final noteDocs = ref.watch(noteDocumentStoreProvider);
  final appSettings = ref.watch(appSettingsProvider);
  final vaultSettings = ref.watch(vaultSettingsProvider);

  final integration = StickyDesktopIntegration(
    globalHotkeyService: hotkey,
    trayService: tray,
    stickyHub: hub,
    stickyRepository: repo,
    stickyPositionsStore: positions,
    windowService: window,
    noteDocumentStore: noteDocs,
    appSettings: appSettings,
    vaultSettings: vaultSettings,
    onNotice: (msg) {
      final key = ref.read(scaffoldMessengerKeyProvider);
      key.currentState?.showSnackBar(SnackBar(content: Text(msg)));
    },
  );

  ref.onDispose(() => unawaited(integration.dispose()));
  return integration;
});

/// Provider supplying the [ReminderLedger] instance.
final reminderLedgerProvider = Provider<ReminderLedger>((ref) {
  final dir = ref.watch(appSupportDirectoryProvider);
  if (dir != null) {
    return FileReminderLedger(File(p.join(dir.path, 'reminders.json')));
  }
  return MemoryReminderLedger();
});

/// Provider managing sticky note reminder notifications for the open vault.
final reminderSchedulerProvider = Provider<ReminderScheduler?>((ref) {
  final session = ref.watch(vaultSessionProvider);
  if (session == null) return null;

  final notifications = ref.watch(notificationServiceProvider);
  final repo = ref.watch(stickyRepositoryProvider);
  final clock = ref.watch(clockProvider);
  final ledger = ref.watch(reminderLedgerProvider);
  final appSettings = ref.watch(appSettingsProvider);

  final scheduler = ReminderScheduler(
    notifications: notifications,
    repo: repo,
    vaultId: session.vaultId,
    location: tz.local,
    clock: clock,
    ledger: ledger,
    enabled: appSettings.remindersEnabled,
  );

  scheduler.start();
  unawaited(scheduler.reconcile());

  // Reconcile when a sync cycle finishes
  ref.listen<AsyncValue<SyncStatusSnapshot>>(
    syncStatusProvider(session.vaultId),
    (prev, next) {
      if (next.asData?.value.state == SyncUiState.idle) {
        unawaited(scheduler.reconcile());
      }
    },
  );

  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Provider keeping `<appSupportDir>/headless.json` synchronized whenever vault or settings change.
final headlessConfigSyncProvider = Provider<void>((ref) {
  final session = ref.watch(vaultSessionProvider);
  if (session == null) return;
  final vaultSettings = ref.watch(vaultSettingsProvider);
  final appSettings = ref.watch(appSettingsProvider);
  final dir = ref.watch(appSupportDirectoryProvider);
  if (dir == null) return;

  final config = HeadlessConfig.fromSession(
    session: session,
    vaultSettings: vaultSettings,
    appSettings: appSettings,
  );
  unawaited(
    config.save(File(p.join(dir.path, HeadlessConfig.defaultFileName))),
  );
});

/// Provider keeping Android home-screen widgets synchronized with sticky changes.
final stickyWidgetSyncProvider = Provider<StickyWidgetSync?>((ref) {
  if (kIsWeb || !Platform.isAndroid) return null;

  final session = ref.watch(vaultSessionProvider);
  if (session == null) return null;

  final repo = ref.watch(stickyRepositoryProvider);
  final homeWidgets = ref.watch(homeWidgetServiceProvider);

  final sync = StickyWidgetSync(
    repo: repo,
    homeWidgets: homeWidgets,
    vaultId: session.vaultId,
  );
  sync.start();

  // Also reconcile when a sync cycle finishes
  ref.listen<AsyncValue<SyncStatusSnapshot>>(
    syncStatusProvider(session.vaultId),
    (prev, next) {
      if (next.asData?.value.state == SyncUiState.idle) {
        unawaited(sync.syncNow());
      }
    },
  );

  ref.onDispose(sync.dispose);
  return sync;
});

/// Provider supplying the [StickyEditApplier] instance for coordinating multi-source edits.
final stickyEditApplierProvider = Provider<StickyEditApplier>((ref) {
  final repo = ref.watch(stickyRepositoryProvider);
  final openNotes = ref.watch(openNoteBridgeProvider);
  final clock = ref.watch(clockProvider);
  final appSettings = ref.watch(appSettingsProvider);

  return StickyEditApplier(
    repo: repo,
    openNotes: openNotes,
    merger: const SyncTextMerger(),
    conflictNamer: (path) => VaultPath(
      conflictCopyName(
        path,
        clock.now(),
        appSettings.deviceName,
        (p) => repo.byPath(p) != null,
      ),
    ),
  );
});

/// Provider managing the Android floating sticky bubble bridge.
final overlayBridgeProvider = Provider<OverlayBridge?>((ref) {
  if (kIsWeb || !Platform.isAndroid) return null;

  final session = ref.watch(vaultSessionProvider);
  if (session == null) return null;

  final overlayService = ref.watch(overlayServiceProvider);
  final repo = ref.watch(stickyRepositoryProvider);
  final openNotes = ref.watch(openNoteBridgeProvider);
  final applier = ref.watch(stickyEditApplierProvider);

  final bridge = OverlayBridge(
    overlayService: overlayService,
    repo: repo,
    openNotes: openNotes,
    applier: applier,
  );

  bridge.start();
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Provider supplying the [StickyArchiver] instance for auto-archiving expired stickies.
final stickyArchiverProvider = Provider<StickyArchiver?>((ref) {
  final session = ref.watch(vaultSessionProvider);
  if (session == null) return null;

  final repo = ref.watch(stickyRepositoryProvider);
  final renameService = ref.watch(linkRenameServiceProvider);
  final clock = ref.watch(clockProvider);
  final vaultSettings = ref.watch(vaultSettingsProvider);

  final archiver = StickyArchiver(
    repo: repo,
    rename: (from, to) async {
      await renameService.renameOrMove(from, to);
    },
    clock: clock,
    stickyFolder: vaultSettings.stickyFolder,
    showSnackbar: (count, archiveFolder) {
      final smKey = ref.read(scaffoldMessengerKeyProvider);
      final context = smKey.currentContext;
      if (context != null) {
        final l10n = AppLocalizations.of(context);
        smKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(l10n.stickyArchivedCount(count)),
            action: SnackBarAction(
              label: l10n.stickyArchivedShow,
              onPressed: () {
                ref
                    .read(explorerExpandedProvider.notifier)
                    .expandAncestors(archiveFolder);
                ref
                    .read(explorerExpandedProvider.notifier)
                    .expand(archiveFolder);
                ref
                    .read(explorerSelectedProvider.notifier)
                    .select(archiveFolder);
              },
            ),
          ),
        );
      }
    },
  );

  archiver.start();
  ref.onDispose(archiver.dispose);
  return archiver;
});
