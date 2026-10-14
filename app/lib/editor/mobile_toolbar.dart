// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/providers.dart';
import '../commands/tephra_command.dart';
import '../l10n/app_localizations.dart';
import 'editor_controller.dart';
import 'providers.dart';

const List<String> _mobileToolbarCommandIds = [
  'editor.toggle-bold',
  'editor.toggle-italic',
  'editor.cycle-heading',
  'editor.toggle-bullet-list',
  'editor.toggle-numbered-list',
  'editor.toggle-task',
  'editor.insert-link',
  'editor.toggle-code',
  'editor.toggle-quote',
  'editor.insert-attachment',
  'editor.undo',
  'editor.redo',
  'editor.outdent-list',
  'editor.indent-list',
];

/// A 48 dp mobile keyboard accessory toolbar providing touch shortcuts for markdown editing.
class MobileToolbar extends ConsumerWidget {
  const MobileToolbar({super.key = const Key('mobile.toolbar')});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final registry = ref.watch(commandRegistryProvider);
    final controller = ref.watch(activeEditorProvider);

    final hideCmd = registry.byId('editor.hide-keyboard');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final id in _mobileToolbarCommandIds)
                      _buildToolbarButton(
                        context,
                        ref,
                        registry.byId(id),
                        controller,
                        l10n,
                      ),
                  ],
                ),
              ),
              if (hideCmd != null && (hideCmd.isAvailable?.call(ref) ?? true))
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  child: _buildButtonWidget(
                    context,
                    ref,
                    hideCmd,
                    l10n,
                    isEnabled: true,
                    icon: Icons.keyboard_hide,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton(
    BuildContext context,
    WidgetRef ref,
    TephraCommand? cmd,
    EditorController? controller,
    AppLocalizations l10n,
  ) {
    if (cmd == null) return const SizedBox.shrink();
    if (controller == null) return const SizedBox.shrink();

    final isUndo = cmd.id == 'editor.undo';
    final isRedo = cmd.id == 'editor.redo';

    if (!isUndo && !isRedo) {
      final available = cmd.isAvailable?.call(ref) ?? true;
      if (!available) return const SizedBox.shrink();
    }

    bool isEnabled = true;
    if (isUndo) {
      isEnabled = controller.canUndo;
    } else if (isRedo) {
      isEnabled = controller.canRedo;
    }

    return _buildButtonWidget(
      context,
      ref,
      cmd,
      l10n,
      isEnabled: isEnabled,
      icon: cmd.icon,
    );
  }

  Widget _buildButtonWidget(
    BuildContext context,
    WidgetRef ref,
    TephraCommand cmd,
    AppLocalizations l10n, {
    required bool isEnabled,
    IconData? icon,
  }) {
    return ExcludeFocus(
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          key: Key('toolbar.${cmd.id}'),
          icon: Icon(icon ?? Icons.extension),
          tooltip: cmd.label(l10n),
          onPressed: isEnabled ? () => cmd.run(ref, context) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
            maxWidth: 48,
            maxHeight: 48,
          ),
        ),
      ),
    );
  }
}
