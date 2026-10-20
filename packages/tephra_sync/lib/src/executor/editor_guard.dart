// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Interface implemented by the application to coordinate disk writes with active editor buffers.
abstract interface class EditorGuard {
  /// Flushes any unsaved editor buffer for [path], then returns `true` only if
  /// the file on disk still matches [expectedHash] and has no unsaved in-memory edits.
  Future<bool> mayReplace(VaultPath path, String expectedHash);
}

/// Default permissive [EditorGuard] that always allows replacement.
final class AllowAllEditorGuard implements EditorGuard {
  const AllowAllEditorGuard();

  @override
  Future<bool> mayReplace(VaultPath path, String expectedHash) async => true;
}
