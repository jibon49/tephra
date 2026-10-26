// © 2026 Tephra. All rights reserved.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tephra/stickies/data/sticky_positions_store.dart';
import 'package:tephra/stickies/windows/sticky_window_geometry.dart';

void main() {
  const primaryScreen = ScreenInfo(
    key: 'DELL U2720Q|1920x1080',
    name: 'DELL U2720Q',
    workArea: Rect.fromLTWH(0, 0, 1920, 1040),
    isPrimary: true,
  );

  const secondaryScreen = ScreenInfo(
    key: 'LG 27UK850|1920x1080',
    name: 'LG 27UK850',
    workArea: Rect.fromLTWH(1920, 0, 1920, 1040),
    isPrimary: false,
  );

  test('restores on same screen', () {
    const geom = StickyGeometry(
      x: 100,
      y: 150,
      w: 300,
      h: 250,
      screen: 'LG 27UK850|1920x1080',
    );

    final rect = toGlobal(geom, [primaryScreen, secondaryScreen]);
    expect(rect, const Rect.fromLTWH(1920 + 100, 150, 300, 250));
  });

  test('falls back to same name with different size', () {
    const geom = StickyGeometry(
      x: 50,
      y: 60,
      w: 280,
      h: 260,
      screen: 'DELL U2720Q|2560x1440',
    );

    final rect = toGlobal(geom, [primaryScreen]);
    expect(rect, const Rect.fromLTWH(50, 60, 280, 260));
  });

  test('missing monitor falls back to primary and clamps', () {
    const geom = StickyGeometry(
      x: 3000,
      y: 50,
      w: 300,
      h: 200,
      screen: 'UnknownMonitor|3840x2160',
    );

    final rect = toGlobal(geom, [primaryScreen]);
    expect(rect.left, equals(1920 - 300));
    expect(rect.top, equals(50));
    expect(rect.width, equals(300));
    expect(rect.height, equals(200));
  });

  test('window larger than work area shrinks', () {
    const geom = StickyGeometry(
      x: 0,
      y: 0,
      w: 2500,
      h: 1500,
      screen: 'DELL U2720Q|1920x1080',
    );

    final rect = toGlobal(geom, [primaryScreen]);
    expect(rect.width, equals(1920));
    expect(rect.height, equals(1040));
    expect(rect.left, equals(0));
    expect(rect.top, equals(0));
  });

  test('collapsed uses 32 px height', () {
    const geom = StickyGeometry(
      x: 100,
      y: 1030,
      w: 280,
      h: 400,
      screen: 'DELL U2720Q|1920x1080',
      collapsed: true,
    );

    final rect = toGlobal(geom, [primaryScreen]);
    expect(rect.height, equals(32.0));
    // Work area bottom is 1040. top must clamp to 1040 - 32 = 1008.
    expect(rect.top, equals(1040 - 32));
    expect(rect.left, equals(100));
    expect(rect.width, equals(280));
  });

  test('toStored picks screen containing centre', () {
    // Window from 1850 to 2050 on X; centre is 1950 (inside secondaryScreen)
    const window = Rect.fromLTWH(1850, 100, 200, 200);
    final geom = toStored(window, [
      primaryScreen,
      secondaryScreen,
    ], collapsed: false);

    expect(geom.screen, equals(secondaryScreen.key));
    expect(geom.x, equals(1850 - 1920));
    expect(geom.y, equals(100));
    expect(geom.w, equals(200));
    expect(geom.h, equals(200));
    expect(geom.collapsed, isFalse);
  });
}
