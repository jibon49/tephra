// © 2026 Tephra. All rights reserved.

import 'dart:math';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';

import '../data/sticky_positions_store.dart';
import 'screen_key.dart';

/// Representation of a display screen and its usable work area in global logical pixels.
final class ScreenInfo {
  const ScreenInfo({
    required this.key,
    required this.name,
    required this.workArea,
    required this.isPrimary,
  });

  /// Stable key (`<display name>|<width>x<height>`).
  final String key;

  /// Display name (e.g. `DELL U2720Q`).
  final String name;

  /// Usable work area in global logical pixels.
  final Rect workArea;

  /// Whether this is the system primary display.
  final bool isPrimary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenInfo &&
          key == other.key &&
          name == other.name &&
          workArea == other.workArea &&
          isPrimary == other.isPrimary;

  @override
  int get hashCode => Object.hash(key, name, workArea, isPrimary);

  @override
  String toString() =>
      'ScreenInfo(key: $key, name: $name, workArea: $workArea, isPrimary: $isPrimary)';
}

/// Converts a global window Rect into a stored [StickyGeometry] relative to the containing screen.
///
/// Screen selection:
/// 1. The screen whose work area contains the window centre.
/// 2. Fallback: the screen with the largest overlap area with the window.
/// 3. Fallback: the primary screen (or first screen).
StickyGeometry toStored(
  Rect windowGlobal,
  List<ScreenInfo> screens, {
  required bool collapsed,
}) {
  if (screens.isEmpty) {
    return StickyGeometry(
      x: windowGlobal.left.round(),
      y: windowGlobal.top.round(),
      w: windowGlobal.width.round(),
      h: windowGlobal.height.round(),
      screen: 'Display|1920x1080',
      collapsed: collapsed,
    );
  }

  final center = windowGlobal.center;
  ScreenInfo? target = screens
      .where((s) => s.workArea.contains(center))
      .firstOrNull;

  if (target == null) {
    ScreenInfo? bestScreen;
    double maxOverlap = 0.0;
    for (final s in screens) {
      final intersection = s.workArea.intersect(windowGlobal);
      if (!intersection.isEmpty &&
          intersection.width > 0 &&
          intersection.height > 0) {
        final area = intersection.width * intersection.height;
        if (area > maxOverlap) {
          maxOverlap = area;
          bestScreen = s;
        }
      }
    }
    target = bestScreen;
  }

  target ??= screens.where((s) => s.isPrimary).firstOrNull ?? screens.first;

  final work = target.workArea;
  return StickyGeometry(
    x: (windowGlobal.left - work.left).round(),
    y: (windowGlobal.top - work.top).round(),
    w: windowGlobal.width.round(),
    h: windowGlobal.height.round(),
    screen: target.key,
    collapsed: collapsed,
  );
}

/// Converts a stored [StickyGeometry] into a global logical pixel Rect clamped to the target screen.
///
/// Screen resolution rules:
/// 1. Find screen by exact key.
/// 2. Else find screen by same name (extracted before the `|`).
/// 3. Else primary screen (or first screen).
///
/// Clamping rules:
/// - width and height are limited to the work area size.
/// - a collapsed window uses height 32 for clamping.
/// - left clamped to `[work.left, work.right - w]`.
/// - top clamped to `[work.top, work.bottom - h]`.
Rect toGlobal(StickyGeometry g, List<ScreenInfo> screens) {
  if (screens.isEmpty) {
    final double h = g.collapsed ? 32.0 : g.h.toDouble();
    return Rect.fromLTWH(g.x.toDouble(), g.y.toDouble(), g.w.toDouble(), h);
  }

  ScreenInfo? screen = screens.where((s) => s.key == g.screen).firstOrNull;
  if (screen == null) {
    final name = displayNameFromScreenKey(g.screen);
    screen = screens.where((s) => s.name == name).firstOrNull;
  }
  screen ??= screens.where((s) => s.isPrimary).firstOrNull ?? screens.first;

  final work = screen.workArea;
  final w = min(g.w.toDouble(), work.width);
  final clampH = g.collapsed
      ? min(32.0, work.height)
      : min(g.h.toDouble(), work.height);

  final maxLeft = work.right - w;
  final left = (work.left + g.x).clamp(work.left, max(work.left, maxLeft));

  final maxTop = work.bottom - clampH;
  final top = (work.top + g.y).clamp(work.top, max(work.top, maxTop));

  return Rect.fromLTWH(left.toDouble(), top.toDouble(), w, clampH);
}

/// Retrieves the current displays using [screenRetriever].
Future<List<ScreenInfo>> getScreenInfos() async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    final primary = await screenRetriever.getPrimaryDisplay();
    return displays.map((d) {
      final isPrimary = d.id == primary.id;
      final key = computeScreenKey(name: d.name, size: d.size);
      final pos = d.visiblePosition ?? Offset.zero;
      final size = d.visibleSize ?? d.size;
      return ScreenInfo(
        key: key,
        name: d.name ?? 'Display',
        workArea: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
        isPrimary: isPrimary,
      );
    }).toList();
  } catch (_) {
    return const [
      ScreenInfo(
        key: 'Display|1920x1080',
        name: 'Display',
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      ),
    ];
  }
}
