// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tephra/stickies/model/task_toggle.dart';

import 'sticky_protocol.dart';
import 'window_bus.dart';

final _log = Logger('sticky_window_controller');

/// Pure business logic controller for a single floating sticky note window.
class StickyWindowController extends ChangeNotifier {
  StickyWindowController({
    required this.bus,
    required this.mainWindowId,
    required this.path,
    this.onCloseWindow,
  });

  final WindowBus bus;
  final String mainWindowId;
  final String path;
  final Future<void> Function()? onCloseWindow;

  String _localText = '';
  String _appliedText = '';
  String _appliedHash = '';
  bool _dirty = false;
  String _color = 'yellow';
  bool _pinned = false;
  bool _locked = false;
  bool _collapsed = false;
  String _title = '';

  Timer? _debounceTimer;
  Timer? _geomDebounceTimer;
  Completer<void>? _saveCompleter;
  StreamSubscription<void>? _incomingSub;

  String get localText => _localText;
  String get appliedText => _appliedText;
  String get appliedHash => _appliedHash;
  bool get dirty => _dirty;
  String get color => _color;
  bool get pinned => _pinned;
  bool get locked => _locked;
  bool get collapsed => _collapsed;
  String get title =>
      _title.isEmpty ? path.split('/').last.replaceAll('.md', '') : _title;

  /// Starts listening to messages from the main window and emits [ReadyMessage].
  Future<void> start() async {
    _incomingSub = bus.incoming.listen((event) {
      final (fromId, message) = event;
      if (fromId != mainWindowId) return;
      _handleMessage(message);
    });

    try {
      await bus.send(mainWindowId, ReadyMessage(path: path));
    } catch (e, st) {
      _log.warning('Failed to send ReadyMessage to main window', e, st);
    }
  }

  void _handleMessage(StickyMessage message) {
    switch (message) {
      case OpenMessage():
        if (message.path != path) return;
        _color = message.color;
        _pinned = message.pinned;
        _locked = message.locked;
        _collapsed = message.collapsed;
        _title = message.title;
        _appliedText = message.text;
        _appliedHash = message.hash;
        if (!_dirty) {
          _localText = message.text;
        } else {
          _scheduleSend();
        }
        notifyListeners();

      case UpdateMessage():
        if (message.path != path) return;
        _color = message.color;
        _pinned = message.pinned;
        _locked = message.locked;
        _title = message.title;
        _appliedText = message.text;
        _appliedHash = message.hash;
        if (!_dirty) {
          _localText = message.text;
        } else {
          _scheduleSend();
        }
        notifyListeners();

      case SavedMessage():
        if (message.path == path) {
          if (_saveCompleter != null && !_saveCompleter!.isCompleted) {
            _saveCompleter!.complete();
          }
        }

      case CloseRequestMessage():
        if (message.path == path) {
          unawaited(_handleCloseRequest(message.reason));
        }

      default:
        break;
    }
  }

  /// Called when the user edits note text in the sticky window.
  void onTextChanged(String newText) {
    if (_locked) return;
    if (_localText == newText) return;

    _localText = newText;
    _dirty = true;
    notifyListeners();

    _scheduleSend();
  }

