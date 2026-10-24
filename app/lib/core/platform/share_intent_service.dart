// © 2026 Tephra. All rights reserved.

import 'dart:async';

/// Base class for an item shared into Tephra.
sealed class SharedItem {
  const SharedItem();
}

/// Plain text shared into Tephra.
final class SharedText extends SharedItem {
  const SharedText(this.text);
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SharedText && text == other.text;

  @override
  int get hashCode => text.hashCode;
}

/// File shared into Tephra.
final class SharedFile extends SharedItem {
  const SharedFile({required this.path, required this.mimeType});
  final String path;
  final String? mimeType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedFile && path == other.path && mimeType == other.mimeType;

  @override
  int get hashCode => Object.hash(path, mimeType);
}

/// Service for receiving items shared from other apps.
abstract interface class ShareIntentService {
  Future<List<SharedItem>> initialShare(); // share that launched the app
  Stream<List<SharedItem>> get shares; // shares while running
  Future<void> markHandled();
}

/// No-op implementation of [ShareIntentService] for unsupported platforms.
class NoopShareIntentService implements ShareIntentService {
  const NoopShareIntentService();

  @override
  Future<List<SharedItem>> initialShare() async => const [];

  @override
  Stream<List<SharedItem>> get shares => const Stream.empty();

  @override
  Future<void> markHandled() async {}
}

/// Android stub implementation of [ShareIntentService].
class AndroidShareIntentService implements ShareIntentService {
  @override
  Future<List<SharedItem>> initialShare() {
    throw UnimplementedError(
      'AndroidShareIntentService.initialShare will be implemented in step 04.15',
    );
  }

  @override
  Stream<List<SharedItem>> get shares => throw UnimplementedError(
    'AndroidShareIntentService.shares will be implemented in step 04.15',
  );

  @override
  Future<void> markHandled() {
    throw UnimplementedError(
      'AndroidShareIntentService.markHandled will be implemented in step 04.15',
    );
  }
}
