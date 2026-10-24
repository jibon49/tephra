// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../core/providers.dart';
import '../../settings/vault_settings.dart';
import '../../vault/providers.dart';
import '../data/sticky_repository.dart';
import '../model/sticky.dart';
import '../model/sticky_color.dart';
import '../model/task_toggle.dart';
import '../providers.dart';
import 'board_color_map.dart';
import 'board_layout.dart';
import 'board_reconciler.dart';
import 'canvas_document.dart';

/// The immutable state of the sticky board.
final class BoardState {
  const BoardState({
    required this.doc,
    this.isBroken = false,
    this.isLoading = false,
    this.selectedNodeId,
    this.undoPositions,
  });

  final CanvasDocument doc;
  final bool isBroken;
  final bool isLoading;
  final String? selectedNodeId;
  final Map<String, Offset>? undoPositions;

  BoardState copyWith({
    CanvasDocument? doc,
    bool? isBroken,
    bool? isLoading,
    String? selectedNodeId,
    bool clearSelected = false,
    Map<String, Offset>? undoPositions,
    bool clearUndo = false,
  }) {
    return BoardState(
      doc: doc ?? this.doc,
      isBroken: isBroken ?? this.isBroken,
      isLoading: isLoading ?? this.isLoading,
      selectedNodeId: clearSelected
          ? null
          : (selectedNodeId ?? this.selectedNodeId),
      undoPositions: clearUndo ? null : (undoPositions ?? this.undoPositions),
    );
  }
}

/// Controller managing board document loading, auto-reconcile, drag persistence,
/// and layout operations.
class BoardController extends Notifier<BoardState> {
  BoardController({
    VaultFileSystem? fs,
    StickyRepository? repository,
    VaultSettings? settings,
    Clock? clock,
    Random? random,
  }) : _injectedFs = fs,
       _injectedRepo = repository,
       _injectedSettings = settings,
       _injectedClock = clock,
       random = random ?? Random();

  final VaultFileSystem? _injectedFs;
  final StickyRepository? _injectedRepo;
  final VaultSettings? _injectedSettings;
  final Clock? _injectedClock;
  final Random random;

  VaultFileSystem get fs => _injectedFs ?? ref.read(vaultFsProvider);
  StickyRepository get repository =>
      _injectedRepo ?? ref.read(stickyRepositoryProvider);
  VaultSettings get settings =>
      _injectedSettings ?? ref.read(vaultSettingsProvider);
  Clock get clock => _injectedClock ?? ref.read(clockProvider);

  Timer? _saveTimer;
  StreamSubscription<StickyChange>? _changesSub;
  StreamSubscription<VaultChange>? _fsWatchSub;

  VaultPath get boardPath {
    final folder = settings.stickyFolder;
    return VaultPath(
      folder.isEmpty ? 'Sticky board.canvas' : '$folder/Sticky board.canvas',
    );
  }

  @override
  BoardState build() {
    ref.onDispose(dispose);
    final initialState = BoardState(
      doc: CanvasDocument(nodes: const [], edges: const []),
      isLoading: true,
    );
    unawaited(start());
    return initialState;
  }

  /// Initial load of the board file and subscription setup.
  Future<void> start() async {
    _changesSub = repository.changes.listen((change) {
      _onStickiesChanged();
    });

    try {
      _fsWatchSub = fs.watch().listen((event) {
        if (event is FileModified && event.path == boardPath) {
          load();
        }
      });
    } catch (_) {
      // Memory filesystems or unwatchable paths
    }

    await load();
  }

  /// Loads or reloads the board document from disk.
  Future<void> load() async {
    final path = boardPath;
    final exists = (await fs.stat(path)) != null;

    if (!exists) {
      final doc = CanvasDocument(nodes: const [], edges: const []);
      final reconcile = reconcileBoard(
        doc,
        repository.all,
        random: random,
        stickyFolder: VaultPath(settings.stickyFolder),
      );

      state = state.copyWith(
        doc: reconcile.doc,
        isBroken: false,
        isLoading: false,
      );

      if (reconcile.changed) {
        _scheduleSave();
      }
      return;
    }

    // File exists, attempt to read and parse
    try {
      final bytes = await fs.readBytes(path);
      final jsonStr = utf8.decode(bytes);
      final parsed = CanvasDocument.parse(jsonStr);

      final reconcile = reconcileBoard(
        parsed,
        repository.all,
        random: random,
        stickyFolder: VaultPath(settings.stickyFolder),
      );

      state = state.copyWith(
        doc: reconcile.doc,
        isBroken: false,
        isLoading: false,
      );

      if (reconcile.changed) {
        _scheduleSave();
      }
    } catch (_) {
      state = state.copyWith(isBroken: true, isLoading: false);
    }
  }

