// © 2026 Tephra. All rights reserved.

import 'dart:async';

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

/// Android stub implementation of [OverlayService].
class AndroidOverlayService implements OverlayService {
  @override
  Future<bool> hasPermission() {
    throw UnimplementedError(
      'AndroidOverlayService.hasPermission will be implemented in step 04.14',
    );
  }

  @override
  Future<bool> requestPermission() {
    throw UnimplementedError(
      'AndroidOverlayService.requestPermission will be implemented in step 04.14',
    );
  }

  @override
  Future<void> showBubble(String stickyPath) {
    throw UnimplementedError(
      'AndroidOverlayService.showBubble will be implemented in step 04.14',
    );
  }

  @override
  Future<void> closeBubble() {
    throw UnimplementedError(
      'AndroidOverlayService.closeBubble will be implemented in step 04.14',
    );
  }

  @override
  Future<bool> isActive() {
    throw UnimplementedError(
      'AndroidOverlayService.isActive will be implemented in step 04.14',
    );
  }

  @override
  Future<void> send(Map<String, Object?> message) {
    throw UnimplementedError(
      'AndroidOverlayService.send will be implemented in step 04.14',
    );
  }

  @override
  Stream<Map<String, Object?>> get messages => throw UnimplementedError(
    'AndroidOverlayService.messages will be implemented in step 04.14',
  );
}
