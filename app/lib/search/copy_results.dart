// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';

import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../workspace/providers.dart';

/// Formats [results] as an indented Markdown list with wikilinks and snippet lines.
String formatResultsAsMarkdown(
  List<SearchResult> results,
  LinkFormatter fmt,
  VaultPath from,
) {
  final buf = StringBuffer();

  for (final res in results) {
    final link = fmt.buildLink(res.path, from: from);
    buf.write('- $link\n');

    final contentMatches = res.matches
        .where((m) => !m.inFileName)
        .take(10)
        .toList();
    for (final m in contentMatches) {
      final lineText = m.snippet.trim();
      buf.write('\t- $lineText\n');
    }
  }

  return buf.toString();
}

/// Copies formatted search results to clipboard and displays a snackbar.
Future<void> copyResultsToClipboard(
  BuildContext context,
  WidgetRef ref,
  List<SearchResult> results,
) async {
  if (results.isEmpty) return;

  final activePath = ref.read(activeNotePathProvider);
  final from = activePath ?? VaultPath('_.md');
  final settings = ref.read(vaultSettingsProvider);

  LinkTargetLookup lookup = NameTable();
  try {
    final index = ref.read(noteIndexProvider).value;
    if (index != null) {
      lookup = await index.loadNameTable();
    }
  } catch (_) {}

  final fmt = LinkFormatter(lookup, settings.linkFormatSettings);
  final markdown = formatResultsAsMarkdown(results, fmt, from);
  await Clipboard.setData(ClipboardData(text: markdown));

  if (context.mounted) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.searchResultsCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
