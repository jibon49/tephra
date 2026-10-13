// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/providers.dart';
import 'providers.dart';
import 'shortcut_codec.dart';

class CommandIntent extends Intent {
  const CommandIntent(this.id);
  final String id;
}

class CommandAction extends Action<CommandIntent> {
  CommandAction(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  @override
  bool isEnabled(CommandIntent intent) {
    final registry = ref.read(commandRegistryProvider);
    final cmd = registry.byId(intent.id);
    if (cmd == null) return false;
    return cmd.isAvailable?.call(ref) ?? true;
  }

  @override
  Object? invoke(CommandIntent intent) {
    final registry = ref.read(commandRegistryProvider);
    final cmd = registry.byId(intent.id);
    if (cmd == null) return null;
    final available = cmd.isAvailable?.call(ref) ?? true;
    if (!available) return null;

    cmd.run(ref, context);
    ref.read(appSettingsProvider.notifier).touchCommand(cmd.id);
    return null;
  }
}

class HotkeyHost extends ConsumerWidget {
  const HotkeyHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(commandRegistryProvider);
    final overrides = ref.watch(hotkeyOverridesProvider);
    final shortcutsMap = registry.shortcutsMap(overrides);

    final shortcuts = <ShortcutActivator, Intent>{};
    for (final entry in shortcutsMap.entries) {
      final activator = parseShortcut(entry.key);
      if (activator != null) {
        shortcuts[activator] = CommandIntent(entry.value);
      }
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          CommandIntent: CommandAction(ref, context),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
