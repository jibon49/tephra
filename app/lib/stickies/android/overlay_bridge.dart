// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../core/platform/overlay_service.dart';
import '../data/open_note_bridge.dart';
import '../data/sticky_edit_applier.dart';
import '../data/sticky_repository.dart';
import 'overlay_protocol.dart';

final _log = Logger('overlay_bridge');

/// Coordinates the Android overlay floating sticky bubble with the main app repository.
///
/// Follows the single-writer principle: edits from the overlay are received as [OverlayContentChangedMessage],
/// applied through [StickyEditApplier], and confirmed with [OverlayAckMessage].
class OverlayBridge {
  OverlayBridge({
    required this.overlayService,
    required this.repo,
    required this.openNotes,
    required this.applier,
  });

  final OverlayService overlayService;
  final StickyRepository repo;
  final OpenNoteBridge openNotes;
  final StickyEditApplier applier;

  VaultPath? _currentPath;
  VaultPath? get currentPath => _currentPath;

  final Map<String, String> _sentHistory = {};
  String? _currentHash;
  String? get currentHash => _currentHash;

  StreamSubscription<Map<String, Object?>>? _messageSub;
  StreamSubscription<StickyChange>? _repoSub;

  /// Starts listening to incoming overlay messages and vault repository changes.
  void start() {
    _messageSub?.cancel();
    _messageSub = overlayService.messages.listen(_handleMessage);

    _repoSub?.cancel();
    _repoSub = repo.changes.listen(_handleRepoChange);
  }

  /// Cancels listeners and releases resources.
  void dispose() {
    _messageSub?.cancel();
    _messageSub = null;
    _repoSub?.cancel();
    _repoSub = null;
  }

  /// Opens or replaces the current floating sticky bubble with [path].
  Future<void> openBubble(VaultPath path) async {
    final sticky = repo.byPath(path);
    if (sticky == null) {
      _log.warning('Cannot open bubble for missing sticky $path');
      return;
    }

    final text = openNotes.openText(path) ?? sticky.text;
    final hash = hashProtocolText(text);

    _currentPath = path;
    _currentHash = hash;
    _sentHistory[hash] = text;

    await overlayService.showBubble(path.value);

    try {
      await overlayService.send(
        OverlayOpenMessage(
          path: path.value,
          text: text,
          hash: hash,
          color: sticky.meta.color.yamlValue,
          locked: sticky.meta.locked,
          title: sticky.title,
        ).toJson(),
      );
    } catch (e, st) {
      _log.fine('Failed to send open message to overlay', e, st);
    }
  }

  /// Closes the currently active floating sticky bubble if any.
  Future<void> closeBubble() async {
    _currentPath = null;
    _currentHash = null;
    _sentHistory.clear();
    await overlayService.closeBubble();
  }

  Future<void> _handleMessage(Map<String, Object?> raw) async {
    final message = OverlayMessage.fromJson(raw);
    if (message == null) return;

    switch (message) {
      case OverlayContentChangedMessage():
        await _handleContentChanged(message);

      case OverlayCloseMessage():
        await _handleClose(message);

      case OverlayPingMessage():
        await overlayService.send(const OverlayPongMessage().toJson());

      default:
        break;
    }
  }

  Future<void> _handleContentChanged(OverlayContentChangedMessage msg) async {
    final path = VaultPath(msg.path);
    final result = await applier.applyEdit(
      path: path,
      text: msg.text,
      baseHash: msg.baseHash,
      baseTextLookup: (h) => _sentHistory[h],
    );

    _currentHash = result.hash;
    _sentHistory[result.hash] = result.text;

    // Confirm the write to the overlay
    try {
      await overlayService.send(
        OverlayAckMessage(path: msg.path, hash: result.hash).toJson(),
      );
    } catch (e, st) {
      _log.fine('Failed to send ack to overlay', e, st);
    }

    // If text merged or changed, send update as well
    if (result.text != msg.text || result.isConflict) {
      final sticky = repo.byPath(path);
      try {
        await overlayService.send(
          OverlayUpdateMessage(
            path: msg.path,
            text: result.text,
            hash: result.hash,
            color: sticky?.meta.color.yamlValue ?? 'yellow',
            locked: sticky?.meta.locked ?? false,
            title: sticky?.title,
          ).toJson(),
        );
      } catch (e, st) {
        _log.fine('Failed to send update to overlay', e, st);
      }
    }
  }

  Future<void> _handleClose(OverlayCloseMessage msg) async {
    _currentPath = null;
    _currentHash = null;
    _sentHistory.clear();
    await overlayService.closeBubble();
  }

  void _handleRepoChange(StickyChange change) {
    if (_currentPath == null) return;
    final path = _currentPath!;

    if (change is StickyRemoved && change.path == path) {
      unawaited(closeBubble());
      return;
    }

    if (change.path == path) {
      final sticky = repo.byPath(path);
      if (sticky == null || !sticky.meta.isSticky) {
        unawaited(closeBubble());
        return;
      }

      final text = openNotes.openText(path) ?? sticky.text;
      final hash = hashProtocolText(text);

      if (hash != _currentHash) {
        _currentHash = hash;
        _sentHistory[hash] = text;
        try {
          overlayService.send(
            OverlayUpdateMessage(
              path: path.value,
              text: text,
              hash: hash,
              color: sticky.meta.color.yamlValue,
              locked: sticky.meta.locked,
              title: sticky.title,
            ).toJson(),
          );
        } catch (e, st) {
          _log.fine('Failed to send repo update to overlay', e, st);
        }
      }
    }
  }
}
