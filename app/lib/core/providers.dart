// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'platform/system_trash_windows.dart';

export '../settings/providers.dart'
    show appSettingsProvider, vaultSettingsProvider;

/// Provider supplying the application's clock source.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Provider supplying operating system recycle bin integration on supported platforms.
final systemTrashProvider = Provider<SystemTrash?>((ref) {
  return (!kIsWeb && Platform.isWindows) ? WindowsSystemTrash() : null;
});
