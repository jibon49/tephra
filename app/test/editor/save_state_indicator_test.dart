// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/save_state_indicator.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

final class _FailOnceFileSystem implements VaultFileSystem {
  _FailOnceFileSystem(this._inner);

  final MemoryVaultFileSystem _inner;
  bool shouldFail = false;
  int saveAttemptCount = 0;

  @override
  String get rootDisplayPath => _inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => _inner.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => _inner.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) => _inner.readBytes(path);

  @override
  Future<TextDocument> readText(VaultPath path) => _inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) async {
    saveAttemptCount++;
    if (shouldFail) {
      throw const PermissionDeniedException('denied');
    }
    return _inner.writeBytes(path, bytes);
  }

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) =>
      _inner.writeText(path, doc);

  @override
  Future<void> createFolder(VaultPath path) => _inner.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => _inner.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => _inner.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => _inner.watch();

  @override
  Future<void> dispose() => _inner.dispose();
}

void main() {
  group('SaveStateIndicator', () {
    late MemoryVaultFileSystem memFs;
    late _FailOnceFileSystem fs;
    late VaultPath path;

    setUp(() async {
      memFs = MemoryVaultFileSystem();
      fs = _FailOnceFileSystem(memFs);
      path = VaultPath('note.md');
      await fs.writeText(path, const TextDocument(text: 'Initial text'));
    });

    testWidgets('renders saved state', (tester) async {
      final doc = NoteDocument(path: path, fs: fs, clock: const SystemClock());
      await doc.load();

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Center(child: SaveStateIndicator(doc: doc)),
          ),
          fs: memFs,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SaveStateIndicator)),
      );
      expect(find.text(l10n.saveStateSaved), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      doc.dispose();
    });

    testWidgets('renders unsaved state', (tester) async {
      final doc = NoteDocument(path: path, fs: fs, clock: const SystemClock());
      await doc.load();

      doc.edit(const EditOperation(0, 0, 'Edit '));

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Center(child: SaveStateIndicator(doc: doc)),
          ),
          fs: memFs,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SaveStateIndicator)),
      );
      expect(find.text(l10n.saveStateUnsaved), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      doc.dispose();
    });

    testWidgets('renders error state and tap retries save', (tester) async {
      final doc = NoteDocument(path: path, fs: fs, clock: const SystemClock());
      await doc.load();

      fs.shouldFail = true;
      doc.edit(const EditOperation(0, 0, 'Fail '));

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Center(child: SaveStateIndicator(doc: doc)),
          ),
          fs: memFs,
        ),
      );
      await tester.pumpAndSettle();

      // Trigger autosave to fail
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SaveStateIndicator)),
      );
      expect(doc.saveState, SaveState.error);
      expect(find.text(l10n.saveStateError), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Now fix failure and tap indicator to retry
      fs.shouldFail = false;
      final prevAttempts = fs.saveAttemptCount;

      await tester.tap(find.byType(SaveStateIndicator));
      await tester.pumpAndSettle();

      expect(fs.saveAttemptCount, greaterThan(prevAttempts));
      expect(doc.saveState, SaveState.saved);
      expect(find.text(l10n.saveStateSaved), findsOneWidget);

      doc.dispose();
    });
  });
}
