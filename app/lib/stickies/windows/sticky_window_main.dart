// © 2026 Tephra. All rights reserved.

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import 'sticky_protocol.dart';

/// Entry point for a secondary Flutter engine displaying a sticky note window.
Future<void> runStickyWindow(
  WindowController controller,
  StickyWindowArgs args,
) async {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Sticky: ${args.path}'))),
    ),
  );
}
