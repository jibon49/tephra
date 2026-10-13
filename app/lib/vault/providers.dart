// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../workspace/providers.dart';
import 'note_creator.dart';
import 'vault_session.dart';

/// Notifier managing the currently active [VaultSession].
class VaultSessionNotifier extends Notifier<VaultSession?> {
  @override
  VaultSession? build() => null;

  void set(VaultSession? s) {
    final oldFs = state?.fs;
    state = s;
    if (oldFs != null && oldFs != s?.fs) {
      if (oldFs is IoVaultFileSystem) {
        unawaited(oldFs.dispose());
      } else if (oldFs is MemoryVaultFileSystem) {
        unawaited(oldFs.dispose());
      }
    }
  }

  void close() {
    set(null);
  }
}

final vaultSessionProvider =
    NotifierProvider<VaultSessionNotifier, VaultSession?>(
      VaultSessionNotifier.new,
    );

final vaultFsProvider = Provider<VaultFileSystem>((ref) {
  final s = ref.watch(vaultSessionProvider);
  if (s == null) {
    throw StateError('No vault is open');
  }
  return s.fs;
});

final vaultChangesProvider = StreamProvider<VaultChange>((ref) {
  final fs = ref.watch(vaultFsProvider);
  return fs.watch();
});

final class VaultRevisionNotifier extends Notifier<int> {
  Timer? _debounceTimer;

  @override
  int build() {
    // Only listen to external vault changes when a vault is open
    final session = ref.watch(vaultSessionProvider);
    if (session != null) {
      ref.listen<AsyncValue<VaultChange>>(vaultChangesProvider, (prev, next) {
        if (next.hasValue) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            bump();
          });
        }
      });
    }

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    return 0;
  }

  void bump() {
    state++;
  }
}

final vaultRevisionProvider = NotifierProvider<VaultRevisionNotifier, int>(
  VaultRevisionNotifier.new,
);

final vaultNameProvider = Provider<String>((ref) {
  return ref.watch(vaultSessionProvider)?.name ?? '';
});

final vaultOpenedHooksProvider = Provider<List<Future<void> Function(Ref ref)>>(
  (ref) => [(ref) => ref.read(workspaceProvider.notifier).restore()],
);

final noteCreatorProvider = Provider<NoteCreator>((ref) => NoteCreator(ref));
