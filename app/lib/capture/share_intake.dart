// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/platform/share_intent_service.dart';

/// Draft capture content containing text, files, and an optional suggested title.
final class CaptureDraft {
  const CaptureDraft({required this.text, required this.files, this.title});

  final String text;
  final List<SharedFile> files;
  final String? title;

  CaptureDraft copyWith({
    String? text,
    List<SharedFile>? files,
    String? title,
  }) {
    return CaptureDraft(
      text: text ?? this.text,
      files: files ?? this.files,
      title: title ?? this.title,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureDraft &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          title == other.title &&
          listEquals(files, other.files);

  @override
  int get hashCode => Object.hash(text, title, Object.hashAll(files));

  @override
  String toString() =>
      'CaptureDraft(text: ${text.length} chars, files: ${files.length}, title: $title)';
}

/// Builds a [CaptureDraft] from [items] shared into Tephra.
CaptureDraft draftFromShare(List<SharedItem> items, {DateTime? now}) {
  final urlRegex = RegExp(r'^https?://\S+$');
  final invalidCharsRegex = RegExp(r'[\*\"\\\/<>:\|\?\x00-\x1F]');

  final formattedTexts = <String>[];
  final files = <SharedFile>[];

  for (final item in items) {
    if (item is SharedText) {
      final trimmed = item.text.trim();
      if (urlRegex.hasMatch(trimmed)) {
        formattedTexts.add('<$trimmed>');
      } else {
        formattedTexts.add(item.text);
      }
    } else if (item is SharedFile) {
      files.add(item);
    }
  }

  final fullText = formattedTexts.join('\n\n');

  String? title;
  if (fullText.trim().isNotEmpty) {
    final firstLine = fullText.split('\n').first.trim();
    final sanitized = firstLine.replaceAll(invalidCharsRegex, '').trim();
    if (sanitized.isNotEmpty) {
      title = sanitized.length > 60
          ? sanitized.substring(0, 60).trim()
          : sanitized;
    }
  }

  if (title == null || title.isEmpty) {
    final stamp = DateFormat('yyyy-MM-dd HHmm').format(now ?? DateTime.now());
    title = 'Shared $stamp';
  }

  return CaptureDraft(text: fullText, files: files, title: title);
}
