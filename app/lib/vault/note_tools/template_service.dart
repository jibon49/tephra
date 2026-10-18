// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../editor/editor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../properties/frontmatter_editor.dart';
import '../../settings/settings_screen.dart';
import '../../settings/vault_settings.dart';
import 'exceptions.dart';
import 'template_picker.dart';

/// Target interface for an active note editor receiving template insertions.
abstract interface class NoteEditorTarget {
  VaultPath get path;
  String get text;
  int get selectionStart;
  int get selectionEnd;
  void applyEdits(List<TextEdit> edits);
  void select(int offset);
}

/// Service managing template notes and template insertion into notes.
final class TemplateService {
  TemplateService({
    required this.fs,
    required dynamic index,
    required this.getSettings,
    required this.clock,
    this.showSnackbar,
  }) : _getIndex = (index is FutureOr<NoteIndex> Function()
           ? index
           : () => index as NoteIndex);

  final VaultFileSystem fs;
  final FutureOr<NoteIndex> Function() _getIndex;
  final VaultSettings Function() getSettings;
  final Clock clock;
  final void Function(String messageKey)? showSnackbar;

  VaultSettings get settings => getSettings();

  /// Returns all `.md` files located in `templates.folder` (recursive).
  ///
  /// Throws [TemplatesNotConfiguredException] if `templates.folder` is empty.
  Future<List<VaultPath>> templateFiles() async {
    final folder = settings.templatesFolder.trim();
    if (folder.isEmpty) {
      throw const TemplatesNotConfiguredException();
    }

    final idx = await _getIndex();
    final all = await idx.allFiles();
    final prefix = folder.endsWith('/') ? folder : '$folder/';

    final templates = all.map((f) => f.path).where((p) {
      if (!p.value.toLowerCase().endsWith('.md')) return false;
      if (folder == '/') return true;
      return p.value.startsWith(prefix);
    }).toList()..sort((a, b) => a.value.compareTo(b.value));

    return templates;
  }

  /// Inserts the template at [templatePath] into the active [target] editor.
  Future<bool> insertTemplate(
    NoteEditorTarget target,
    VaultPath templatePath,
  ) async {
    TextDocument raw;
    try {
      raw = await fs.readText(templatePath);
    } catch (_) {
      showSnackbar?.call('templateUnreadable');
      return false;
    }

    final now = clock.now();
    final ctx = TemplateContext(
      title: target.path.stem,
      date: now,
      now: now,
      dateFormat: settings.templatesDateFormat,
      timeFormat: settings.templatesTimeFormat,
    );

    final processed = applyTemplate(raw.text, ctx);
    final tmplSplit = splitFrontmatter(processed);

    if (tmplSplit == null) {
      // Template has no frontmatter: single TextEdit at caret / selection.
      final start = target.selectionStart;
      final end = target.selectionEnd;
      final edit = TextEdit(start, end, processed);
      target.applyEdits([edit]);
      target.select(start + processed.length);
      return true;
    }

    // Template has frontmatter: separate bodyText after closing `---` line.
    final bodyText = processed.substring(tmplSplit.bodyStart);
    final noteText = target.text;
    final noteSplit = splitFrontmatter(noteText);

    final tmplProps = FrontmatterEditor.read(processed);
    final noteProps = FrontmatterEditor.read(noteText);

    var currentText = noteText;
    for (final entry in tmplProps.entries) {
      final key = entry.key;
      final tmplVal = entry.value;

      if (!noteProps.containsKey(key)) {
        final edit = FrontmatterEditor.setValue(currentText, key, tmplVal);
        if (edit != null) {
          currentText = applyTextEdits(currentText, [edit]);
        }
      } else {
        final noteVal = noteProps[key];
        if (noteVal is List && tmplVal is List) {
          final merged = List<Object?>.from(noteVal);
          for (final item in tmplVal) {
            if (!merged.contains(item)) {
              merged.add(item);
            }
          }
          final edit = FrontmatterEditor.setValue(currentText, key, merged);
          if (edit != null) {
            currentText = applyTextEdits(currentText, [edit]);
          }
        }
        // If present otherwise, note's value is kept.
      }
    }

    final evolvedSplit = splitFrontmatter(currentText)!;
    final newFmBlock = currentText.substring(0, evolvedSplit.bodyStart);
    final oldFmEnd = noteSplit?.bodyStart ?? 0;

    final fmEdit = TextEdit(0, oldFmEnd, newFmBlock);
    final targetOffset = math.max(target.selectionStart, oldFmEnd);
    final bodyEdit = TextEdit(targetOffset, targetOffset, bodyText);

    final edits = <TextEdit>[];
    if (bodyText.isEmpty) {
      if (fmEdit.replacement != noteText.substring(0, oldFmEnd)) {
        edits.add(fmEdit);
      }
    } else {
      if (fmEdit.start == bodyEdit.start) {
        // Two edits that start at the same offset (new block at 0 and body at 0)
        // are merged into one edit (block first).
        edits.add(
          TextEdit(0, oldFmEnd, '${fmEdit.replacement}${bodyEdit.replacement}'),
        );
      } else {
        if (fmEdit.replacement != noteText.substring(0, oldFmEnd)) {
          edits.add(fmEdit);
        }
        edits.add(bodyEdit);
      }
    }

    if (edits.isNotEmpty) {
      target.applyEdits(edits);
    }
    target.select(targetOffset + bodyText.length);
    return true;
  }
}

/// Adapter wrapping [EditorController] as [NoteEditorTarget].
final class EditorControllerTarget implements NoteEditorTarget {
  EditorControllerTarget(this.controller);
  final EditorController controller;

  @override
  VaultPath get path => controller.path;
  @override
  String get text => controller.text;
  @override
  int get selectionStart => controller.selection.start;
  @override
  int get selectionEnd => controller.selection.end;
  @override
  void applyEdits(List<TextEdit> edits) => controller.applyEdits(edits);
  @override
  void select(int offset) => controller.select(offset);
}

/// Prompts the user to pick a template and inserts it into [editor].
Future<void> executeInsertTemplate(
  BuildContext context, {
  required TemplateService templateService,
  required EditorController editor,
}) async {
  final l10n = AppLocalizations.of(context);
  List<VaultPath> templates;
  try {
    templates = await templateService.templateFiles();
  } on TemplatesNotConfiguredException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.templatesFolderNotSet),
          action: SnackBarAction(
            label: l10n.openSettings,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  final chosen = await showTemplatePicker(context, templates: templates);
  if (chosen == null || !context.mounted) return;

  final target = EditorControllerTarget(editor);
  await templateService.insertTemplate(target, chosen);
}
