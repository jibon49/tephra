// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_permission_service.dart';
import 'system_trash_windows.dart';

final storagePermissionServiceProvider = Provider<StoragePermissionService>(
  (ref) => (!kIsWeb && Platform.isAndroid)
      ? AndroidStoragePermissionService()
      : const NoopStoragePermissionService(),
);

final windowsSystemTrashProvider = Provider<WindowsSystemTrash?>(
  (ref) => (!kIsWeb && Platform.isWindows) ? WindowsSystemTrash() : null,
);
