// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra/stickies/data/open_note_bridge.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// In-memory fake of [OpenNoteBridge] for testing sticky operations.
final class FakeOpenNoteBridge implements OpenNoteBridge {
  final Map<VaultPath, String> openNotes = {};
  final List<(VaultPath, String)> appliedTexts = [];
  final StreamController<VaultPath> _editedController =
      StreamController<VaultPath>.broadcast();

  @override
  String? openText(VaultPath path) => openNotes[path];

  @override
  Future<void> applyText(VaultPath path, String text) async {
    openNotes[path] = text;
    appliedTexts.add((path, text));
  }

  @override
  Stream<VaultPath> get edited => _editedController.stream;

  void emitEdited(VaultPath path) {
    _editedController.add(path);
  }

  void dispose() {
    _editedController.close();
  }
}

/// In-memory fake of [SearchEngine] returning paths whose file text contains 'tephra-sticky: true'.
class FakeSearchEngine implements SearchEngine {
  FakeSearchEngine(this.fs);

  @override
  final VaultFileSystem fs;

  @override
  NoteIndex get index => throw UnimplementedError('Not used in fake');

  @override
  Stream<SearchResult> run(
    SearchExpr expr, {
    CancelToken? cancel,
    SearchSort sort = SearchSort.fileNameAsc,
    bool matchCase = false,
  }) async* {
    final entries = await fs.list(recursive: true);
    for (final entry in entries) {
      if (cancel?.isCancelled ?? false) break;
      if (entry.path.extension.toLowerCase() == 'md') {
        try {
          final doc = await fs.readText(entry.path);
          if (doc.text.contains('tephra-sticky: true')) {
            yield SearchResult(entry.path, const []);
          }
        } catch (_) {}
      }
    }
  }
}
