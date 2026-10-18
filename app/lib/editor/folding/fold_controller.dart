// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'fold_anchors.dart';
import 'fold_regions.dart';
import 'fold_store.dart';

/// Adapter for engine collapse and expand operations.
typedef ChunkCollapseCallback = void Function(int startLine, int endLine);
typedef ChunkExpandCallback = void Function(int startLine);
typedef ChunkIsCollapsedCallback = bool Function(int startLine);

/// Controller managing fold state and regions for an active editor tab.
final class FoldController extends ChangeNotifier {
  FoldController({
    required this.tabId,
    required this.path,
    this.foldStore,
    this.foldHeadings = true,
    this.foldIndent = true,
  });

  final String tabId;
  final VaultPath path;
  final FoldStore? foldStore;
  bool foldHeadings;
  bool foldIndent;

  FoldState _state = FoldState();
  List<FoldRegion> _regions = const [];
  String _text = '';
  LineIndex _lines = LineIndex('');

  ChunkCollapseCallback? onCollapseChunk;
  ChunkExpandCallback? onExpandChunk;
  ChunkIsCollapsedCallback? isLineCollapsed;

  FoldState get state => _state;
  List<FoldRegion> get regions => _regions;
  String get text => _text;
  LineIndex get lines => _lines;

  /// Returns active folded ranges as (from, to) UTF-16 pairs.
  List<(int, int)> get foldedRanges {
    final ranges = <(int, int)>[];
    for (final r in _regions) {
      if (_state.isFolded(r.headerStart)) {
        ranges.add((r.from, r.to));
      }
    }
    return ranges;
  }

  /// Returns true if the region starting at [headerStart] is folded.
  bool isFolded(int headerStart) => _state.isFolded(headerStart);

  /// Toggles fold state for the region starting at [headerStart].
  void toggle(int headerStart) {
    final region = _findRegion(headerStart);
    if (region == null) return;

    final wasFolded = _state.isFolded(headerStart);
    _state = _state.toggle(headerStart);

    if (wasFolded) {
      _expandRegionInEngine(region);
    } else {
      _collapseRegionInEngine(region);
    }

    _save();
    notifyListeners();
  }

  /// Folds every valid region.
  void foldAll() {
    _state = _state.foldAll(_regions);
    _syncToEngine();
    _save();
    notifyListeners();
  }

  /// Unfolds all regions.
  void unfoldAll() {
    _state = _state.unfoldAll();
    _syncToEngine();
    _save();
    notifyListeners();
  }

  /// Unfolds any fold containing [offset].
  ///
  /// Called when the caret moves, link navigation jumps, or search reveals text.
  /// Returns true if at least one region was unfolded.
  bool revealOffset(int offset) {
    var unfoldedAny = false;
    final toUnfold = <FoldRegion>[];

    for (final r in _regions) {
      if (_state.isFolded(r.headerStart)) {
        // A folded region contains offset if offset is past header line up to r.to.
        if (offset > r.from && offset <= r.to) {
          toUnfold.add(r);
        }
      }
    }

    if (toUnfold.isNotEmpty) {
      for (final r in toUnfold) {
        _state = _state.toggle(r.headerStart);
        _expandRegionInEngine(r);
      }
      unfoldedAny = true;
      _save();
      notifyListeners();
    }

    return unfoldedAny;
  }

  /// Updates anchors following a text edit before a re-parse completes.
  void handleEdit(int start, int deletedLength, int insertedLength) {
    _state = _state.mapThroughEdit(start, deletedLength, insertedLength);
  }

  /// Updates regions and prunes dead anchors after a document re-parse.
  void updateParse(
    String newText,
    ParsedNote parsed, {
    bool? foldHeadings,
    bool? foldIndent,
  }) {
    _text = newText;
    _lines = parsed.lines;
    if (foldHeadings != null) this.foldHeadings = foldHeadings;
    if (foldIndent != null) this.foldIndent = foldIndent;

    _regions = computeFoldRegions(
      newText,
      parsed,
      headings: this.foldHeadings,
      lists: this.foldIndent,
    );

    _state = _state.pruneDeadAnchors(_regions);
    _syncToEngine();
    notifyListeners();
  }

