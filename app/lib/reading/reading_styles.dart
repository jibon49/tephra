// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

/// Resolved styles for reading view rendering.
final class ReadingStyles {
  const ReadingStyles({
    required this.theme,
    required this.fontSize,
    required this.body,
    required this.mono,
    required this.linkColor,
    required this.quoteBorder,
    required this.codeBackground,
    required this.tableBorder,
    required this.highlightBackground,
    required this.tagBackground,
    required this.paragraphBottomMargin,
    required this.headingTopMargin,
    required this.headingBottomMargin,
  });

  factory ReadingStyles.of(ThemeData theme, double fontSize) {
    final bodyStyle = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontSize: fontSize,
      height: 1.5,
      color: theme.colorScheme.onSurface,
    );

    final monoStyle = TextStyle(
      fontSize: 0.9 * fontSize,
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Consolas', 'Cascadia Mono', 'Roboto Mono'],
      color: theme.colorScheme.onSurface,
    );

    final highlightBg = theme.brightness == Brightness.light
        ? const Color(0xAAFFEB3B)
        : const Color(0x66FFEB3B);

    final tagBg = theme.colorScheme.primaryContainer.withValues(alpha: 0.5);

    return ReadingStyles(
      theme: theme,
      fontSize: fontSize,
      body: bodyStyle,
      mono: monoStyle,
      linkColor: theme.colorScheme.primary,
      quoteBorder: theme.colorScheme.outline,
      codeBackground: theme.colorScheme.surfaceContainerHighest,
      tableBorder: theme.colorScheme.outlineVariant,
      highlightBackground: highlightBg,
      tagBackground: tagBg,
      paragraphBottomMargin: 0.6 * fontSize,
      headingTopMargin: 0.8 * fontSize,
      headingBottomMargin: 0.4 * fontSize,
    );
  }

  final ThemeData theme;
  final double fontSize;
  final TextStyle body;
  final TextStyle mono;
  final Color linkColor;
  final Color quoteBorder;
  final Color codeBackground;
  final Color tableBorder;
  final Color highlightBackground;
  final Color tagBackground;
  final double paragraphBottomMargin;
  final double headingTopMargin;
  final double headingBottomMargin;

  TextStyle heading(int level) {
    final double multiplier;
    final FontWeight weight;
    final Color color;

    switch (level) {
      case 1:
        multiplier = 2.0;
        weight = FontWeight.w700;
        color = theme.colorScheme.onSurface;
      case 2:
        multiplier = 1.7;
        weight = FontWeight.w700;
        color = theme.colorScheme.onSurface;
      case 3:
        multiplier = 1.4;
        weight = FontWeight.w600;
        color = theme.colorScheme.onSurface;
      case 4:
        multiplier = 1.2;
        weight = FontWeight.w600;
        color = theme.colorScheme.onSurface;
      case 5:
        multiplier = 1.1;
        weight = FontWeight.w600;
        color = theme.colorScheme.onSurface;
      case 6:
      default:
        multiplier = 1.0;
        weight = FontWeight.w600;
        color = theme.colorScheme.onSurfaceVariant;
    }

    return TextStyle(
      fontSize: multiplier * fontSize,
      fontWeight: weight,
      color: color,
      height: 1.3,
    );
  }
}
