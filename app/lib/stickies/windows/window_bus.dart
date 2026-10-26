// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:logging/logging.dart';

import 'sticky_protocol.dart';

final _log = Logger('window_bus');

/// Exception thrown when attempting to send a message to a window that has closed or does not exist.
class WindowGoneException implements Exception {
  const WindowGoneException(this.windowId);

  final String windowId;

  @override
  String toString() =>
      'WindowGoneException: Window $windowId does not exist or has closed';
}

/// The abstraction over desktop multi-window inter-process messaging.
abstract interface class WindowBus {
  /// The window identifier of the current engine.
  String get selfId;

  /// Sends a typed message to [toWindowId].
  ///
  /// Throws [WindowGoneException] if the target window is closed or unreachable.
  Future<void> send(String toWindowId, StickyMessage message);

  /// Stream of incoming messages received by this window, paired with the sender window ID.
  Stream<(String fromWindowId, StickyMessage message)> get incoming;

  /// Creates a new hidden sticky window with the given arguments and returns its ID.
  /// Only called by the main window.
  Future<String> createStickyWindow(StickyWindowArgs args);

  /// Broadcast stream emitting the set of all live window IDs on every window list change.
  Stream<Set<String>> get openWindowIds;

  /// Releases resources, unbinds method handlers, and cancels subscriptions.
  Future<void> dispose();
}

/// No-op implementation of [WindowBus] for unsupported platforms or stubbing.
final class NoopWindowBus implements WindowBus {
  const NoopWindowBus({this.selfId = 'main'});

  @override
  final String selfId;

  @override
  Future<void> send(String toWindowId, StickyMessage message) async {}

  @override
  Stream<(String fromWindowId, StickyMessage message)> get incoming =>
      const Stream.empty();

  @override
  Future<String> createStickyWindow(StickyWindowArgs args) async => 'noop';

  @override
  Stream<Set<String>> get openWindowIds => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

/// Production implementation of [WindowBus] backed by `package:desktop_multi_window`.
class DesktopWindowBus implements WindowBus {
  DesktopWindowBus._(this._currentController, {required this.selfId}) {
    _init();
  }

  @override
  final String selfId;

  final WindowController _currentController;
  final StreamController<(String fromWindowId, StickyMessage message)>
  _incomingController = StreamController.broadcast();
  final StreamController<Set<String>> _openWindowsController =
      StreamController.broadcast();

  StreamSubscription<void>? _windowsChangedSub;
  final Map<String, WindowController> _windows = {};

  /// Creates a [DesktopWindowBus] instance for the current Flutter engine.
  static Future<DesktopWindowBus> fromCurrentEngine() async {
    final current = await WindowController.fromCurrentEngine();
    final bus = DesktopWindowBus._(current, selfId: current.windowId);
    await bus._refreshWindows();
    return bus;
  }

  void _init() {
    _currentController.setWindowMethodHandler((call) async {
      if (call.method == 'tephra.sticky') {
        final args = call.arguments;
        if (args is Map) {
          final from = args['from']?.toString() ?? '';
          final rawMsg = args['msg'];
          if (rawMsg is Map) {
            final msg = StickyMessage.fromJson(rawMsg.cast<String, Object?>());
            if (msg != null && from.isNotEmpty) {
              _incomingController.add((from, msg));
            } else {
              _log.fine(
                'Ignored invalid or unknown message from $from: $rawMsg',
              );
            }
          }
        }
      }
      return null;
    });

    _windowsChangedSub = onWindowsChanged.listen((_) {
      unawaited(_refreshWindows());
    });
  }

  Future<void> _refreshWindows() async {
    try {
      final list = await WindowController.getAll();
      _windows.clear();
      for (final c in list) {
        _windows[c.windowId] = c;
      }
      if (!_openWindowsController.isClosed) {
        _openWindowsController.add(Set.unmodifiable(_windows.keys));
      }
    } catch (e, st) {
      _log.warning('Failed to refresh window list', e, st);
    }
  }

  @override
  Stream<(String fromWindowId, StickyMessage message)> get incoming =>
      _incomingController.stream;

  @override
  Stream<Set<String>> get openWindowIds => _openWindowsController.stream;

  @override
  Future<void> send(String toWindowId, StickyMessage message) async {
    var target = _windows[toWindowId];
    if (target == null) {
      await _refreshWindows();
      target = _windows[toWindowId];
    }

    if (target == null) {
      throw WindowGoneException(toWindowId);
    }

    try {
      await target.invokeMethod('tephra.sticky', {
        'from': selfId,
        'msg': message.toJson(),
      });
    } catch (e, st) {
      _log.fine('Failed to invoke method on window $toWindowId', e, st);
      throw WindowGoneException(toWindowId);
    }
  }

  @override
  Future<String> createStickyWindow(StickyWindowArgs args) async {
    try {
      final controller = await WindowController.create(
        WindowConfiguration(arguments: args.encode(), hiddenAtLaunch: true),
      );
      await _refreshWindows();
      return controller.windowId;
    } catch (e, st) {
      _log.severe(
        'Failed to create sticky window with args: ${args.encode()}',
        e,
        st,
      );
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    await _windowsChangedSub?.cancel();
    _windowsChangedSub = null;
    await _incomingController.close();
    await _openWindowsController.close();
    try {
      await _currentController.setWindowMethodHandler(null);
    } catch (_) {}
  }
}