  /// Updates fold settings and unfolds disabled region types.
  void updateSettings({required bool foldHeadings, required bool foldIndent}) {
    if (this.foldHeadings == foldHeadings && this.foldIndent == foldIndent) {
      return;
    }
    this.foldHeadings = foldHeadings;
    this.foldIndent = foldIndent;

    if (_text.isNotEmpty) {
      final parsed = MarkdownParser.parse(_text);
      _regions = computeFoldRegions(
        _text,
        parsed,
        headings: this.foldHeadings,
        lists: this.foldIndent,
      );
      _state = _state.pruneDeadAnchors(_regions);
      _syncToEngine();
      notifyListeners();
    }
  }

  /// Restores fold state from [FoldStore].
  Future<void> restoreFromStore() async {
    if (foldStore == null) return;
    final items = await foldStore!.load(path);
    if (items.isEmpty || _regions.isEmpty) return;

    final restored = FoldStore.restore(
      regions: _regions,
      storedItems: items,
      text: _text,
      lines: _lines,
    );

    _state = FoldState(restored.map((r) => r.headerStart).toSet());
    _syncToEngine();
    notifyListeners();
  }

  /// Attaches engine collapse/expand callbacks.
  void attachEngine({
    required ChunkCollapseCallback onCollapse,
    required ChunkExpandCallback onExpand,
    ChunkIsCollapsedCallback? isCollapsed,
  }) {
    onCollapseChunk = onCollapse;
    onExpandChunk = onExpand;
    isLineCollapsed = isCollapsed;
    _syncToEngine();
  }

  void detachEngine() {
    onCollapseChunk = null;
    onExpandChunk = null;
    isLineCollapsed = null;
  }

  FoldRegion? _findRegion(int headerStart) {
    for (final r in _regions) {
      if (r.headerStart == headerStart) return r;
    }
    return null;
  }

  void _collapseRegionInEngine(FoldRegion region) {
    if (onCollapseChunk == null) return;
    final startLine = _lines.lineOf(region.headerStart);
    final lastHiddenLine = _lines.lineOf(region.to);
    if (lastHiddenLine > startLine) {
      onCollapseChunk!(startLine, lastHiddenLine + 1);
    }
  }

  void _expandRegionInEngine(FoldRegion region) {
    if (onExpandChunk == null) return;
    final startLine = _lines.lineOf(region.headerStart);
    onExpandChunk!(startLine);
  }

  void _syncToEngine() {
    if (onCollapseChunk == null || onExpandChunk == null) return;

    // First expand all lines that shouldn't be folded
    for (final r in _regions) {
      if (!_state.isFolded(r.headerStart)) {
        final startLine = _lines.lineOf(r.headerStart);
        if (isLineCollapsed?.call(startLine) ?? true) {
          onExpandChunk!(startLine);
        }
      }
    }

    // Collapse from bottom to top so indices remain consistent
    final toCollapse =
        _regions.where((r) => _state.isFolded(r.headerStart)).toList()
          ..sort((a, b) => b.headerStart.compareTo(a.headerStart));

    for (final r in toCollapse) {
      final startLine = _lines.lineOf(r.headerStart);
      final lastHiddenLine = _lines.lineOf(r.to);
      if (lastHiddenLine > startLine) {
        onCollapseChunk!(startLine, lastHiddenLine + 1);
      }
    }
  }

  void _save() {
    if (foldStore == null) return;
    final items = <FoldItem>[];
    for (final r in _regions) {
      if (_state.isFolded(r.headerStart)) {
        items.add(
          FoldStore.itemFromRegion(region: r, text: _text, lines: _lines),
        );
      }
    }
    foldStore!.save(path, items);
  }
}
