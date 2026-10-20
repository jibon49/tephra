// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';

import '../../editor/editor_registry.dart';
import '../../vault/note_document.dart';
import '../../vault/note_document_store.dart';

final _log = Logger('sync.editor_guard');

/// Host implementation answering [EditorGuardRequest] messages on the main isolate.
class EditorGuardHost {
  EditorGuardHost({
    required this.vaultRootPath,
    this.editorRegistry,
    this.documentStore,
    this.timeout = const Duration(seconds: 5),
  });

  final String vaultRootPath;
  final EditorRegistry? editorRegistry;
  final NoteDocumentStore? documentStore;
  final Duration timeout;

  /// Handles an editor guard check for [relativePath] and [expectedHash].
  ///
  /// Returns `false` if:
  /// - The document has unsaved in-memory edits (which are saved immediately).
  /// - The file on disk does not match [expectedHash].
  /// - The verification operation exceeds [timeout].
  Future<bool> handleRequest(String relativePath, String expectedHash) async {
    try {
      return await _check(relativePath, expectedHash).timeout(
        timeout,
        onTimeout: () {
          _log.warning('Editor guard check timed out for $relativePath');
          return false;
        },
      );
    } catch (e, st) {
      _log.warning('Editor guard check failed for $relativePath: $e', e, st);
      return false;
    }
  }

  Future<bool> _check(String relativePath, String expectedHash) async {
    final vaultPath = VaultPath(relativePath);

    // 1. Check for open document with unsaved changes
    NoteDocument? doc = documentStore?.peek(vaultPath);
    if (doc == null && editorRegistry != null) {
      final controller = editorRegistry!.controllerFor(vaultPath);
      doc = controller?.document;
    }

    if (doc != null && doc.isDirty) {
      _log.info(
        'Document $relativePath has unsaved edits; saving and rejecting replace',
      );
      await doc.save();
      return false;
    }

    // 2. Hash file on disk in an isolate to avoid UI jank
    final fullPath = p.join(vaultRootPath, relativePath);
    final diskHash = await Isolate.run(() {
      final file = File(fullPath);
      if (!file.existsSync()) return '';
      final bytes = file.readAsBytesSync();
      return contentHash(bytes);
    });

    final matches = diskHash == expectedHash;
    if (!matches) {
      _log.info(
        'Disk hash mismatch for $relativePath: expected $expectedHash, got $diskHash',
      );
    }
    return matches;
  }
}
