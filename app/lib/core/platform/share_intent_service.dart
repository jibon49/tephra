// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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

  @override
  String toString() => 'SharedText($text)';
}

/// File shared into Tephra.
final class SharedFile extends SharedItem {
  const SharedFile({required this.path, required this.mimeType, this.bytes});

  final String path;
  final String? mimeType;
  final List<int>? bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedFile &&
          path == other.path &&
          mimeType == other.mimeType &&
          listEquals(bytes, other.bytes);

  @override
  int get hashCode =>
      Object.hash(path, mimeType, bytes == null ? 0 : Object.hashAll(bytes!));

  @override
  String toString() =>
      'SharedFile(path: $path, mimeType: $mimeType, bytes: ${bytes?.length})';
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

/// Android implementation of [ShareIntentService] wrapping [ReceiveSharingIntent].
class AndroidShareIntentService implements ShareIntentService {
  @override
  Future<List<SharedItem>> initialShare() async {
    try {
      final media = await ReceiveSharingIntent.instance.getInitialMedia();
      return _mapMedia(media);
    } catch (_) {
      return const [];
    }
  }

  @override
  Stream<List<SharedItem>> get shares {
    return ReceiveSharingIntent.instance.getMediaStream().map(_mapMedia);
  }

  @override
  Future<void> markHandled() async {
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (_) {}
  }

  static List<SharedItem> _mapMedia(List<SharedMediaFile> media) {
    final result = <SharedItem>[];
    for (final file in media) {
      switch (file.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          final text = file.message ?? file.path;
          if (text.isNotEmpty) {
            result.add(SharedText(text));
          }
        case SharedMediaType.image:
        case SharedMediaType.video:
        case SharedMediaType.file:
          if (file.path.isNotEmpty) {
            result.add(SharedFile(path: file.path, mimeType: file.mimeType));
          }
      }
    }
    return result;
  }
}
