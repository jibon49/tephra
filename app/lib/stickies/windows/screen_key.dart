// © 2026 Tephra. All rights reserved.

import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';

/// Formats a stable screen key from a display name and size in logical pixels.
///
/// Format: `<display name>|<width>x<height>` (e.g. `DELL U2720Q|2560x1440`).
String computeScreenKey({String? name, required Size size}) {
  final cleanName = (name != null && name.trim().isNotEmpty)
      ? name.trim()
      : 'Display';
  return '$cleanName|${size.width.toInt()}x${size.height.toInt()}';
}

/// Formats a stable screen key for a [Display].
String screenKeyForDisplay(Display display) {
  return computeScreenKey(name: display.name, size: display.size);
}

/// Extracts the display name part from a stable screen key.
String displayNameFromScreenKey(String screenKey) {
  final pipeIndex = screenKey.indexOf('|');
  if (pipeIndex == -1) return screenKey;
  return screenKey.substring(0, pipeIndex);
}
