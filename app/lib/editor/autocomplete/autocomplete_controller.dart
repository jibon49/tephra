// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../commands/providers.dart';
import '../../commands/quick_switcher_items.dart';
import '../../core/isolate_utils.dart';
import '../../core/providers.dart';
import '../../explorer/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../outline/outline_tree.dart';
import '../../vault/note_tools/providers.dart';
import '../../vault/note_tools/template_service.dart';
import '../../vault/providers.dart';
import '../../workspace/providers.dart';
import '../editor_controller.dart';
import '../providers.dart';
import 'autocomplete_context.dart';
import 'autocomplete_insertion.dart';
import 'autocomplete_item.dart';
import 'autocomplete_ranker.dart';
import 'block_candidates.dart';
import 'frontmatter_scanner.dart';
import 'providers.dart';
import 'slash_commands.dart';

final _logger = Logger('autocomplete');

/// State of the editor autocomplete popup.
final class AutocompleteState {
  const AutocompleteState({
    this.context,
    this.items = const [],
    this.selected = 0,
    this.visible = false,
    this.loading = false,
  });

  final AutocompleteContext? context;
  final List<AcItem> items;
  final int selected;
  final bool visible;
  final bool loading;

  AutocompleteState copyWith({
    AutocompleteContext? context,
    bool clearContext = false,
    List<AcItem>? items,
    int? selected,
    bool? visible,
    bool? loading,
  }) {
    return AutocompleteState(
      context: clearContext ? null : (context ?? this.context),
      items: items ?? this.items,
      selected: selected ?? this.selected,
      visible: visible ?? this.visible,
      loading: loading ?? this.loading,
    );
  }
}

/// Provider for tab-scoped autocomplete controller.
final autocompleteControllerProvider =
    NotifierProvider.family<AutocompleteController, AutocompleteState, String>(
      (arg) => AutocompleteController(arg),
    );

/// Controller managing autocomplete detection, keyboard events, and side-effects.
class AutocompleteController extends Notifier<AutocompleteState> {
  AutocompleteController([this.tabId]);

  final String? tabId;

  EditorController? _editor;
  StreamSubscription<void>? _editsSub;
  StreamSubscription<void>? _selectionSub;

  int? _dismissedAt;
  Type? _dismissedKind;
  int _seq = 0;
  bool _wasComposing = false;
  String? _lastQuery;
  Type? _lastContextKind;

  final _swallowed = <LogicalKeyboardKey>{};
  bool _isDisposed = false;
  bool _forceValueAfterKey = false;

  @override
  AutocompleteState build() {
    ref.onDispose(() {
      _isDisposed = true;
      detach(isDisposing: true);
    });
    return const AutocompleteState();
  }

  /// Attaches this controller to an [EditorController].
  void attach(EditorController editor) {
    if (_editor == editor) return;
    detach();
    _editor = editor;

    _editsSub = editor.edits.listen((_) => _onEditorEvent());
    _selectionSub = editor.selectionChanges.listen((_) => _onEditorEvent());
  }

  /// Detaches from the active [EditorController].
  void detach({bool isDisposing = false}) {
    _editsSub?.cancel();
    _editsSub = null;
    _selectionSub?.cancel();
    _selectionSub = null;
    _editor?.setKeyInterceptor(null);
    _editor = null;
    _swallowed.clear();
    if (!isDisposing && !_isDisposed) {
      state = const AutocompleteState();
    }
  }

  /// Triggers autocomplete manually (e.g. on Ctrl+Space).
  void trigger({bool force = true}) {
    if (_isDisposed) return;
    _dismissedAt = null;
    _dismissedKind = null;
    _onEditorEvent(force: force);
  }

