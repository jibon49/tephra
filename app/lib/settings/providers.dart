// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:tephra/vault/providers.dart';

import 'app_settings.dart';
import 'app_settings_store.dart';
import 'vault_settings.dart';
import 'vault_settings_store.dart';

final initialAppSettingsProvider = Provider<AppSettings>((ref) {
  return const AppSettings(deviceId: 'default-device');
});

final appSettingsStoreProvider = Provider<AppSettingsStore?>((ref) => null);

final class AppSettingsNotifier extends Notifier<AppSettings> {
  final _log = Logger('settings');

  @override
  AppSettings build() {
    return ref.watch(initialAppSettingsProvider);
  }

  void update(AppSettings Function(AppSettings) mutate) {
    final updated = mutate(state);
    state = updated;
    final store = ref.read(appSettingsStoreProvider);
    if (store != null) {
      unawaited(
        store.save(updated).catchError((Object e, StackTrace st) {
          _log.warning('Failed to save app settings: $e', e, st);
        }),
      );
    }
  }

  void addRecentVault(String path, String name) {
    update((s) => s.addRecentVault(path, name));
  }

  void removeRecentVault(String path) {
    update((s) => s.removeRecentVault(path));
  }

  void touchCommand(String id) {
    update((s) => s.touchCommand(id));
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

final class VaultSettingsNotifier extends Notifier<VaultSettings> {
  final _log = Logger('settings');
  Future<void>? _pendingSave;

  @override
  VaultSettings build() {
    final session = ref.watch(vaultSessionProvider);
    return session?.settings ?? const VaultSettings();
  }

  void update(VaultSettings Function(VaultSettings) mutate) {
    final updated = mutate(state);
    state = updated;

    final session = ref.read(vaultSessionProvider);
    if (session != null) {
      final store = VaultSettingsStore(session.fs);
      final prev = _pendingSave ?? Future.value();
      _pendingSave = prev
          .then((_) async {
            await store.save(updated);
          })
          .catchError((Object e, StackTrace st) {
            _log.warning('Failed to save vault settings: $e', e, st);
          });
    }
  }
}

final vaultSettingsProvider =
    NotifierProvider<VaultSettingsNotifier, VaultSettings>(
      VaultSettingsNotifier.new,
    );
