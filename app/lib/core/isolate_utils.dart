// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Runs [computation] in a worker isolate on native platforms, or synchronously on web.
Future<T> runInIsolate<T>(FutureOr<T> Function() computation) {
  if (kIsWeb) {
    return Future.sync(computation);
  }
  return Isolate.run(computation);
}
