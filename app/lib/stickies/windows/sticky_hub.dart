// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../settings/app_settings.dart';
import '../data/open_note_bridge.dart';
import '../data/sticky_edit_applier.dart';
import '../data/sticky_positions_store.dart';
import '../data/sticky_repository.dart';
import '../model/sticky_color.dart';
import '../model/sticky_frontmatter.dart';
import 'sticky_protocol.dart';
import 'sticky_window_geometry.dart';
import 'text_merger.dart';
import 'window_bus.dart';

export '../data/sticky_edit_applier.dart' show ConflictCopyNamer;

final _log = Logger('sticky_hub');

class _OpenWindowState {
  _OpenWindowState({required this.windowId, required this.path});

  final String windowId;
  VaultPath path;
  final LinkedHashMap<String, String> sentHistory =
      LinkedHashMap<String, String>();
  StickyGeometry? lastPosition;

  void recordSent(String hash, String text) {
    sentHistory[hash] = text;
    while (sentHistory.length > 20) {
      sentHistory.remove(sentHistory.keys.first);
    }
  }
}

/// The main-window single writer coordinating floating sticky windows.
class StickyHub {
  StickyHub({
    required this.bus,
    required this.repo,
    required this.openNotes,
    required this.merger,
    required this.positions,
    required this.conflictNamer,
    required this.clock,
    StickyEditApplier? applier,
    this.screenRetriever,
    this.getAppSettings,
    this.updateAppSettings,
    this.onNotify,
  }) : applier =
           applier ??
           StickyEditApplier(
             repo: repo,
             openNotes: openNotes,
             merger: merger,
             conflictNamer: conflictNamer,
           );

  final WindowBus bus;
  final StickyRepository repo;
  final OpenNoteBridge openNotes;
  final TextMerger merger;
  final StickyPositionsStore positions;
  final ConflictCopyNamer conflictNamer;
  final Clock clock;
  final StickyEditApplier applier;
  final Future<List<ScreenInfo>> Function()? screenRetriever;
  final AppSettings Function()? getAppSettings;
  final Future<void> Function(AppSettings)? updateAppSettings;
  final void Function(String message)? onNotify;

  final Map<VaultPath, _OpenWindowState> _windows = {};
  final Map<String, VaultPath> _windowIdToPath = {};
  final Map<VaultPath, Future<void>> _pathChains = {};
  final Map<VaultPath, Rect> _pendingBounds = {};
  final Map<VaultPath, bool> _pendingFocusEdit = {};
  final Set<VaultPath> _closingForHideAll = {};
  final Set<VaultPath> _closingForQuit = {};

  StreamSubscription<void>? _incomingSub;
  StreamSubscription<void>? _repoSub;
  StreamSubscription<void>? _openNotesSub;
  StreamSubscription<void>? _openWindowsSub;

  /// Returns the set of all note paths currently open in floating sticky windows.
  Set<VaultPath> get openPaths => Set.unmodifiable(_windows.keys);

  /// Computes the protocol SHA-256 hash on '\n'-normalized text.
  static String hashProtocolText(String text) {
    return contentHash(utf8.encode(text.replaceAll('\r\n', '\n')));
  }

  /// Starts listening to messages, vault changes, and tab edits.
  Future<void> start() async {
    _incomingSub = bus.incoming.listen((event) {
      final (fromId, message) = event;
      unawaited(_handleIncoming(fromId, message));
    });

    _repoSub = repo.changes.listen((change) {
      unawaited(_handleRepoChange(change));
    });

    _openNotesSub = openNotes.edited.listen((path) {
      unawaited(_handleOpenNoteEdited(path));
    });

    _openWindowsSub = bus.openWindowIds.listen((liveWindowIds) {
      _handleOpenWindowsChanged(liveWindowIds);
    });
  }

