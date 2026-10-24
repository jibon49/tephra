// © 2026 Tephra. All rights reserved.

import '../model/sticky_color.dart';

/// Maps Tephra sticky colors to and from Obsidian JSON Canvas 1.0 color presets.
///
/// Presets in JSON Canvas:
/// - "1" red / pink
/// - "2" orange (reads as pink)
/// - "3" yellow
/// - "4" green
/// - "5" cyan / blue
/// - "6" purple
/// - gray: key omitted in JSON Canvas
/// - hex: "#RRGGBB"
String? stickyColorToCanvasColor(StickyColor color) {
  if (color is NamedStickyColor) {
    switch (color.name) {
      case StickyColorName.yellow:
        return '3';
      case StickyColorName.pink:
        return '1';
      case StickyColorName.blue:
        return '5';
      case StickyColorName.green:
        return '4';
      case StickyColorName.purple:
        return '6';
      case StickyColorName.gray:
        return null;
    }
  } else if (color is HexStickyColor) {
    return color.yamlValue;
  }
  return '3';
}

StickyColor canvasColorToStickyColor(String? canvasColor) {
  if (canvasColor == null || canvasColor.trim().isEmpty) {
    return NamedStickyColor.gray;
  }

  final trimmed = canvasColor.trim();
  switch (trimmed) {
    case '1':
    case '2':
      return NamedStickyColor.pink;
    case '3':
      return NamedStickyColor.yellow;
    case '4':
      return NamedStickyColor.green;
    case '5':
      return NamedStickyColor.blue;
    case '6':
      return NamedStickyColor.purple;
  }

  if (trimmed.startsWith('#')) {
    return StickyColor.parse(trimmed);
  }

  return NamedStickyColor.yellow;
}
