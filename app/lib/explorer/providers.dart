// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'explorer_service.dart';

export 'explorer_state.dart';

final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>((ref) {
      return GlobalKey<ScaffoldMessengerState>();
    });

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

final explorerServiceProvider = Provider<ExplorerService>((ref) {
  return ExplorerService(ref);
});
