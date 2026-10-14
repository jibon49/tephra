// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/command_registry.dart';
import '../commands/tephra_command.dart';
import 'attachment_actions.dart';
import 'helpers/block_format.dart';
import 'helpers/indentation.dart';
import 'helpers/inline_format.dart';
import 'helpers/line_moves.dart';
import 'providers.dart';

/// Registers all `editor.*` commands into [registry].
void registerEditorCommands(CommandRegistry registry) {
  bool editorAvailable(WidgetRef ref) => ref.read(activeEditorProvider) != null;

  registry.register(
    TephraCommand(
      id: 'editor.toggle-bold',
      label: (l10n) => l10n.commandEditorToggleBold,
      icon: Icons.format_bold,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyB, control: true),
      ],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(
          toggleInlineFormat(c.lines, c.engine.selection, InlineFormat.bold),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-italic',
      label: (l10n) => l10n.commandEditorToggleItalic,
      icon: Icons.format_italic,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyI, control: true),
      ],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(
          toggleInlineFormat(c.lines, c.engine.selection, InlineFormat.italic),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-strikethrough',
      label: (l10n) => l10n.commandEditorToggleStrikethrough,
      icon: Icons.format_strikethrough,
      defaultShortcuts: const [],
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(
          toggleInlineFormat(
            c.lines,
            c.engine.selection,
            InlineFormat.strikethrough,
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-highlight',
      label: (l10n) => l10n.commandEditorToggleHighlight,
      icon: Icons.highlight,
      defaultShortcuts: const [],
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(
          toggleInlineFormat(
            c.lines,
            c.engine.selection,
            InlineFormat.highlight,
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-code',
      label: (l10n) => l10n.commandEditorToggleCode,
      icon: Icons.code,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(
          toggleInlineFormat(c.lines, c.engine.selection, InlineFormat.code),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.insert-link',
      label: (l10n) => l10n.commandEditorInsertLink,
      icon: Icons.link,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyK, control: true),
      ],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(insertLink(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-bullet-list',
      label: (l10n) => l10n.commandEditorToggleBulletList,
      icon: Icons.format_list_bulleted,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(toggleBulletList(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-numbered-list',
      label: (l10n) => l10n.commandEditorToggleNumberedList,
      icon: Icons.format_list_numbered,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(toggleNumberedList(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-task',
      label: (l10n) => l10n.commandEditorToggleTask,
      icon: Icons.check_box_outlined,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.enter, control: true),
      ],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(toggleTaskStatus(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-quote',
      label: (l10n) => l10n.commandEditorToggleQuote,
      icon: Icons.format_quote,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(toggleQuote(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.cycle-heading',
      label: (l10n) => l10n.commandEditorCycleHeading,
      icon: Icons.title,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(cycleHeading(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.indent-list',
      label: (l10n) => l10n.commandEditorIndentList,
      icon: Icons.format_indent_increase,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(
          indentOnTab(
            c.lines,
            c.engine.selection,
            c.options,
            shift: false,
            forceLine: true,
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.outdent-list',
      label: (l10n) => l10n.commandEditorOutdentList,
      icon: Icons.format_indent_decrease,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(
          indentOnTab(
            c.lines,
            c.engine.selection,
            c.options,
            shift: true,
            forceLine: true,
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.undo',
      label: (l10n) => l10n.commandEditorUndo,
      icon: Icons.undo,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyZ, control: true),
      ],
      showInMobileToolbar: true,
      isAvailable: (ref) => ref.read(activeEditorProvider)?.canUndo ?? false,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.undo();
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.redo',
      label: (l10n) => l10n.commandEditorRedo,
      icon: Icons.redo,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyY, control: true),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
      ],
      showInMobileToolbar: true,
      isAvailable: (ref) => ref.read(activeEditorProvider)?.canRedo ?? false,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.redo();
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.find',
      label: (l10n) => l10n.commandEditorFind,
      icon: Icons.search,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyF, control: true),
      ],
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.findController.open(replace: false);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.replace',
      label: (l10n) => l10n.commandEditorReplace,
      icon: Icons.find_replace,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyH, control: true),
      ],
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.findController.open(replace: true);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.move-line-up',
      label: (l10n) => l10n.commandEditorMoveLineUp,
      icon: Icons.arrow_upward,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.arrowUp, alt: true),
      ],
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(moveLinesUp(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.move-line-down',
      label: (l10n) => l10n.commandEditorMoveLineDown,
      icon: Icons.arrow_downward,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.arrowDown, alt: true),
      ],
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(moveLinesDown(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.duplicate-line',
      label: (l10n) => l10n.commandEditorDuplicateLine,
      icon: Icons.content_copy,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true),
      ],
      isAvailable: editorAvailable,
      run: (ref, context) {
        final c = ref.read(activeEditorProvider);
        if (c == null) return;
        c.runPlan(duplicateLines(c.lines, c.engine.selection));
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.insert-attachment',
      label: (l10n) => l10n.commandEditorInsertAttachment,
      icon: Icons.attach_file,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) async {
        await pickAndInsertAttachment(context, ref);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.hide-keyboard',
      label: (l10n) => l10n.commandEditorHideKeyboard,
      icon: Icons.keyboard_hide,
      defaultShortcuts: const [],
      showInMobileToolbar: true,
      isAvailable: editorAvailable,
      run: (ref, context) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
  );
}
