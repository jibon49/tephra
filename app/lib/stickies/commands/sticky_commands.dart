// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../capture/capture_screen.dart';
import '../../capture/share_intake.dart';
import '../../commands/command_registry.dart';
import '../../commands/tephra_command.dart';
import '../../core/platform/platform_providers.dart';
import '../../vault/providers.dart';
import '../../workspace/open_file.dart';
import '../../workspace/providers.dart';
import '../board/sticky_board_screen.dart';
import '../model/sticky.dart';
import '../model/sticky_frontmatter.dart';
import '../model/sticky_meta.dart';
import '../providers.dart';
import '../ui/sticky_color_picker.dart';
import '../ui/sticky_expiry_dialog.dart';
import '../ui/sticky_reminder_dialog.dart';

/// Registers all sticky notes and capture commands with the [CommandRegistry].
void registerStickyCommands(CommandRegistry registry) {
  // Check if Ctrl+Shift+N is already assigned in the registry
  final bool hasCtrlShiftNConflict = registry.all.any(
    (c) => c.defaultShortcuts.any(
      (s) =>
          s.trigger == LogicalKeyboardKey.keyN &&
          s.control &&
          s.shift &&
          !s.alt &&
          !s.meta,
    ),
  );

  // 1. sticky.new
  registry.register(
    TephraCommand(
      id: 'sticky.new',
      label: (l10n) => l10n.stickyCommandNew,
      icon: Icons.note_add_outlined,
      defaultShortcuts: (Platform.isWindows && !hasCtrlShiftNConflict)
          ? const [
              SingleActivator(
                LogicalKeyboardKey.keyN,
                control: true,
                shift: true,
              ),
            ]
          : const [],
      isAvailable: (ref) => ref.watch(vaultSessionProvider) != null,
      run: (ref, context) async {
        final repo = ref.read(stickyRepositoryProvider);
        final sticky = await repo.create();
        openFile(ref, sticky.path);
      },
    ),
  );

  // 2. sticky.pin-note
  registry.register(
    TephraCommand(
      id: 'sticky.pin-note',
      label: (l10n) => l10n.stickyCommandPinNote,
      icon: Icons.push_pin_outlined,
      isAvailable: (ref) {
        final activePath = ref.watch(activeNotePathProvider);
        if (activePath == null) return false;
        if (activePath.extension.toLowerCase() != 'md') return false;
        final sticky = _activeSticky(ref, activePath);
        return sticky == null;
      },
      run: (ref, context) async {
        final activePath = ref.read(activeNotePathProvider);
        if (activePath == null) return;
        final repo = ref.read(stickyRepositoryProvider);
        await repo.patch(
          activePath,
          StickyPatch(sticky: true, color: repo.settings.defaultColor),
        );
      },
    ),
  );

  // 3. sticky.unpin
  registry.register(
    TephraCommand(
      id: 'sticky.unpin',
      label: (l10n) => l10n.stickyCommandUnpin,
      icon: Icons.push_pin,
      isAvailable: (ref) {
        final activePath = ref.watch(activeNotePathProvider);
        if (activePath == null) return false;
        return _activeSticky(ref, activePath) != null;
      },
      run: (ref, context) async {
        final activePath = ref.read(activeNotePathProvider);
        if (activePath == null) return;
        final repo = ref.read(stickyRepositoryProvider);
        await repo.patch(activePath, const StickyPatch(removeAll: true));
      },
    ),
  );

  // 4. sticky.set-color
  registry.register(
    TephraCommand(
      id: 'sticky.set-color',
      label: (l10n) => l10n.stickyCommandSetColor,
      icon: Icons.palette_outlined,
      isAvailable: (ref) {
        final activePath = ref.watch(activeNotePathProvider);
        if (activePath == null) return false;
        return _activeSticky(ref, activePath) != null;
      },
      run: (ref, context) async {
        final activePath = ref.read(activeNotePathProvider);
        if (activePath == null) return;
        final sticky = _activeSticky(ref, activePath);
        if (sticky == null) return;

        final picked = await showStickyColorPicker(
          context,
          initialColor: sticky.meta.color,
        );
        if (picked != null) {
          final repo = ref.read(stickyRepositoryProvider);
          await repo.patch(activePath, StickyPatch(color: picked));
        }
      },
    ),
  );

  // 5. sticky.lock
  registry.register(
    TephraCommand(
      id: 'sticky.lock',
      label: (l10n) => l10n.stickyCommandLock,
      icon: Icons.lock_outline,
      isAvailable: (ref) {
        final activePath = ref.watch(activeNotePathProvider);
        if (activePath == null) return false;
        return _activeSticky(ref, activePath) != null;
      },
      run: (ref, context) async {
        final activePath = ref.read(activeNotePathProvider);
        if (activePath == null) return;
        final sticky = _activeSticky(ref, activePath);
        if (sticky == null) return;

        final repo = ref.read(stickyRepositoryProvider);
        await repo.patch(activePath, StickyPatch(locked: !sticky.meta.locked));
      },
    ),
  );

  // 6. sticky.set-reminder
  registry.register(
    TephraCommand(
      id: 'sticky.set-reminder',
      label: (l10n) => l10n.stickyCommandSetReminder,
      icon: Icons.alarm,
      isAvailable: (ref) {
        final activePath = ref.watch(activeNotePathProvider);
        if (activePath == null) return false;
        return _activeSticky(ref, activePath) != null;
      },
      run: (ref, context) async {
        final activePath = ref.read(activeNotePathProvider);
        if (activePath == null) return;
        final sticky = _activeSticky(ref, activePath);
        if (sticky == null) return;

        final notifs = ref.read(notificationServiceProvider);
        final perm = await notifs.permissionState();
        if (!perm.notifications) {
          await notifs.requestNotificationPermission();
        }

        if (!context.mounted) return;
        final result = await showStickyReminderDialog(
          context,
          initialValue: sticky.meta.remind,
          exactAlarmsAllowed: perm.exactAlarms,
          onRequestExactAlarms: () => notifs.requestExactAlarmPermission(),
        );
        if (result != null) {
          final repo = ref.read(stickyRepositoryProvider);
          await repo.patch(activePath, StickyPatch(remind: result));
        }
      },
    ),
  );

  // 7. sticky.set-expiry
  registry.register(
    TephraCommand(
      id: 'sticky.set-expiry',
      label: (l10n) => l10n.stickyCommandSetExpiry,
      icon: Icons.event,
      isAvailable: (ref) {
        final activePath = ref.watch(activeNotePathProvider);
        if (activePath == null) return false;
        return _activeSticky(ref, activePath) != null;
      },
      run: (ref, context) async {
        final activePath = ref.read(activeNotePathProvider);
        if (activePath == null) return;
        final sticky = _activeSticky(ref, activePath);
        if (sticky == null) return;

        final result = await showDialog<Optional<LocalDate>>(
          context: context,
          builder: (ctx) =>
              StickyExpiryDialog(initialValue: sticky.meta.expire),
        );
        if (result != null) {
          final repo = ref.read(stickyRepositoryProvider);
          await repo.patch(activePath, StickyPatch(expire: result));
        }
      },
    ),
  );

  // 8. sticky.open-window (enabled in 04.9 / 04.14)
  registry.register(
    TephraCommand(
      id: 'sticky.open-window',
      label: (l10n) => l10n.stickyCommandOpenWindow,
      icon: Icons.open_in_new,
      isAvailable: (ref) {
        if (!Platform.isAndroid && !Platform.isWindows) return false;
        final activePath = ref.watch(activeNotePathProvider);
        if (activePath == null) return false;
        return _activeSticky(ref, activePath) != null;
      },
      run: (ref, context) async {
        final activePath = ref.read(activeNotePathProvider);
        if (activePath == null) return;
        if (Platform.isAndroid) {
          final bridge = ref.read(overlayBridgeProvider);
          if (bridge != null) {
            await bridge.openBubble(activePath);
          }
        } else if (Platform.isWindows) {
          final hub = ref.read(stickyHubProvider);
          await hub.open(activePath);
        }
      },
    ),
  );

  // 9. sticky.show-all (enabled in 04.9)
  registry.register(
    TephraCommand(
      id: 'sticky.show-all',
      label: (l10n) => l10n.stickyCommandShowAll,
      icon: Icons.visibility,
      isAvailable: (ref) =>
          Platform.isWindows && ref.watch(vaultSessionProvider) != null,
      run: (ref, context) async {
        if (Platform.isWindows) {
          await ref.read(stickyHubProvider).showAll();
        }
      },
    ),
  );

  // 10. sticky.hide-all (enabled in 04.9)
  registry.register(
    TephraCommand(
      id: 'sticky.hide-all',
      label: (l10n) => l10n.stickyCommandHideAll,
      icon: Icons.visibility_off,
      isAvailable: (ref) =>
          Platform.isWindows && ref.watch(vaultSessionProvider) != null,
      run: (ref, context) async {
        if (Platform.isWindows) {
          await ref.read(stickyHubProvider).hideAll();
        }
      },
    ),
  );

  // 11. sticky.board (enabled in 04.7)
  registry.register(
    TephraCommand(
      id: 'sticky.board',
      label: (l10n) => l10n.stickyCommandBoard,
      icon: Icons.dashboard_customize_outlined,
      isAvailable: (ref) => ref.watch(vaultSessionProvider) != null,
      run: (ref, context) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StickyBoardScreen()),
        );
      },
    ),
  );

  // 12. capture.quick-note (enabled in 04.15)
  registry.register(
    TephraCommand(
      id: 'capture.quick-note',
      label: (l10n) => l10n.captureCommandQuickNote,
      icon: Icons.flash_on,
      isAvailable: (ref) => ref.watch(vaultSessionProvider) != null,
      run: (ref, context) {
        final width = MediaQuery.sizeOf(context).width;
        if (width >= 840) {
          showDialog<void>(
            context: context,
            builder: (_) => const CaptureScreen(
              initialDraft: CaptureDraft(text: '', files: []),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CaptureScreen(
                initialDraft: CaptureDraft(text: '', files: []),
              ),
            ),
          );
        }
      },
    ),
  );
}

Sticky? _activeSticky(WidgetRef ref, VaultPath path) {
  final stickies = ref.watch(stickiesProvider);
  for (final s in stickies.all) {
    if (s.path == path) return s;
  }
  return null;
}