  void _scheduleSend() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_sendContentChanged());
    });
  }

  Future<void> _sendContentChanged() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (!_dirty) return;

    final textToSend = _localText;
    final baseHashToSend = _appliedHash;
    _dirty = false;

    try {
      await bus.send(
        mainWindowId,
        ContentChangedMessage(
          path: path,
          text: textToSend,
          baseHash: baseHashToSend,
        ),
      );
    } catch (e, st) {
      _log.warning('Failed to send contentChanged to main window', e, st);
      _dirty = true;
    }
  }

  /// Toggles task checkbox on line [lineIndex] if not locked.
  void toggleTask(int lineIndex) {
    if (_locked) return;
    final toggled = toggleTaskAtLine(_localText, lineIndex);
    if (toggled != null) {
      onTextChanged(toggled);
    }
  }

  /// Updates sticky color.
  Future<void> setColor(String newColor) async {
    _color = newColor;
    notifyListeners();
    try {
      await bus.send(
        mainWindowId,
        SetColorMessage(path: path, color: newColor),
      );
    } catch (e, st) {
      _log.warning('Failed to send setColor', e, st);
    }
  }

  /// Toggles always-on-top pinned status.
  Future<void> setPinned(bool newPinned) async {
    _pinned = newPinned;
    notifyListeners();
    try {
      await bus.send(
        mainWindowId,
        SetPinnedMessage(path: path, pinned: newPinned),
      );
    } catch (e, st) {
      _log.warning('Failed to send setPinned', e, st);
    }
  }

  /// Toggles locked status.
  Future<void> setLocked(bool newLocked) async {
    _locked = newLocked;
    notifyListeners();
    try {
      await bus.send(
        mainWindowId,
        SetLockedMessage(path: path, locked: newLocked),
      );
    } catch (e, st) {
      _log.warning('Failed to send setLocked', e, st);
    }
  }

  /// Sends geometry update debounced by 500 ms.
  void onGeometryChanged({
    required int x,
    required int y,
    required int w,
    required int h,
    required String screen,
    required bool collapsed,
  }) {
    _collapsed = collapsed;
    notifyListeners();

    _geomDebounceTimer?.cancel();
    _geomDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      bus.send(
        mainWindowId,
        PositionChangedMessage(
          path: path,
          x: x,
          y: y,
          w: w,
          h: h,
          screen: screen,
          collapsed: collapsed,
        ),
      );
    });
  }

  /// Flushes any pending debounce and sends a [SaveMessage].
  Future<void> onFocusLost() async {
    await flush();
    try {
      await bus.send(mainWindowId, SaveMessage(path: path));
    } catch (e, st) {
      _log.fine('Failed to send SaveMessage on focus lost', e, st);
    }
  }

  /// Explicitly flushes any pending debounced text edit.
  Future<void> flush() async {
    if (_debounceTimer != null || _dirty) {
      await _sendContentChanged();
    }
  }

  /// Requests closing the window via the close button.
  Future<void> requestClose() async {
    await flush();
    await _sendSaveAndWait();
    try {
      await bus.send(mainWindowId, CloseMessage(path: path));
    } catch (e, st) {
      _log.fine('Failed to send CloseMessage', e, st);
    }
    await onCloseWindow?.call();
  }

  /// Requests opening this note in the main Tephra window.
  Future<void> requestOpenInMain() async {
    try {
      await bus.send(mainWindowId, OpenInMainMessage(path: path));
    } catch (e, st) {
      _log.warning('Failed to send OpenInMainMessage', e, st);
    }
  }

  /// Requests creating a new sticky note from this window.
  Future<void> requestNewSticky() async {
    try {
      await bus.send(mainWindowId, const NewStickyMessage());
    } catch (e, st) {
      _log.warning('Failed to send NewStickyMessage', e, st);
    }
  }

  Future<void> _handleCloseRequest(String reason) async {
    await flush();
    await _sendSaveAndWait();

    if (reason == 'unpinned' || reason == 'deleted') {
      try {
        await bus.send(mainWindowId, CloseMessage(path: path));
      } catch (e, st) {
        _log.fine('Failed to send CloseMessage on unpinned/deleted', e, st);
      }
    }
    await onCloseWindow?.call();
  }

  Future<void> _sendSaveAndWait() async {
    _saveCompleter = Completer<void>();
    try {
      await bus.send(mainWindowId, SaveMessage(path: path));
      await _saveCompleter!.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          _log.fine('Timed out waiting for SavedMessage on path $path');
        },
      );
    } catch (e, st) {
      _log.fine('Save failed or target gone', e, st);
    } finally {
      _saveCompleter = null;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _geomDebounceTimer?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }
}
