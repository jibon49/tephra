// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../core/providers.dart';
import '../editor/edit_operation.dart';
import '../editor/providers.dart';
import '../explorer/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import '../vault/vault_undo.dart';
import 'providers.dart';

/// Service that converts an unlinked mention in a note to a link.
final class UnlinkedMentionLinker {
  UnlinkedMentionLinker(this.ref);

  final Ref ref;

  /// Links [m] by replacing its text with a link pointing to [target].
  Future<bool> link(UnlinkedMention m, VaultPath target) async {
    final controller = ref.read(editorRegistryProvider).controllerFor(m.source);
    final fs = ref.read(vaultFsProvider);
    final String text;
    final TextDocument? doc;

    if (controller != null) {
      text = controller.text;
      doc = null;
    } else {
      doc = await fs.readText(m.source);
      if (doc.malformed) return false;
      text = doc.text;
    }

    if (m.start < 0 ||
        m.end > text.length ||
        text.substring(m.start, m.end) != m.matchedText) {
      _showNotice((l10n) => l10n.mentionChangedRefresh);
      ref.invalidate(unlinkedMentionsProvider(target));
      return false;
    }

    final index = await ref.read(noteIndexProvider.future);
    final table = await index.loadNameTable();
    final settings = ref.read(vaultSettingsProvider);
    final linkFormatSettings = LinkFormatSettings(
      format: settings.newLinkFormatEnum,
      useMarkdownLinks: settings.useMarkdownLinks,
    );
    final formatter = LinkFormatter(table, linkFormatSettings);
    final syntax = settings.useMarkdownLinks
        ? LinkSyntax.markdown
        : LinkSyntax.wiki;
    final linkPath = formatter.linkPath(target, from: m.source, syntax: syntax);

    final String replacement;
    if (syntax == LinkSyntax.wiki) {
      if (m.matchedText == linkPath) {
        replacement = '[[$linkPath]]';
      } else {
        replacement = '[[$linkPath|${m.matchedText}]]';
      }
    } else {
      replacement = '[${m.matchedText}]($linkPath)';
    }

    final edit = TextEdit(m.start, m.end, replacement);
    final String newText;
    final bool inBuffer;

    if (controller != null) {
      controller.applyEdits([EditOperation(m.start, m.end, replacement)]);
      newText = controller.text;
      inBuffer = true;
    } else {
      newText = applyTextEdits(text, [edit]);
      await fs.writeText(
        m.source,
        TextDocument(
          text: newText,
          hasBom: doc!.hasBom,
          lineEnding: doc.lineEnding,
        ),
      );
      inBuffer = false;
    }

    final change = FileChange(
      path: m.source,
      oldText: text,
      newText: newText,
      inBuffer: inBuffer,
    );
    final op = VaultOperation(
      moves: const {},
      changes: [change],
      at: DateTime.now(),
    );
    ref.read(vaultUndoStackProvider.notifier).push(op);

    _showLinkedNotice();

    ref.invalidate(unlinkedMentionsProvider(target));
    ref.invalidate(backlinksProvider(target));

    return true;
  }

  void _showNotice(String Function(AppLocalizations) getMsg) {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      if (context == null) return;
      final l10n = AppLocalizations.of(context);
      key.currentState?.showSnackBar(SnackBar(content: Text(getMsg(l10n))));
    } catch (_) {}
  }

  void _showLinkedNotice() {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      if (context == null) return;
      final l10n = AppLocalizations.of(context);
      key.currentState?.showSnackBar(
        SnackBar(
          content: Text(l10n.mentionLinked),
          action: SnackBarAction(
            label: l10n.undoAction,
            onPressed: () {
              ref.read(vaultUndoStackProvider.notifier).undoLast();
            },
          ),
        ),
      );
    } catch (_) {}
  }
}
