// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../vault/note_document.dart';
import '../vault/providers.dart';

/// Indicates whether a given file path has unsaved edits, is saving, or has a save error.
final tabDirtyProvider = Provider.family<bool, VaultPath>((ref, path) {
  final store = ref.watch(noteDocumentStoreProvider);
  void listener() {
    ref.invalidateSelf();
  }

  store.stateVersion.addListener(listener);
  ref.onDispose(() {
    store.stateVersion.removeListener(listener);
  });

  final doc = store.peek(path);
  if (doc == null) return false;
  return doc.saveState == SaveState.unsaved ||
      doc.saveState == SaveState.saving ||
      doc.saveState == SaveState.error;
});