  /// Opens a floating sticky window for [path].
  ///
  /// If a window is already open for this note, focuses/brings it to front instead.
  Future<void> open(VaultPath path, {bool focusEdit = false}) async {
    final existing = _windows[path];
    if (existing != null) {
      // One window per path: focus existing
      _log.fine('Window for $path already open with id ${existing.windowId}');
      return;
    }

    _pendingFocusEdit[path] = focusEdit;
    try {
      final screens = await (screenRetriever?.call() ?? getScreenInfos());
      Rect bounds;
      if (positions.mine.containsKey(path)) {
        bounds = toGlobal(positions.mine[path]!, screens);
      } else {
        // Cascade: first free slot starting at primary work-area top-right minus (320, -40),
        // each next one offset (-24, +24).
        final primary =
            screens.where((s) => s.isPrimary).firstOrNull ??
            screens.firstOrNull;
        final work = primary?.workArea ?? const Rect.fromLTWH(0, 0, 1920, 1040);
        final startX = (work.right - 320).round();
        final startY = (work.top + 40).round();

        var k = 0;
        while (true) {
          final candX = startX - 24 * k;
          final candY = startY + 24 * k;
          final isOccupied = _windows.values.any((w) {
            final p = w.lastPosition;
            if (p == null) return false;
            return (p.x - candX).abs() < 12 && (p.y - candY).abs() < 12;
          });
          if (!isOccupied || k >= 50) {
            bounds = Rect.fromLTWH(
              candX.toDouble(),
              candY.toDouble(),
              280,
              260,
            );
            break;
          }
          k++;
        }
        final geom = toStored(bounds, screens, collapsed: false);
        await positions.save(path, geom);
      }
      _pendingBounds[path] = bounds;

      final args = StickyWindowArgs(mainWindowId: bus.selfId, path: path.value);
      final winId = await bus.createStickyWindow(args);
      final state = _OpenWindowState(windowId: winId, path: path);
      _windows[path] = state;
      _windowIdToPath[winId] = path;
    } catch (e, st) {
      _log.warning('Failed to create sticky window for $path', e, st);
    }
  }

  /// Closes the window for [path] with the given [reason].
  Future<void> closeWindow(VaultPath path, {required String reason}) async {
    final win = _windows[path];
    if (win == null) return;
    try {
      await bus.send(
        win.windowId,
        CloseRequestMessage(path: path.value, reason: reason),
      );
    } catch (e, st) {
      _log.fine('Window ${win.windowId} gone on closeWindow', e, st);
    }
  }

