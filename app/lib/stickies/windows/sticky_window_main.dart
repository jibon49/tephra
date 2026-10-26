// © 2026 Tephra. All rights reserved.

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'sticky_protocol.dart';
import 'sticky_window_app.dart';
import 'sticky_window_controller.dart';
import 'window_bus.dart';

/// Entry point for a secondary Flutter engine displaying a floating sticky note window.
Future<void> runStickyWindow(
  WindowController controller,
  StickyWindowArgs args,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(300, 260),
    minimumSize: Size(180, 36),
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: true,
    backgroundColor: Colors.transparent,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  final bus = await DesktopWindowBus.fromCurrentEngine();
  final stickyController = StickyWindowController(
    bus: bus,
    mainWindowId: args.mainWindowId,
    path: args.path,
    onCloseWindow: () async {
      await windowManager.close();
    },
  );
  await stickyController.start();

  runApp(StickyWindowApp(controller: stickyController));
}
