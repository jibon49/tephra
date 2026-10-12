// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color seed = Color(0xFFC2410C);
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData _build(Brightness b) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b),
    useMaterial3: true,
  );
}
