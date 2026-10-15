// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../commands/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/vault_settings.dart';
import 'autocomplete_insertion.dart';

/// Context provided to a slash command when building its snippet.
final class SlashInput {
  const SlashInput({
    required this.now,
    required this.settings,
    this.isLineZero = false,
  });

  final DateTime now;
  final VaultSettings settings;
  final bool isLineZero;
}

/// Definition of a slash command item in the editor `/` menu.
final class SlashCommand {
  const SlashCommand({
    required this.id,
    required this.label,
    required this.keywords,
    required this.isBlock,
    required this.build,
    this.isAvailable,
  });

  final String id;
  final String Function(AppLocalizations) label;
  final List<String> keywords;
  final bool isBlock;
  final Snippet Function(SlashInput) build;
  final bool Function(Ref)? isAvailable;
}

/// Complete ordered list of standard slash commands.
final List<SlashCommand> defaultSlashCommands = [
  // Headings 1..6
  SlashCommand(
    id: 'heading1',
    label: (l10n) => l10n.slashHeading1,
    keywords: const ['h1', 'title'],
    isBlock: false,
    build: (_) => const Snippet('# '),
  ),
  SlashCommand(
    id: 'heading2',
    label: (l10n) => l10n.slashHeading2,
    keywords: const ['h2'],
    isBlock: false,
    build: (_) => const Snippet('## '),
  ),
  SlashCommand(
    id: 'heading3',
    label: (l10n) => l10n.slashHeading3,
    keywords: const ['h3'],
    isBlock: false,
    build: (_) => const Snippet('### '),
  ),
  SlashCommand(
    id: 'heading4',
    label: (l10n) => l10n.slashHeading4,
    keywords: const ['h4'],
    isBlock: false,
    build: (_) => const Snippet('#### '),
  ),
  SlashCommand(
    id: 'heading5',
    label: (l10n) => l10n.slashHeading5,
    keywords: const ['h5'],
    isBlock: false,
    build: (_) => const Snippet('##### '),
  ),
  SlashCommand(
    id: 'heading6',
    label: (l10n) => l10n.slashHeading6,
    keywords: const ['h6'],
    isBlock: false,
    build: (_) => const Snippet('###### '),
  ),

  // Callouts (13)
  SlashCommand(
    id: 'callout-note',
    label: (l10n) => l10n.slashCalloutNote,
    keywords: const ['callout', 'admonition', 'note'],
    isBlock: true,
    build: (_) => const Snippet('> [!note]\n> '),
  ),
  SlashCommand(
    id: 'callout-abstract',
    label: (l10n) => l10n.slashCalloutAbstract,
    keywords: const ['callout', 'admonition', 'abstract'],
    isBlock: true,
    build: (_) => const Snippet('> [!abstract]\n> '),
  ),
  SlashCommand(
    id: 'callout-info',
    label: (l10n) => l10n.slashCalloutInfo,
    keywords: const ['callout', 'admonition', 'info'],
    isBlock: true,
    build: (_) => const Snippet('> [!info]\n> '),
  ),
  SlashCommand(
    id: 'callout-todo',
    label: (l10n) => l10n.slashCalloutTodo,
    keywords: const ['callout', 'admonition', 'todo'],
    isBlock: true,
    build: (_) => const Snippet('> [!todo]\n> '),
  ),
  SlashCommand(
    id: 'callout-tip',
    label: (l10n) => l10n.slashCalloutTip,
    keywords: const ['callout', 'admonition', 'tip'],
    isBlock: true,
    build: (_) => const Snippet('> [!tip]\n> '),
  ),
  SlashCommand(
    id: 'callout-success',
    label: (l10n) => l10n.slashCalloutSuccess,
    keywords: const ['callout', 'admonition', 'success'],
    isBlock: true,
    build: (_) => const Snippet('> [!success]\n> '),
  ),
  SlashCommand(
    id: 'callout-question',
    label: (l10n) => l10n.slashCalloutQuestion,
    keywords: const ['callout', 'admonition', 'question'],
    isBlock: true,
    build: (_) => const Snippet('> [!question]\n> '),
  ),
  SlashCommand(
    id: 'callout-warning',
    label: (l10n) => l10n.slashCalloutWarning,
    keywords: const ['callout', 'admonition', 'warning'],
    isBlock: true,
    build: (_) => const Snippet('> [!warning]\n> '),
  ),
  SlashCommand(
    id: 'callout-failure',
    label: (l10n) => l10n.slashCalloutFailure,
    keywords: const ['callout', 'admonition', 'failure'],
    isBlock: true,
    build: (_) => const Snippet('> [!failure]\n> '),
  ),
  SlashCommand(
    id: 'callout-danger',
    label: (l10n) => l10n.slashCalloutDanger,
    keywords: const ['callout', 'admonition', 'danger'],
    isBlock: true,
    build: (_) => const Snippet('> [!danger]\n> '),
  ),
  SlashCommand(
    id: 'callout-bug',
    label: (l10n) => l10n.slashCalloutBug,
    keywords: const ['callout', 'admonition', 'bug'],
    isBlock: true,
    build: (_) => const Snippet('> [!bug]\n> '),
  ),
  SlashCommand(
    id: 'callout-example',
    label: (l10n) => l10n.slashCalloutExample,
    keywords: const ['callout', 'admonition', 'example'],
    isBlock: true,
    build: (_) => const Snippet('> [!example]\n> '),
  ),
  SlashCommand(
    id: 'callout-quote',
    label: (l10n) => l10n.slashCalloutQuote,
    keywords: const ['callout', 'admonition', 'quote'],
    isBlock: true,
    build: (_) => const Snippet('> [!quote]\n> '),
  ),

  // Table (3 x 3)
  SlashCommand(
    id: 'table',
    label: (l10n) => l10n.slashTable,
    keywords: const ['table', 'grid'],
    isBlock: true,
    build: (_) => const Snippet(
      '|   |   |   |\n| --- | --- | --- |\n|   |   |   |\n|   |   |   |\n',
      caret: 2,
    ),
  ),

  // Code block
  SlashCommand(
    id: 'code-block',
    label: (l10n) => l10n.slashCodeBlock,
    keywords: const ['code', 'fence'],
    isBlock: true,
    build: (_) => const Snippet('```\n\n```', caret: 4),
  ),

  // Math block
  SlashCommand(
    id: 'math-block',
    label: (l10n) => l10n.slashMathBlock,
    keywords: const ['math', 'latex', 'equation'],
    isBlock: true,
    build: (_) => const Snippet('\$\$\n\n\$\$', caret: 3),
  ),

  // Horizontal rule
  SlashCommand(
    id: 'horizontal-rule',
    label: (l10n) => l10n.slashHorizontalRule,
    keywords: const ['divider', 'hr', 'line'],
    isBlock: true,
    build: (input) => Snippet(input.isLineZero ? '***' : '---'),
  ),

  // Task
  SlashCommand(
    id: 'task',
    label: (l10n) => l10n.slashTask,
    keywords: const ['todo', 'checkbox'],
    isBlock: true,
    build: (_) => const Snippet('- [ ] '),
  ),

  // Today
  SlashCommand(
    id: 'today',
    label: (l10n) => l10n.slashToday,
    keywords: const ['date'],
    isBlock: false,
    build: (input) =>
        Snippet(formatMoment(input.now, input.settings.templatesDateFormat)),
  ),

  // Template
  SlashCommand(
    id: 'template',
    label: (l10n) => l10n.slashTemplate,
    keywords: const ['template'],
    isBlock: false,
    build: (_) => const Snippet(''),
    isAvailable: (ref) =>
        ref.watch(commandRegistryProvider).byId('templates.insert-template') !=
        null,
  ),
];