  void _onEditorEvent({bool force = false}) {
    if (_isDisposed) return;
    final editor = _editor;
    if (editor == null) return;

    if (!editor.composing.isCollapsed && editor.composing.isValid) {
      _wasComposing = true;
      return;
    }

    if (_wasComposing) {
      _wasComposing = false;
    }

    if (!editor.selection.isCollapsed) {
      _hide();
      return;
    }

    final text = editor.text;
    final caret = editor.selection.baseOffset;
    final settings = ref.read(vaultSettingsProvider);
    final ctx = detectAutocompleteContext(
      text,
      caret,
      force: force,
      forceEmpty: _forceValueAfterKey,
      slashCommands: settings.slashCommandsEnabled,
    );
    _forceValueAfterKey = false;

    if (ctx == null) {
      _dismissedAt = null;
      _dismissedKind = null;
      _hide();
      return;
    }

    final currentKind = ctx.runtimeType;
    if (!force &&
        _dismissedAt == ctx.replaceStart &&
        _dismissedKind == currentKind) {
      _hide();
      return;
    }

    if (force || _dismissedAt != ctx.replaceStart) {
      _dismissedAt = null;
      _dismissedKind = null;
    }

    _queryItems(ctx);
  }

  Future<void> _queryItems(AutocompleteContext ctx) async {
    final editor = _editor;
    if (editor == null) return;

    _seq++;
    final currentSeq = _seq;

    if (ctx is NoteLinkContext) {
      final switcherItems = ref.read(switcherItemsProvider).value ?? const [];
      final recent = ref.read(recentFilesProvider);
      final includeAttachments = ctx.embed;

      List<AcItem>? prevCandidates;
      if (_lastQuery != null &&
          ctx.query.startsWith(_lastQuery!) &&
          _lastContextKind == ctx.runtimeType) {
        prevCandidates = state.items;
      }

      final items = AutocompleteRanker.rankNotes(
        ctx.query,
        switcherItems,
        recent,
        includeAttachments: includeAttachments,
        previousCandidates: prevCandidates,
      );

      _lastQuery = ctx.query;
      _lastContextKind = ctx.runtimeType;

      state = state.copyWith(
        context: ctx,
        items: items,
        selected: 0,
        visible: items.isNotEmpty,
        loading: false,
      );
      _updateKeyInterceptor();
      return;
    }

    if (ctx is HeadingLinkContext) {
      state = state.copyWith(context: ctx, loading: true);

      if (ctx.noteText.isEmpty) {
        final p =
            ref.read(activeParsedNoteProvider) ??
            MarkdownParser.parse(editor.text);
        final headings = <HeadingRecord>[];
        for (final h in p.headings) {
          headings.add(
            HeadingRecord(
              path: editor.path,
              level: h.level,
              text: extractHeadingText(h),
              start: h.start,
              end: h.end,
              line: p.lines.lineOf(h.start),
              ordinal: headings.length,
            ),
          );
        }

        if (currentSeq == _seq) {
          final items = AutocompleteRanker.rankHeadings(ctx.query, headings);
          state = state.copyWith(
            context: ctx,
            items: items,
            selected: 0,
            visible: items.isNotEmpty,
            loading: false,
          );
          _updateKeyInterceptor();
        }
        return;
      }

      try {
        final index = await ref.read(noteIndexProvider.future);
        final resolvedPath = await index.resolveLink(
          ctx.noteText,
          from: editor.path,
        );
        if (_isDisposed) return;
        if (resolvedPath != null) {
          final headings = await index.headings(resolvedPath);
          if (_isDisposed) return;
          if (currentSeq == _seq) {
            final items = AutocompleteRanker.rankHeadings(ctx.query, headings);
            state = state.copyWith(
              context: ctx,
              items: items,
              selected: 0,
              visible: items.isNotEmpty,
              loading: false,
            );
            _updateKeyInterceptor();
          }
        } else {
          if (_isDisposed) return;
          if (currentSeq == _seq) {
            state = state.copyWith(
              context: ctx,
              items: const [],
              selected: 0,
              visible: false,
              loading: false,
            );
            _updateKeyInterceptor();
          }
        }
      } catch (_) {
        if (_isDisposed) return;
        if (currentSeq == _seq) {
          state = state.copyWith(loading: false, visible: false);
          _updateKeyInterceptor();
        }
      }
      return;
    }

    if (ctx is BlockLinkContext) {
      state = state.copyWith(context: ctx, loading: true);

      if (ctx.noteText.isEmpty) {
        final parsed = MarkdownParser.parse(editor.text);
        final candidates = listBlockCandidates(editor.text, parsed);
        final items = AutocompleteRanker.rankBlocks(ctx.query, candidates);

        if (currentSeq == _seq) {
          state = state.copyWith(
            context: ctx,
            items: items,
            selected: 0,
            visible: items.isNotEmpty,
            loading: false,
          );
          _updateKeyInterceptor();
        }
        return;
      }

      try {
        final index = await ref.read(noteIndexProvider.future);
        final resolvedPath = await index.resolveLink(
          ctx.noteText,
          from: editor.path,
        );
        if (resolvedPath != null) {
          final registry = ref.read(editorRegistryProvider);
          final openTarget = registry.controllerFor(resolvedPath);
          final String targetText;
          if (openTarget != null) {
            targetText = openTarget.text;
          } else {
            final session = ref.read(vaultSessionProvider);
            if (session == null) return;
            final doc = await session.fs.readText(resolvedPath);
            targetText = doc.text;
          }

          final ParsedNote parsed;
          if (targetText.length > 50000) {
            parsed = await runInIsolate(() => MarkdownParser.parse(targetText));
          } else {
            parsed = MarkdownParser.parse(targetText);
          }

          final candidates = listBlockCandidates(targetText, parsed);
          if (currentSeq == _seq) {
            final items = AutocompleteRanker.rankBlocks(ctx.query, candidates);
            state = state.copyWith(
              context: ctx,
              items: items,
              selected: 0,
              visible: items.isNotEmpty,
              loading: false,
            );
            _updateKeyInterceptor();
          }
        } else {
          if (currentSeq == _seq) {
            state = state.copyWith(
              context: ctx,
              items: const [],
              selected: 0,
              visible: false,
              loading: false,
            );
            _updateKeyInterceptor();
          }
        }
      } catch (_) {
        if (currentSeq == _seq) {
          state = state.copyWith(loading: false, visible: false);
          _updateKeyInterceptor();
        }
      }
      return;
    }

    if (ctx is AliasLinkContext) {
      state = state.copyWith(context: ctx, loading: true);
      try {
        final index = await ref.read(noteIndexProvider.future);
        final resolvedPath = ctx.noteText.isEmpty
            ? editor.path
            : await index.resolveLink(ctx.noteText, from: editor.path);

        if (resolvedPath != null) {
          final allAliases = await index.allAliases();
          final aliases = [
            for (final a in allAliases)
              if (a.path == resolvedPath) a.alias,
            resolvedPath.stem,
          ];

          if (currentSeq == _seq) {
            final items = AutocompleteRanker.rankAliases(ctx.query, aliases);
            state = state.copyWith(
              context: ctx,
              items: items,
              selected: 0,
              visible: items.isNotEmpty,
              loading: false,
            );
            _updateKeyInterceptor();
          }
        } else {
          if (currentSeq == _seq) {
            state = state.copyWith(
              context: ctx,
              items: const [],
              selected: 0,
              visible: false,
              loading: false,
            );
            _updateKeyInterceptor();
          }
        }
      } catch (_) {
        if (currentSeq == _seq) {
          state = state.copyWith(loading: false, visible: false);
          _updateKeyInterceptor();
        }
      }
      return;
    }

    if (ctx is TagContext) {
      state = state.copyWith(context: ctx, loading: true);
      try {
        final tagList = await ref.read(tagListProvider.future);
        if (_isDisposed) return;
        if (currentSeq == _seq) {
          final items = AutocompleteRanker.rankTags(
            ctx.query,
            tagList,
            inFrontmatter: ctx.inFrontmatter,
          );
          state = state.copyWith(
            context: ctx,
            items: items,
            selected: 0,
            visible: items.isNotEmpty,
            loading: false,
          );
          _updateKeyInterceptor();
        }
      } catch (_) {
        if (_isDisposed) return;
        if (currentSeq == _seq) {
          state = state.copyWith(loading: false, visible: false);
          _updateKeyInterceptor();
        }
      }
      return;
    }

    if (ctx is PropertyKeyContext) {
      state = state.copyWith(context: ctx, loading: true);
      try {
        final allKeys = await ref.read(propertyKeysProvider.future);
        if (_isDisposed) return;
        final fm = frontmatterRange(editor.text);
        final existing = fm == null
            ? const <String>{}
            : extractFrontmatterKeys(editor.text, fm);
        final available = allKeys
            .where((k) => !existing.contains(k.key.toLowerCase()))
            .toList();

        if (currentSeq == _seq) {
          final items = AutocompleteRanker.rankPropertyKeys(
            ctx.query,
            available,
          );
          state = state.copyWith(
            context: ctx,
            items: items,
            selected: 0,
            visible: items.isNotEmpty,
            loading: false,
          );
          _updateKeyInterceptor();
        }
      } catch (_) {
        if (_isDisposed) return;
        if (currentSeq == _seq) {
          state = state.copyWith(loading: false, visible: false);
          _updateKeyInterceptor();
        }
      }
      return;
    }

    if (ctx is PropertyValueContext) {
      state = state.copyWith(context: ctx, loading: true);
      try {
        final keyLower = ctx.key.toLowerCase();
        List<AcItem> items;
        if (keyLower == 'tags' || keyLower == 'tag') {
          final tagList = await ref.read(tagListProvider.future);
          if (_isDisposed) return;
          final fm = frontmatterRange(editor.text);
          final existing = fm == null
              ? const <String>{}
              : extractValuesForProperty(
                  editor.text,
                  fm,
                  ctx.key,
                  inInlineList: ctx.inInlineList,
                  caret: editor.selection.baseOffset,
                );
          final available = tagList
              .where((t) => !existing.contains(t.tagLower))
              .toList();
          items = AutocompleteRanker.rankTags(
            ctx.query,
            available,
            inFrontmatter: true,
          );
        } else if (keyLower == 'aliases') {
          items = const [];
        } else {
          final allKeys = await ref.read(propertyKeysProvider.future);
          final pkc = allKeys
              .where((k) => k.key.toLowerCase() == keyLower)
              .firstOrNull;
          final valueType = pkc?.valueType;

          List<String> rawValues;
          if (valueType == 'checkbox') {
            rawValues = const ['true', 'false'];
          } else if (valueType == 'date') {
            final now = DateTime.now();
            final formatted =
                '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            rawValues = [formatted];
          } else if (valueType == 'datetime') {
            final now = DateTime.now();
            final formatted =
                '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            rawValues = [formatted];
          } else {
            rawValues = await ref.read(propertyValuesProvider(ctx.key).future);
          }

          if (_isDisposed) return;
          final fm = frontmatterRange(editor.text);
          final existing = fm == null
              ? const <String>{}
              : extractValuesForProperty(
                  editor.text,
                  fm,
                  ctx.key,
                  inInlineList: ctx.inInlineList,
                  caret: editor.selection.baseOffset,
                );
          final available = rawValues
              .where((v) => !existing.contains(v.toLowerCase()))
              .toList();
          items = AutocompleteRanker.rankPropertyValues(ctx.query, available);
        }

        if (currentSeq == _seq) {
          state = state.copyWith(
            context: ctx,
            items: items,
            selected: 0,
            visible: items.isNotEmpty,
            loading: false,
          );
          _updateKeyInterceptor();
        }
      } catch (_) {
        if (_isDisposed) return;
        if (currentSeq == _seq) {
          state = state.copyWith(loading: false, visible: false);
          _updateKeyInterceptor();
        }
      }
      return;
    }

    if (ctx is SlashContext) {
      final l10n = _getL10n();
      if (l10n == null) return;
      final availableCommands = defaultSlashCommands.where((cmd) {
        if (cmd.isAvailable != null) {
          return cmd.isAvailable!(ref);
        }
        return true;
      }).toList();

      final items = AutocompleteRanker.rankSlashCommands(
        ctx.query,
        availableCommands,
        l10n,
      );

      if (currentSeq == _seq) {
        state = state.copyWith(
          context: ctx,
          items: items,
          selected: 0,
          visible: items.isNotEmpty,
          loading: false,
        );
        _updateKeyInterceptor();
      }
      return;
    }
  }