  /// Shows sticky windows for active stickies up to maxWindows.
  Future<void> showAll({int? maxWindows}) async {
    final settings = getAppSettings?.call();
    final effectiveMax = maxWindows ?? settings?.stickiesMaxWindows ?? 20;
    if (updateAppSettings != null && settings != null) {
      await updateAppSettings!(settings.copyWith(stickiesHiddenAll: false));
    }

    final active = repo.all.toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));

    var count = 0;
    for (final sticky in active) {
      if (count >= effectiveMax) break;
      if (!_windows.containsKey(sticky.path)) {
        await open(sticky.path);
      }
      count++;
    }

    if (active.length > effectiveMax) {
      onNotify?.call('Showing $effectiveMax of ${active.length} stickies');
    }
  }

  /// Hides all open sticky windows by sending closeRequest(hideAll).
  Future<void> hideAll() async {
    final settings = getAppSettings?.call();
    if (updateAppSettings != null && settings != null) {
      await updateAppSettings!(settings.copyWith(stickiesHiddenAll: true));
    }

    final copy = _windows.values.toList();
    for (final win in copy) {
      _closingForHideAll.add(win.path);
      try {
        await bus.send(
          win.windowId,
          CloseRequestMessage(path: win.path.value, reason: 'hideAll'),
        );
      } catch (e, st) {
        _log.fine('Window ${win.windowId} gone on hideAll', e, st);
      }
    }
  }

  /// Restores floating sticky windows on application startup if configured.
  Future<void> restoreOnStart() async {
    final settings = getAppSettings?.call();
    final restore = settings?.stickiesRestoreOnStart ?? true;
    final hiddenAll = settings?.stickiesHiddenAll ?? false;
    if (!restore || hiddenAll) return;

    final minePaths = positions.mine.keys.toList();
    for (final path in minePaths) {
      final sticky = repo.byPath(path);
      if (sticky != null && sticky.meta.pinned) {
        await open(path);
      } else {
        await positions.remove(path);
      }
    }
  }

  /// Closes all open sticky windows cleanly before the main application quits.
  Future<void> closeAllForQuit() async {
    if (_windows.isEmpty) return;

    final copy = _windows.values.toList();
    for (final win in copy) {
      _closingForQuit.add(win.path);
      try {
        await bus.send(
          win.windowId,
          CloseRequestMessage(path: win.path.value, reason: 'quit'),
        );
      } catch (e, st) {
        _log.fine('Window ${win.windowId} gone on closeAllForQuit', e, st);
      }
    }

    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_windows.isNotEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _handleIncoming(String fromId, StickyMessage message) async {
    switch (message) {
      case ReadyMessage():
        await _handleReady(fromId, VaultPath(message.path));

      case ContentChangedMessage():
        await _handleContentChanged(
          fromId,
          VaultPath(message.path),
          message.text,
          message.baseHash,
        );

      case SaveMessage():
        await _handleSave(fromId, VaultPath(message.path));

      case SetColorMessage():
        await repo.patch(
          VaultPath(message.path),
          StickyPatch(color: StickyColor.parse(message.color)),
        );

      case SetPinnedMessage():
        await repo.patch(
          VaultPath(message.path),
          StickyPatch(pinned: message.pinned),
        );

      case SetLockedMessage():
        await repo.patch(
          VaultPath(message.path),
          StickyPatch(locked: message.locked),
        );

      case PositionChangedMessage():
        await _handlePositionChanged(message);

      case CloseMessage():
        await _handleClose(fromId, VaultPath(message.path));

      case OpenInMainMessage():
        _log.info('Sticky requested open in main: ${message.path}');

      case NewStickyMessage():
        final newSticky = await repo.create();
        await open(newSticky.path);

      default:
        break;
    }
  }

  Future<void> _handleReady(String fromId, VaultPath path) async {
    final sticky = repo.byPath(path);
    if (sticky == null) {
      _log.fine('Received ready for non-existent sticky $path');
      return;
    }

    final text = openNotes.openText(path) ?? sticky.text;
    final hash = hashProtocolText(text);

    final screens = await (screenRetriever?.call() ?? getScreenInfos());
    final bounds =
        _pendingBounds.remove(path) ??
        (positions.mine.containsKey(path)
            ? toGlobal(positions.mine[path]!, screens)
            : null);
    final focusEdit = _pendingFocusEdit.remove(path) ?? false;

    final win =
        _windows[path] ?? _OpenWindowState(windowId: fromId, path: path);
    _windows[path] = win;
    _windowIdToPath[fromId] = path;
    win.recordSent(hash, text);

    try {
      await bus.send(
        fromId,
        OpenMessage(
          path: path.value,
          text: text,
          hash: hash,
          color: sticky.meta.color.yamlValue,
          pinned: sticky.meta.pinned,
          locked: sticky.meta.locked,
          collapsed: positions.mine[path]?.collapsed ?? false,
          title: sticky.title,
          focusEdit: focusEdit,
          x: bounds?.left,
          y: bounds?.top,
          width: bounds?.width,
          height: bounds?.height,
        ),
      );
    } catch (e, st) {
      _log.fine('Failed to send OpenMessage to $fromId', e, st);
    }
  }

  Future<void> _handleContentChanged(
    String fromId,
    VaultPath path,
    String text,
    String baseHash,
  ) {
    return _enqueue(path, () async {
      final win = _windows[path];
      final result = await applier.applyEdit(
        path: path,
        text: text,
        baseHash: baseHash,
        baseTextLookup: (h) => win?.sentHistory[h],
      );

      win?.recordSent(result.hash, result.text);

      final sticky = repo.byPath(path);
      try {
        await bus.send(
          fromId,
          UpdateMessage(
            path: path.value,
            text: result.text,
            hash: result.hash,
            color: sticky?.meta.color.yamlValue ?? 'yellow',
            pinned: sticky?.meta.pinned ?? false,
            locked: sticky?.meta.locked ?? false,
            title: sticky?.title ?? path.stem,
          ),
        );
      } catch (e, st) {
        _log.fine('Target $fromId gone when sending update', e, st);
      }
    });
  }

  Future<void> _handleSave(String fromId, VaultPath path) {
    return _enqueue(path, () async {
      final current =
          openNotes.openText(path) ?? (repo.byPath(path)?.text ?? '');
      final currentHash = hashProtocolText(current);
      try {
        await bus.send(
          fromId,
          SavedMessage(path: path.value, hash: currentHash),
        );
      } catch (e, st) {
        _log.fine('Target $fromId gone when sending saved', e, st);
      }
    });
  }

  Future<void> _handlePositionChanged(PositionChangedMessage msg) async {
    final path = VaultPath(msg.path);
    final geom = StickyGeometry(
      x: msg.x,
      y: msg.y,
      w: msg.w,
      h: msg.h,
      screen: msg.screen,
      collapsed: msg.collapsed,
    );

    final win = _windows[path];
    win?.lastPosition = geom;
    await positions.save(path, geom);
  }

  Future<void> _handleClose(String fromId, VaultPath path) async {
    _windows.remove(path);
    _windowIdToPath.remove(fromId);
    if (!_closingForHideAll.remove(path) && !_closingForQuit.remove(path)) {
      await positions.remove(path);
    }
  }

  Future<void> _handleRepoChange(StickyChange change) async {
    switch (change) {
      case StickyUpdated():
        final win = _windows[change.sticky.path];
        if (win != null) {
          final text =
              openNotes.openText(change.sticky.path) ?? change.sticky.text;
          final hash = hashProtocolText(text);
          if (!win.sentHistory.containsKey(hash)) {
            win.recordSent(hash, text);
            try {
              await bus.send(
                win.windowId,
                UpdateMessage(
                  path: change.sticky.path.value,
                  text: text,
                  hash: hash,
                  color: change.sticky.meta.color.yamlValue,
                  pinned: change.sticky.meta.pinned,
                  locked: change.sticky.meta.locked,
                  title: change.sticky.title,
                ),
              );
            } catch (e, st) {
              _log.fine('Window gone on repo update', e, st);
            }
          }
        }

      case StickyRemoved():
        final win = _windows[change.path];
        if (win != null) {
          try {
            await bus.send(
              win.windowId,
              CloseRequestMessage(path: change.path.value, reason: 'unpinned'),
            );
          } catch (e, st) {
            _log.fine('Window gone on sticky removed', e, st);
          }
        }

      case StickyMoved():
        final oldWin = _windows.remove(change.from);
        if (oldWin != null) {
          _windowIdToPath.remove(oldWin.windowId);
          try {
            await bus.send(
              oldWin.windowId,
              CloseRequestMessage(path: change.from.value, reason: 'unpinned'),
            );
          } catch (e, st) {
            _log.fine('Window gone on sticky moved', e, st);
          }
          await positions.rename(change.from, change.path);
          await open(change.path);
        }

      default:
        break;
    }
  }

  Future<void> _handleOpenNoteEdited(VaultPath path) async {
    final win = _windows[path];
    if (win == null) return;

    final openText = openNotes.openText(path);
    if (openText == null) return;

    final hash = hashProtocolText(openText);
    if (!win.sentHistory.containsKey(hash)) {
      win.recordSent(hash, openText);
      final sticky = repo.byPath(path);
      try {
        await bus.send(
          win.windowId,
          UpdateMessage(
            path: path.value,
            text: openText,
            hash: hash,
            color: sticky?.meta.color.yamlValue ?? 'yellow',
            pinned: sticky?.meta.pinned ?? false,
            locked: sticky?.meta.locked ?? false,
            title: sticky?.title ?? path.stem,
          ),
        );
      } catch (e, st) {
        _log.fine('Window gone on open note edit', e, st);
      }
    }
  }

  void _handleOpenWindowsChanged(Set<String> liveIds) {
    final disappeared = <VaultPath>[];
    for (final entry in _windows.entries) {
      if (!liveIds.contains(entry.value.windowId)) {
        disappeared.add(entry.key);
      }
    }
    for (final path in disappeared) {
      final win = _windows.remove(path);
      if (win != null) {
        _windowIdToPath.remove(win.windowId);
      }
      // Note: geometry entry is preserved (only CloseMessage removes geometry)
    }
  }

  Future<void> _enqueue(VaultPath path, Future<void> Function() action) {
    final previous = _pathChains[path] ?? Future.value();
    final next = previous.then(
      (_) => action(),
      onError: (Object e, StackTrace st) {
        _log.warning('Error in path queue for $path', e, st);
      },
    );
    _pathChains[path] = next;
    return next;
  }

  /// Cancels subscriptions and releases resources.
  Future<void> dispose() async {
    await _incomingSub?.cancel();
    _incomingSub = null;
    await _repoSub?.cancel();
    _repoSub = null;
    await _openNotesSub?.cancel();
    _openNotesSub = null;
    await _openWindowsSub?.cancel();
    _openWindowsSub = null;
    _windows.clear();
    _windowIdToPath.clear();
  }
}
