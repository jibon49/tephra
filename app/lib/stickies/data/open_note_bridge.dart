// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';

import '../../vault/note_document_store.dart';

/// Bridge interface decoupling the stickies subsystem from the open-document registry.
abstract interface class OpenNoteBridge {
  /// Returns the current in-memory text if the note at [path] is currently open, else null.
  String? openText(VaultPath path);

  /// Replaces the open note document's text and queues autosave.
  Future<void> applyText(VaultPath path, String text);

  /// Stream emitting note paths whose in-memory text was edited from typing.
  Stream<VaultPath> get edited;
}

/// Production implementation of [OpenNoteBridge] backed by [NoteDocumentStore].
final class AppOpenNoteBridge implements OpenNoteBridge {
  AppOpenNoteBridge(this._store);

  final NoteDocumentStore _store;
  final StreamController<VaultPath> _editedController =
      StreamController<VaultPath>.broadcast();
  Timer? _debounceTimer;
  VaultPath? _pendingPath;

  @override
  String? openText(VaultPath path) {
    return _store.peek(path)?.text;
  }

  @override
  Future<void> applyText(VaultPath path, String text) async {
    final doc = _store.peek(path);
    if (doc != null) {
      doc.setText(text);
    }
  }

  @override
  Stream<VaultPath> get edited => _editedController.stream;

  /// Notifies the bridge that an open note's buffer was modified by typing.
  void notifyEdited(VaultPath path) {
    _pendingPath = path;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_pendingPath != null && !_editedController.isClosed) {
        _editedController.add(_pendingPath!);
      }
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    _editedController.close();
  }
}
