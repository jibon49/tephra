// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  test('vaultFsProvider throws StateError with no session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(vaultFsProvider),
      throwsA(predicate((e) => e.toString().contains('No vault is open'))),
    );
  });

  test('vaultFsProvider returns fs with active session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final fs = MemoryVaultFileSystem();
    final session = VaultSession(
      vaultId: 'session-1',
      rootDir: '/memory',
      name: 'Session 1',
      fs: fs,
      settings: VaultSettings(),
    );

    container.read(vaultSessionProvider.notifier).set(session);
    expect(container.read(vaultFsProvider), equals(fs));
    expect(container.read(vaultNameProvider), equals('Session 1'));
  });

  test('vaultRevisionProvider.bump() increments revision number', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(vaultRevisionProvider), equals(0));
    container.read(vaultRevisionProvider.notifier).bump();
    expect(container.read(vaultRevisionProvider), equals(1));
    container.read(vaultRevisionProvider.notifier).bump();
    expect(container.read(vaultRevisionProvider), equals(2));
  });
}
