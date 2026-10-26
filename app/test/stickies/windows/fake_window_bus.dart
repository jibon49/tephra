// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra/stickies/windows/sticky_protocol.dart';
import 'package:tephra/stickies/windows/window_bus.dart';

/// In-memory network coordinating a group of [FakeWindowBus] instances.
class FakeWindowNetwork {
  FakeWindowNetwork();

  int _nextWindowId = 1;
  final Map<String, FakeWindowBus> _buses = {};
  final Map<String, StickyWindowArgs> _windowArgs = {};

  /// All currently open window IDs.
  Set<String> get openWindowIds => Set.unmodifiable(_buses.keys);

  /// Creates and registers a new [FakeWindowBus] with [windowId].
  FakeWindowBus createBus(String windowId) {
    if (_buses.containsKey(windowId)) {
      throw StateError('Window $windowId already exists in network');
    }
    final bus = FakeWindowBus._(this, selfId: windowId);
    _buses[windowId] = bus;
    _broadcastOpenWindows();
    return bus;
  }

  /// Allocates a new sticky window ID and creates its [FakeWindowBus].
  String createStickyWindow(StickyWindowArgs args) {
    final windowId = 'sticky_${_nextWindowId++}';
    _windowArgs[windowId] = args;
    createBus(windowId);
    return windowId;
  }

  /// Returns the [StickyWindowArgs] used to create [windowId], if any.
  StickyWindowArgs? argsFor(String windowId) => _windowArgs[windowId];

  /// Returns the [FakeWindowBus] for [windowId], or null if closed / does not exist.
  FakeWindowBus? busFor(String windowId) => _buses[windowId];

  /// Closes and unregisters [windowId] from the network.
  void close(String windowId) {
    final bus = _buses.remove(windowId);
    if (bus != null) {
      bus._markClosed();
      _broadcastOpenWindows();
    }
  }

  void _routeMessage(String fromId, String toId, StickyMessage message) {
    final target = _buses[toId];
    if (target == null || target.isClosed) {
      throw WindowGoneException(toId);
    }

    // Deliver asynchronously via microtask to preserve send order while decoupling execution.
    scheduleMicrotask(() {
      if (!target.isClosed) {
        target._receive(fromId, message);
      }
    });
  }

  void _broadcastOpenWindows() {
    final currentIds = openWindowIds;
    for (final bus in _buses.values) {
      if (!bus.isClosed) {
        bus._notifyOpenWindows(currentIds);
      }
    }
  }
}

/// In-memory test implementation of [WindowBus].
class FakeWindowBus implements WindowBus {
  FakeWindowBus._(this._network, {required this.selfId});

  final FakeWindowNetwork _network;
  bool _isClosed = false;

  /// Whether this window has been closed or disposed.
  bool get isClosed => _isClosed;

  final StreamController<(String fromWindowId, StickyMessage message)>
  _incomingController = StreamController.broadcast();
  final StreamController<Set<String>> _openWindowsController =
      StreamController.broadcast();

  @override
  final String selfId;

  @override
  Stream<(String fromWindowId, StickyMessage message)> get incoming =>
      _incomingController.stream;

  @override
  Stream<Set<String>> get openWindowIds => _openWindowsController.stream;

  @override
  Future<void> send(String toWindowId, StickyMessage message) async {
    if (_isClosed) {
      throw WindowGoneException(toWindowId);
    }
    _network._routeMessage(selfId, toWindowId, message);
  }

  @override
  Future<String> createStickyWindow(StickyWindowArgs args) async {
    if (_isClosed) {
      throw StateError('Cannot create sticky window from a disposed bus');
    }
    return _network.createStickyWindow(args);
  }

  void _receive(String fromId, StickyMessage message) {
    if (!_isClosed && !_incomingController.isClosed) {
      _incomingController.add((fromId, message));
    }
  }

  void _notifyOpenWindows(Set<String> ids) {
    if (!_isClosed && !_openWindowsController.isClosed) {
      _openWindowsController.add(ids);
    }
  }

  void _markClosed() {
    _isClosed = true;
    _incomingController.close();
    _openWindowsController.close();
  }

  @override
  Future<void> dispose() async {
    if (_isClosed) return;
    _network.close(selfId);
  }
}