  /// Hides the autocomplete popup and clears the context.
  void hide() => _hide();

  void _hide() {
    if (_isDisposed) return;
    state = state.copyWith(
      visible: false,
      clearContext: true,
      items: const [],
      loading: false,
      selected: 0,
    );
    _updateKeyInterceptor();
  }

  void _updateKeyInterceptor() {
    if (_isDisposed) return;
    if (state.visible && _editor != null) {
      _editor!.setKeyInterceptor(_onKeyEvent);
    } else {
      _editor?.setKeyInterceptor(null);
      _swallowed.clear();
    }
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (_editor == null || !_editor!.composing.isCollapsed || !state.visible) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _swallowed.add(event.logicalKey);
        _moveSelection(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _swallowed.add(event.logicalKey);
        _moveSelection(-1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.pageDown) {
        _swallowed.add(event.logicalKey);
        _moveSelection(8);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.pageUp) {
        _swallowed.add(event.logicalKey);
        _moveSelection(-8);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _swallowed.add(event.logicalKey);
        if (state.items.isNotEmpty &&
            state.selected >= 0 &&
            state.selected < state.items.length) {
          accept(state.items[state.selected], continueIntoSubpath: false);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _swallowed.add(event.logicalKey);
        if (state.items.isNotEmpty &&
            state.selected >= 0 &&
            state.selected < state.items.length) {
          accept(state.items[state.selected], continueIntoSubpath: true);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _swallowed.add(event.logicalKey);
        _dismissedAt = state.context?.replaceStart;
        _dismissedKind = state.context.runtimeType;
        _hide();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event is KeyRepeatEvent) {
      if (_swallowed.contains(event.logicalKey)) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _moveSelection(1);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _moveSelection(-1);
        } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
          _moveSelection(8);
        } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
          _moveSelection(-8);
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event is KeyUpEvent) {
      if (_swallowed.remove(event.logicalKey)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  void _moveSelection(int delta) {
    if (state.items.isEmpty) return;
    final count = state.items.length;
    final next = (state.selected + delta) % count;
    state = state.copyWith(selected: next < 0 ? next + count : next);
  }

  /// Selects an item at [index].
  void selectIndex(int index) {
    if (index >= 0 && index < state.items.length) {
      state = state.copyWith(selected: index);
    }
  }

  /// Accepts [item] and inserts it into the active editor.
  Future<void> accept(
    AcItem item, {
    AutocompleteContext? context,
    bool continueIntoSubpath = false,
  }) async {
    final ctx = context ?? state.context;
    final editor = _editor;
    if (ctx == null || editor == null) return;

    final settings = ref.read(vaultSettingsProvider);
    LinkFormatter formatter;
    try {
      final index = await ref.read(noteIndexProvider.future);
      final nameTable = await index.loadNameTable();
      formatter = LinkFormatter(nameTable, settings.linkFormatSettings);
    } catch (_) {
      formatter = LinkFormatter(NameTable(), settings.linkFormatSettings);
    }

    VaultPath? targetNotePath;
    Set<String>? takenBlockIds;

    if (ctx is BlockLinkContext) {
      if (ctx.noteText.isEmpty) {
        targetNotePath = editor.path;
      } else {
        try {
          final index = await ref.read(noteIndexProvider.future);
          targetNotePath = await index.resolveLink(
            ctx.noteText,
            from: editor.path,
          );
        } catch (_) {
          targetNotePath = null;
        }
      }
      if (targetNotePath != null) {
        final parsed = MarkdownParser.parse(editor.text);
        final candidates = listBlockCandidates(editor.text, parsed);
        takenBlockIds = {
          for (final c in candidates)
            if (c.existingId != null) c.existingId!.toLowerCase(),
        };
      }
    }

    String? propertyKeyType;
    if (ctx is PropertyValueContext) {
      try {
        final allKeys = await ref.read(propertyKeysProvider.future);
        final pkc = allKeys
            .where((k) => k.key.toLowerCase() == ctx.key.toLowerCase())
            .firstOrNull;
        propertyKeyType = pkc?.valueType;
      } catch (_) {}
    }

    final slashInput = SlashInput(
      now: DateTime.now(),
      settings: settings,
      isLineZero: _isLineZero(editor.text, ctx.replaceStart),
    );

    final insertion = buildInsertion(
      editor.text,
      ctx,
      item,
      formatter: formatter,
      from: editor.path,
      continueIntoSubpath: continueIntoSubpath,
      targetNotePath: targetNotePath,
      takenBlockIds: takenBlockIds,
      onExternalBlockCreated: (target, candidate, id) async {
        await _handleExternalBlockCreated(target, candidate, id);
      },
      propertyKeyType: propertyKeyType,
      slashInput: slashInput,
    );

    if (ctx is PropertyKeyContext) {
      final String key;
      final String? valueType;
      if (item.payload is PropertyKeyCount) {
        final pkc = item.payload as PropertyKeyCount;
        key = pkc.key;
        valueType = pkc.valueType;
      } else {
        key = item.primary;
        valueType = item.secondary;
      }
      final keyLower = key.toLowerCase();
      final isListKey =
          valueType == 'multitext' ||
          valueType == 'tags' ||
          valueType == 'aliases' ||
          keyLower == 'tags' ||
          keyLower == 'aliases' ||
          keyLower == 'cssclasses';
      if (!isListKey) {
        _forceValueAfterKey = true;
      }
    }

    editor.applyEdits(insertion.edits);
    editor.select(insertion.caretAfter);

    for (final effect in insertion.sideEffects) {
      await effect();
    }

    if (item.kind == AcKind.slash && item.payload is SlashCommand) {
      final cmd = item.payload as SlashCommand;
      if (cmd.id == 'template') {
        final reg = ref.read(commandRegistryProvider);
        final insertCmd = reg.byId('templates.insert-template');
        final smKey = ref.read(scaffoldMessengerKeyProvider);
        final buildContext = smKey.currentContext;
        if (insertCmd != null && buildContext != null && buildContext.mounted) {
          unawaited(
            executeInsertTemplate(
              buildContext,
              templateService: ref.read(templateServiceProvider),
              editor: editor,
            ),
          );
        }
      }
    }

    if (insertion.continueCompletion || _forceValueAfterKey) {
      _onEditorEvent(force: true);
    } else {
      _hide();
    }
  }

  Future<void> _handleExternalBlockCreated(
    VaultPath target,
    BlockCandidate candidate,
    String id,
  ) async {
    final registry = ref.read(editorRegistryProvider);
    final openEditor = registry.controllerFor(target);
    if (openEditor != null) {
      final parsed = MarkdownParser.parse(openEditor.text);
      final blocks = listBlockCandidates(openEditor.text, parsed);
      final match = blocks
          .where(
            (b) => b.kind == candidate.kind && b.preview == candidate.preview,
          )
          .firstOrNull;
      if (match != null) {
        final edit = blockIdEdit(openEditor.text, match, id);
        openEditor.applyEdits([edit]);
        _showSnackbar((l10n) => l10n.autocompleteBlockCreated(id));
        return;
      }
    }

    final session = ref.read(vaultSessionProvider);
    if (session == null) return;
    try {
      final doc = await session.fs.readText(target);
      if (doc.malformed) return;
      final parsed = MarkdownParser.parse(doc.text);
      final blocks = listBlockCandidates(doc.text, parsed);
      final match = blocks
          .where(
            (b) => b.kind == candidate.kind && b.preview == candidate.preview,
          )
          .firstOrNull;
      if (match == null) {
        _showSnackbar((l10n) => l10n.autocompleteBlockMissing);
        return;
      }
      final edit = blockIdEdit(doc.text, match, id);
      final newText =
          doc.text.substring(0, edit.start) +
          edit.replacement +
          doc.text.substring(edit.end);
      await session.fs.writeText(
        target,
        TextDocument(
          text: newText,
          hasBom: doc.hasBom,
          lineEnding: doc.lineEnding,
        ),
      );
      _showSnackbar((l10n) => l10n.autocompleteBlockCreated(id));
    } catch (e, st) {
      _logger.severe('Failed to write block ID to $target', e, st);
      _showSnackbar((l10n) => l10n.autocompleteBlockMissing);
    }
  }

  void _showSnackbar(String Function(AppLocalizations) getMessage) {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      if (context != null) {
        final l10n = AppLocalizations.of(context);
        key.currentState?.showSnackBar(
          SnackBar(content: Text(getMessage(l10n))),
        );
      }
    } catch (_) {}
  }

  bool _isLineZero(String text, int offset) {
    for (var i = offset - 1; i >= 0; i--) {
      if (text.codeUnitAt(i) == 0x0A) return false;
    }
    return true;
  }

  AppLocalizations? _getL10n() {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      if (context != null) {
        return AppLocalizations.of(context);
      }
    } catch (_) {}
    return lookupAppLocalizations(const Locale('en'));
  }
}
