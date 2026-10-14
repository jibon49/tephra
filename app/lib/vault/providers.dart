// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../reading/providers.dart';
import '../workspace/providers.dart';
import 'note_creator.dart';
import 'note_document.dart';
import 'note_document_store.dart';
import 'vault_session.dart';

/// Notifier managing the currently active [VaultSession].
class VaultSessionNotifier extends Notifier<VaultSession?> {
  @override
  VaultSession? build() => null;

  Future<void> set(VaultSession? s) async {
    final oldFs = state?.fs;
    state = s;
    if (oldFs != null && oldFs != s?.fs) {
      if (oldFs is IoVaultFileSystem) {
        await oldFs.dispose();
      } else if (oldFs is MemoryVaultFileSystem) {
        await oldFs.dispose();
      }
    }
  }

  Future<void> close() async {
    await set(null);
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

final noteDocumentStoreProvider = Provider<NoteDocumentStore>((ref) {
  final fs = ref.watch(vaultFsProvider);
  final parseService = ref.watch(parseServiceProvider);
  final store = NoteDocumentStore(
    fs,
    const SystemClock(),
    parseService: parseService,
  );
  store.start();
  ref.onDispose(() {
    unawaited(store.flushAll().then((_) => store.dispose()));
  });
  return store;
});

final noteDocumentProvider = Provider.autoDispose
    .family<NoteDocument, VaultPath>((ref, path) {
      final s = ref.watch(noteDocumentStoreProvider);
      final d = s.acquire(path);
      ref.onDispose(() => s.release(path));
      return d;
    });

final vaultFilesProvider = FutureProvider<List<VaultPath>>((ref) async {
  ref.watch(vaultRevisionProvider);
  final fs = ref.watch(vaultFsProvider);
  final entries = await fs.list(folder: VaultPath.root, recursive: true);
  return entries.where((e) => !e.isFolder).map((e) => e.path).toList();
});
