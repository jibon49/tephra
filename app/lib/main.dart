// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:tephra/app.dart';
import 'package:tephra/core/logging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLogging();
  installCrashHandlers();
  Logger('app').info('Tephra starting');
  runApp(const ProviderScope(child: TephraApp()));
}
