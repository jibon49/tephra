// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

/// Names of built-in light card sticky colors.
enum StickyColorName { yellow, pink, blue, green, purple, gray }

/// Card background and text color representation for sticky notes.
sealed class StickyColor {
  const StickyColor();

  /// Fallback color used when parsing fails or no color is set.
  static const StickyColor fallback = NamedStickyColor.yellow;

  /// Parses a color from YAML values, strings, or object instances.
  /// Never throws; invalid inputs fall back to [fallback] (yellow).
  static StickyColor parse(Object? raw) {
    if (raw is! String) return fallback;
    final s = raw.trim();
    if (s.isEmpty) return fallback;

    final lower = s.toLowerCase();
    switch (lower) {
      case 'yellow':
        return NamedStickyColor.yellow;
      case 'pink':
        return NamedStickyColor.pink;
      case 'blue':
        return NamedStickyColor.blue;
      case 'green':
        return NamedStickyColor.green;
      case 'purple':
        return NamedStickyColor.purple;
      case 'gray':
        return NamedStickyColor.gray;
    }

    if (s.startsWith('#')) {
      final hexPart = s.substring(1);
      final hex3Regex = RegExp(r'^[0-9a-fA-F]{3}$');
      final hex6Regex = RegExp(r'^[0-9a-fA-F]{6}$');

      if (hex3Regex.hasMatch(hexPart)) {
        final r = hexPart[0] * 2;
        final g = hexPart[1] * 2;
        final b = hexPart[2] * 2;
        final rgb = int.tryParse('$r$g$b', radix: 16);
        if (rgb != null) return HexStickyColor(rgb);
      } else if (hex6Regex.hasMatch(hexPart)) {
        final rgb = int.tryParse(hexPart, radix: 16);
        if (rgb != null) return HexStickyColor(rgb);
      }
    }

    return fallback;
  }

  /// Representation suitable for YAML serialization ('yellow' or upper-case '#RRGGBB').
  String get yamlValue;

  /// Card background color in 0xFFRRGGBB ARGB format.
  int get argb;

  /// Card text color ensuring WCAG contrast (0xFF1F1F1F or 0xFFFFFFFF).
  int get textArgb {
    final lum = _relativeLuminance(argb);
    return lum > 0.45 ? 0xFF1F1F1F : 0xFFFFFFFF;
  }

  static double _relativeLuminance(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;

    double linearize(double c) => c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

    final rLin = linearize(r);
    final gLin = linearize(g);
    final bLin = linearize(b);

    return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin;
  }
}

/// A standard named sticky card color.
final class NamedStickyColor extends StickyColor {
  const NamedStickyColor(this.name);

  final StickyColorName name;

  static const yellow = NamedStickyColor(StickyColorName.yellow);
  static const pink = NamedStickyColor(StickyColorName.pink);
  static const blue = NamedStickyColor(StickyColorName.blue);
  static const green = NamedStickyColor(StickyColorName.green);
  static const purple = NamedStickyColor(StickyColorName.purple);
  static const gray = NamedStickyColor(StickyColorName.gray);

  @override
  String get yamlValue => name.name;

  @override
  int get argb {
    switch (name) {
      case StickyColorName.yellow:
        return 0xFFFFF3A3;
      case StickyColorName.pink:
        return 0xFFFFC7DD;
      case StickyColorName.blue:
        return 0xFFBFE3FF;
      case StickyColorName.green:
        return 0xFFC8F2C2;
      case StickyColorName.purple:
        return 0xFFE0CCFF;
      case StickyColorName.gray:
        return 0xFFE3E3E3;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NamedStickyColor && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'NamedStickyColor(${name.name})';
}

/// A custom hex sticky card color.
final class HexStickyColor extends StickyColor {
  const HexStickyColor(this.rgb);

  /// 24-bit 0xRRGGBB integer.
  final int rgb;

  @override
  String get yamlValue =>
      '#${(rgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  int get argb => 0xFF000000 | (rgb & 0xFFFFFF);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HexStickyColor && (rgb & 0xFFFFFF) == (other.rgb & 0xFFFFFF);

  @override
  int get hashCode => (rgb & 0xFFFFFF).hashCode;

  @override
  String toString() => 'HexStickyColor($yamlValue)';
}
