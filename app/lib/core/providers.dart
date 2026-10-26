// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../vault/index_session.dart';
import 'platform/system_trash_windows.dart';
import 'sync/google_auth_service.dart';

export '../links/providers.dart'
    show linkNavigatorProvider, linkResolutionProvider;
export '../settings/providers.dart'
    show appSettingsProvider, vaultSettingsProvider;
export '../vault/index_session.dart' show NoteIndexNotifier;
export 'platform/platform_providers.dart';
export 'sync/google_auth_service.dart'
    show GoogleAccount, GoogleAuthService, createGoogleAuthService;

/// Provider supplying the application's clock source.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Provider supplying the application support directory when available.
final appSupportDirectoryProvider = Provider<Directory?>((ref) => null);

/// Provider supplying operating system recycle bin integration on supported platforms.
final systemTrashProvider = Provider<SystemTrash?>((ref) {
  return (!kIsWeb && Platform.isWindows) ? WindowsSystemTrash() : null;
});

/// Provider supplying platform-specific Google Sign-In and authorization.
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return createGoogleAuthService(
    isWeb: kIsWeb,
    isAndroid: !kIsWeb && Platform.isAndroid,
    isWindows: !kIsWeb && Platform.isWindows,
  );
});

final noteIndexProvider = AsyncNotifierProvider<NoteIndexNotifier, NoteIndex>(
  NoteIndexNotifier.new,
);

final indexProgressProvider = StreamProvider<IndexProgress>((ref) async* {
  final i = await ref.watch(noteIndexProvider.future);
  yield i.currentProgress;
  yield* i.progress;
});

final indexChangesProvider = StreamProvider<IndexEvent>((ref) async* {
  final i = await ref.watch(noteIndexProvider.future);
  yield* i.changes;
});
