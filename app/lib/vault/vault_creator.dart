// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';

/// Thrown when vault folder creation fails.
final class VaultCreateException extends TephraException {
  const VaultCreateException(this.code) : super('Vault create failed: $code');

  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultCreateException && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'VaultCreateException($code)';
}

/// Creates a new empty directory for a vault.
///
/// Throws [VaultCreateException] if the name is invalid, empty, or if the
/// target directory already exists and is not empty (ignoring `.tephra`).
Future<String> createVault({
  required String parentDir,
  required String name,
}) async {
  final err = VaultPath.checkName(name);
  if (err != null) {
    throw VaultCreateException(err == 'empty' ? 'empty' : 'invalid');
  }

  final dirPath = p.join(parentDir, name);
  final dir = Directory(dirPath);

  if (dir.existsSync()) {
    final entities = await dir.list().toList();
    final nonIgnored = entities.where((e) {
      final base = p.basename(e.path);
      return base != '.tephra';
    }).toList();

    if (nonIgnored.isNotEmpty) {
      throw const VaultCreateException('not-empty');
    }
  } else {
    dir.createSync(recursive: true);
  }

  return dir.path;
}
