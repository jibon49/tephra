// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

final class RecordingVaultFileSystem implements VaultFileSystem {
  RecordingVaultFileSystem(this.inner);

  final VaultFileSystem inner;

  int writeBytesCount = 0;
  int writeTextCount = 0;
  int moveCount = 0;
  int deleteCount = 0;

  int get writeCount => writeBytesCount + writeTextCount;

  final List<VaultPath> writtenPaths = [];
  final List<VaultPath> deletedPaths = [];
  final List<(VaultPath, VaultPath)> movedPaths = [];

  void reset() {
    writeBytesCount = 0;
    writeTextCount = 0;
    moveCount = 0;
    deleteCount = 0;
    writtenPaths.clear;
    deletedPaths.clear;
    movedPaths.clear;
  }

  @override
  String get rootDisplayPath => inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) {
    return inner.list(folder: folder, recursive: recursive);
  }

  @override
  Future<VaultEntry?> stat(VaultPath path) {
    return inner.stat(path);
  }

  @override
  Future<List<int>> readBytes(VaultPath path) {
    return inner.readBytes(path);
  }

  @override
  Future<TextDocument> readText(VaultPath path) {
    return inner.readText(path);
  }

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) async {
    writeBytesCount++;
    writtenPaths.add(path);
    await inner.writeBytes(path, bytes);
  }

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) async {
    writeTextCount++;
    writtenPaths.add(path);
    await inner.writeText(path, doc);
  }

  @override
  Future<void> createFolder(VaultPath path) {
    return inner.createFolder(path);
  }

  @override
  Future<void> move(VaultPath from, VaultPath to) async {
    moveCount++;
    movedPaths.add((from, to));
    await inner.move(from, to);
  }

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) async {
    deleteCount++;
    deletedPaths.add(path);
    await inner.delete(path, mode: mode);
  }

  @override
  Stream<VaultChange> watch() {
    return inner.watch();
  }

  @override
  Future<void> dispose() {
    return inner.dispose();
  }
}