  /// Creates a new board by backing up the broken file and resetting.
  Future<void> createNewBoard() async {
    final path = boardPath;
    final now = clock.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${pad2(now.month)}-${pad2(now.day)} '
        '${pad2(now.hour)}${pad2(now.minute)}';

    final folder = settings.stickyFolder;
    final brokenPath = VaultPath(
      folder.isEmpty
          ? 'Sticky board (broken $stamp).canvas'
          : '$folder/Sticky board (broken $stamp).canvas',
    );

    try {
      if ((await fs.stat(path)) != null) {
        await fs.move(path, brokenPath);
      }
    } catch (_) {}

    final doc = CanvasDocument(nodes: const [], edges: const []);
    final reconcile = reconcileBoard(
      doc,
      repository.all,
      random: random,
      stickyFolder: VaultPath(settings.stickyFolder),
    );

    state = state.copyWith(doc: reconcile.doc, isBroken: false);

    await _saveImmediately();
  }

  void selectNode(String? nodeId) {
    state = state.copyWith(
      selectedNodeId: nodeId,
      clearSelected: nodeId == null,
    );
  }

  /// Updates node position and schedules a debounced save.
  void updateNodePosition(String nodeId, Offset newPosition) {
    final nodes = state.doc.nodes.map((n) {
      if (n.id == nodeId) {
        return n.copyWith(x: newPosition.dx.round(), y: newPosition.dy.round());
      }
      return n;
    }).toList();

    state = state.copyWith(doc: state.doc.copyWith(nodes: nodes));

    _scheduleSave();
  }

  /// Applies an automatic layout arrangement and retains previous positions for undo.
  void applyLayout(BoardLayoutMode mode) {
    if (mode == BoardLayoutMode.free) return;

    final stickyNodes = state.doc.nodes.where((n) => n.type == 'file').toList();
    final stickyByPath = {for (final s in repository.all) s.path.value: s};

    final previousPositions = {
      for (final n in state.doc.nodes)
        n.id: Offset(n.x.toDouble(), n.y.toDouble()),
    };

    final newPositions = layoutBoard(stickyNodes, stickyByPath, mode);

    final updatedNodes = state.doc.nodes.map((n) {
      if (newPositions.containsKey(n.id)) {
        final pos = newPositions[n.id]!;
        return n.copyWith(x: pos.dx.round(), y: pos.dy.round());
      }
      return n;
    }).toList();

    state = state.copyWith(
      doc: state.doc.copyWith(nodes: updatedNodes),
      undoPositions: previousPositions,
    );

    _scheduleSave();
  }

  /// Restores positions prior to the last auto-layout operation.
  void undoLayout() {
    final undos = state.undoPositions;
    if (undos == null) return;

    final updatedNodes = state.doc.nodes.map((n) {
      if (undos.containsKey(n.id)) {
        final pos = undos[n.id]!;
        return n.copyWith(x: pos.dx.round(), y: pos.dy.round());
      }
      return n;
    }).toList();

    state = state.copyWith(
      doc: state.doc.copyWith(nodes: updatedNodes),
      clearUndo: true,
    );

    _scheduleSave();
  }

  /// Creates a new sticky and places a canvas node at the given scene position.
  Future<Sticky> createStickyAt(
    Offset canvasOffset, {
    String body = '',
    StickyColor? color,
  }) async {
    final sticky = await repository.create(body: body, color: color);

    final newNode = CanvasNode(
      id: generateCanvasNodeId(random),
      type: 'file',
      x: canvasOffset.dx.round(),
      y: canvasOffset.dy.round(),
      width: 260,
      height: 220,
      file: sticky.path.value,
      color: stickyColorToCanvasColor(sticky.meta.color),
    );

    final updatedNodes = [...state.doc.nodes, newNode];
    state = state.copyWith(
      doc: state.doc.copyWith(nodes: updatedNodes),
      selectedNodeId: newNode.id,
    );

    _scheduleSave();
    return sticky;
  }

  /// Toggles a task checkbox item at the given line of a note.
  Future<void> toggleTask(VaultPath path, int line) async {
    final sticky = repository.byPath(path);
    if (sticky == null || sticky.meta.locked) return;

    final newText = toggleTaskAtLine(sticky.text, line);
    if (newText != null && newText != sticky.text) {
      await repository.setText(path, newText);
    }
  }

  void _onStickiesChanged() {
    if (state.isBroken) return;

    final reconcile = reconcileBoard(
      state.doc,
      repository.all,
      random: random,
      stickyFolder: VaultPath(settings.stickyFolder),
    );

    if (reconcile.changed) {
      state = state.copyWith(doc: reconcile.doc);
      _scheduleSave();
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () {
      _saveImmediately();
    });
  }

  /// Flushes any pending debounced save immediately to disk.
  Future<void> flush() async {
    if (_saveTimer == null) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    await _saveImmediately();
  }

  Future<void> _saveImmediately() async {
    if (state.isBroken) return;
    try {
      final text = state.doc.encode();
      try {
        final current = await fs.readText(boardPath);
        if (current.text == text) return;
      } catch (_) {}
      await fs.writeText(boardPath, TextDocument(text: text));
    } catch (_) {}
  }

  void dispose() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _changesSub?.cancel();
    _changesSub = null;
    _fsWatchSub?.cancel();
    _fsWatchSub = null;
  }
}
