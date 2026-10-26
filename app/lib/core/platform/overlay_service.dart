// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Android overlay window service for floating sticky bubbles.
abstract interface class OverlayService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<void> showBubble(String stickyPath);
  Future<void> closeBubble();
  Future<bool> isActive();
  Future<void> send(
    Map<String, Object?> message,
  ); // to the overlay engine (JSON)
  Stream<Map<String, Object?>> get messages; // from the overlay engine
}

/// No-op implementation of [OverlayService] for unsupported platforms.
class NoopOverlayService implements OverlayService {
  const NoopOverlayService();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> showBubble(String stickyPath) async {}

  @override
  Future<void> closeBubble() async {}

  @override
  Future<bool> isActive() async => false;

  @override
  Future<void> send(Map<String, Object?> message) async {}

  @override
  Stream<Map<String, Object?>> get messages => const Stream.empty();
}

/// Android implementation of [OverlayService] using [FlutterOverlayWindow].
class AndroidOverlayService implements OverlayService {
  AndroidOverlayService({this.showExplanationDialog});

  final Future<bool> Function()? showExplanationDialog;

  @override
  Future<bool> hasPermission() async {
    return FlutterOverlayWindow.isPermissionGranted();
  }

  @override
  Future<bool> requestPermission() async {
    final show = showExplanationDialog;
    if (show != null) {
      final proceed = await show();
      if (!proceed) return false;
    }
    final res = await FlutterOverlayWindow.requestPermission();
    return res ?? false;
  }

  @override
  Future<void> showBubble(String stickyPath) async {
    final active = await FlutterOverlayWindow.isActive();
    if (active) {
      await FlutterOverlayWindow.closeOverlay();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    await FlutterOverlayWindow.showOverlay(
      height: 168, // 56 dp in px at standard 3.0 density
      width: 168,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.defaultFlag,
      positionGravity: PositionGravity.auto,
      enableDrag: false,
      overlayTitle: 'Tephra Sticky',
      overlayContent: 'Floating sticky note',
    );
  }

  @override
  Future<void> closeBubble() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Future<bool> isActive() async {
    return FlutterOverlayWindow.isActive();
  }

  @override
  Future<void> send(Map<String, Object?> message) async {
    await FlutterOverlayWindow.shareData(message);
  }

  @override
  Stream<Map<String, Object?>> get messages {
    return FlutterOverlayWindow.overlayListener.transform(
      StreamTransformer<dynamic, Map<String, Object?>>.fromHandlers(
        handleData: (data, sink) {
          if (data is Map) {
            sink.add(data.cast<String, Object?>());
          } else if (data is String) {
            try {
              final decoded = jsonDecode(data);
              if (decoded is Map) {
                sink.add(decoded.cast<String, Object?>());
              }
            } catch (_) {}
          }
        },
      ),
    );
  }
}
