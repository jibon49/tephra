// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import 'providers.dart';

void openFile(
  WidgetRef ref,
  VaultPath path, {
  String? subpath,
  bool newTab = false,
}) => ref
    .read(workspaceProvider.notifier)
    .openPath(path, subpath: subpath, newTab: newTab);
