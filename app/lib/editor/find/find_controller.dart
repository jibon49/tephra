// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../edit_operation.dart';
import '../editor_controller.dart';
import '../highlight/source_highlighter.dart';
import '../highlight/source_styles.dart';
import 'find_engine.dart';
import 'find_options.dart';

/// State of the active find & replace session.
final class FindState {
  const FindState({
    this.options = const FindOptions(query: ''),
    this.matches = const [],
    this.currentIndex = -1,
    this.replaceText = '',
    this.isOpen = false,
    this.showReplace = false,
    this.error,
    this.truncated = false,
  });

  final FindOptions options;
  final List<FindMatch> matches;
  final int currentIndex;
  final String replaceText;
  final bool isOpen;
  final bool showReplace;
  final String? error;
  final bool truncated;

  FindState copyWith({
    FindOptions? options,
    List<FindMatch>? matches,
    int? currentIndex,
    String? replaceText,
    bool? isOpen,
    bool? showReplace,
    String? error,
    bool clearError = false,
    bool? truncated,
  }) {
    return FindState(
      options: options ?? this.options,
      matches: matches ?? this.matches,
      currentIndex: currentIndex ?? this.currentIndex,
      replaceText: replaceText ?? this.replaceText,
      isOpen: isOpen ?? this.isOpen,
      showReplace: showReplace ?? this.showReplace,
      error: clearError ? null : (error ?? this.error),
      truncated: truncated ?? this.truncated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FindState &&
          options == other.options &&
          listEquals(matches, other.matches) &&
          currentIndex == other.currentIndex &&
          replaceText == other.replaceText &&
          isOpen == other.isOpen &&
          showReplace == other.showReplace &&
          error == other.error &&
          truncated == other.truncated;

  @override
  int get hashCode => Object.hash(
    options,
    Object.hashAll(matches),
    currentIndex,
    replaceText,
    isOpen,
    showReplace,
    error,
    truncated,
  );
}

/// Controller managing search state, debounced queries, navigation, and overlays.
final class FindController extends ValueNotifier<FindState> {
  FindController(this.controller) : super(const FindState());

  final EditorController controller;
  Timer? _debounceTimer;
  void Function(int count)? onReplaceAll;

  FindState get state => value;
  set state(FindState s) => value = s;

  void open({bool replace = false}) {
    final sel = controller.selection;
    var query = state.options.query;
    if (!sel.isCollapsed) {
      final text = controller.text;
      if (sel.start >= 0 && sel.end <= text.length) {
        final selText = text.substring(sel.start, sel.end);
        if (!selText.contains('\n') && selText.length <= 100) {
          query = selText;
        }
      }
    }
    state = state.copyWith(
      options: state.options.copyWith(query: query),
      isOpen: true,
      showReplace: replace || state.showReplace,
    );
    _runSearch(immediate: true);
  }

  void close() {
    _debounceTimer?.cancel();
    state = state.copyWith(isOpen: false);
    _clearOverlays();
    controller.focus();
  }

  void setQuery(String query) {
    if (state.options.query == query) return;
    state = state.copyWith(options: state.options.copyWith(query: query));
    _scheduleSearch();
  }

  void setReplaceText(String text) {
    state = state.copyWith(replaceText: text);
  }

  void setOptions(FindOptions options) {
    state = state.copyWith(options: options);
    _scheduleSearch();
  }

  void toggleMatchCase() =>
      setOptions(state.options.copyWith(matchCase: !state.options.matchCase));

  void toggleWholeWord() =>
      setOptions(state.options.copyWith(wholeWord: !state.options.wholeWord));

  void toggleRegex() =>
      setOptions(state.options.copyWith(regex: !state.options.regex));

  void toggleReplace() {
    state = state.copyWith(showReplace: !state.showReplace);
  }

  void _scheduleSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _runSearch();
    });
  }

  void _runSearch({bool immediate = false}) {
    _debounceTimer?.cancel();
    final res = findAll(controller.text, state.options);

    if (res.error != null) {
      state = state.copyWith(
        matches: const [],
        currentIndex: -1,
        error: res.error,
        truncated: false,
      );
      _clearOverlays();
      return;
    }

    if (res.matches.isEmpty) {
      state = state.copyWith(
        matches: const [],
        currentIndex: -1,
        clearError: true,
        truncated: false,
      );
      _clearOverlays();
      return;
    }

    // Determine current index: first match at or after caret
    final caret = controller.selection.start;
    var idx = 0;
    for (var i = 0; i < res.matches.length; i++) {
      if (res.matches[i].start >= caret) {
        idx = i;
        break;
      }
    }

    state = state.copyWith(
      matches: res.matches,
      currentIndex: idx,
      clearError: true,
      truncated: res.truncated,
    );

    _updateOverlays();
  }

  void next() {
    final matches = state.matches;
    if (matches.isEmpty) return;

    final nextIndex = (state.currentIndex + 1) % matches.length;
    _selectMatch(nextIndex);
  }

  void previous() {
    final matches = state.matches;
    if (matches.isEmpty) return;

    final prevIndex =
        (state.currentIndex - 1 + matches.length) % matches.length;
    _selectMatch(prevIndex);
  }

  void _selectMatch(int index) {
    final matches = state.matches;
    if (index < 0 || index >= matches.length) return;

    state = state.copyWith(currentIndex: index);
    final m = matches[index];
    controller.select(m.start, m.end);
    controller.revealOffset(m.start);
    _updateOverlays();
  }

  void replaceCurrent() {
    final matches = state.matches;
    final idx = state.currentIndex;
    if (matches.isEmpty || idx < 0 || idx >= matches.length) return;

    final m = matches[idx];
    final rep = expandReplacement(
      m,
      state.replaceText,
      regex: state.options.regex,
    );
    controller.apply(EditOperation(m.start, m.end, rep), selectAfter: true);

    // Re-search immediately
    final res = findAll(controller.text, state.options);
    if (res.matches.isEmpty) {
      state = state.copyWith(
        matches: const [],
        currentIndex: -1,
        clearError: true,
      );
      _clearOverlays();
      return;
    }

    // Move to next match at or after replacement point
    final nextTarget = m.start + rep.length;
    var nextIdx = 0;
    for (var i = 0; i < res.matches.length; i++) {
      if (res.matches[i].start >= nextTarget) {
        nextIdx = i;
        break;
      }
    }

    state = state.copyWith(
      matches: res.matches,
      currentIndex: nextIdx,
      clearError: true,
      truncated: res.truncated,
    );
    _selectMatch(nextIdx);
  }

  void replaceAll() {
    final matches = state.matches;
    if (matches.isEmpty) return;

    final ops = replaceAllOps(
      controller.text,
      matches,
      state.replaceText,
      regex: state.options.regex,
    );
    final count = ops.length;
    controller.applyEdits(ops);

    onReplaceAll?.call(count);

    // Re-search immediately
    _runSearch(immediate: true);
  }

  void _updateOverlays() {
    final matches = state.matches;
    final curr = state.currentIndex;
    final overlays = <OverlayRange>[];

    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      overlays.add(
        OverlayRange(
          start: m.start,
          end: m.end,
          token: (i == curr) ? SourceToken.findCurrent : SourceToken.findMatch,
        ),
      );
    }

    controller.highlighter.setOverlays(overlays, controller.lines);
    controller.repaintLines(0, controller.lines.lineCount - 1);
  }

  void _clearOverlays() {
    controller.highlighter.setOverlays(const [], controller.lines);
    controller.repaintLines(0, controller.lines.lineCount - 1);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
