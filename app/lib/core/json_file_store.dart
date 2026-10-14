// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Stateless helper for reading, writing, and atomically updating JSON configuration
/// files inside a vault (under `.tephra/`).
final class TephraJsonStore {
  const TephraJsonStore([this.clock]);

  final Clock? clock;

  /// Reads a JSON object from [path] in [fs].
  ///
  /// Returns empty map if the file is missing, invalid JSON, or not a JSON object.
  Future<Map<String, Object?>> readMap(
    VaultFileSystem fs,
    VaultPath path,
  ) async {
    try {
      final doc = await fs.readText(path);
      final decoded = jsonDecode(doc.text);
      if (decoded is Map<String, Object?>) {
        return Map<String, Object?>.from(decoded);
      } else if (decoded is Map) {
        return decoded.cast<String, Object?>();
      } else {
        Logger('settings').warning('JSON in $path is not an object');
        return <String, Object?>{};
      }
    } on FileNotFoundException {
      return <String, Object?>{};
    } catch (e) {
      Logger('settings').warning('Invalid JSON in $path: $e');
      return <String, Object?>{};
    }
  }

  /// Writes [map] as 2-space indented JSON ending with LF to [path] in [fs].
  ///
  /// Returns `false` without writing if the file already exists with identical content.
  /// If the existing file contains corrupt/invalid JSON, it is copied to `<name>.bad-<yyyyMMddHHmmss>`
  /// before being overwritten.
  Future<bool> writeMap(
    VaultFileSystem fs,
    VaultPath path,
    Map<String, Object?> map,
  ) async {
    final encoded = '${const JsonEncoder.withIndent('  ').convert(map)}\n';
    final newBytes = utf8.encode(encoded);

    List<int>? existingBytes;
    var isInvalid = false;
    try {
      final bytes = await fs.readBytes(path);
      existingBytes = bytes;
      try {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map) {
          isInvalid = true;
        }
      } catch (_) {
        isInvalid = true;
      }

      if (!isInvalid && utf8.decode(bytes) == encoded) {
        return false;
      }
    } on FileNotFoundException {
      // File does not exist yet.
    }

    if (isInvalid && existingBytes != null) {
      final now =
          clock?.now() ??
          (fs is MemoryVaultFileSystem ? fs.clock.now() : DateTime.now());
      final ts =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final badName = '${path.name}.bad-$ts';
      final badPath = path.withName(badName);
      await fs.writeBytes(badPath, existingBytes);
    }

    await fs.writeBytes(path, newBytes);
    return true;
  }

  /// Reads [path], mutates the map via [mutate], and writes it back atomically.
  Future<void> update(
    VaultFileSystem fs,
    VaultPath path,
    void Function(Map<String, Object?> map) mutate,
  ) async {
    final map = await readMap(fs, path);
    mutate(map);
    await writeMap(fs, path, map);
  }
}

/// JSON file store for standalone files outside the vault (e.g. app settings).
final class AppJsonFile {
  AppJsonFile(this.file, {AtomicFileWriter? writer})
    : _writer = writer ?? AtomicFileWriter();

  final File file;
  final AtomicFileWriter _writer;

  /// Synchronously reads and decodes the JSON object.
  ///
  /// Returns empty map if missing or invalid.
  Map<String, Object?> readSync() {
    if (!file.existsSync()) {
      return <String, Object?>{};
    }
    try {
      final text = file.readAsStringSync();
      final decoded = jsonDecode(text);
      if (decoded is Map<String, Object?>) {
        return Map<String, Object?>.from(decoded);
      } else if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
      Logger('settings').warning('JSON in ${file.path} is not an object');
      return <String, Object?>{};
    } catch (e) {
      Logger('settings').warning('Invalid JSON in ${file.path}: $e');
      return <String, Object?>{};
    }
  }

  /// Writes [map] atomically using [AtomicFileWriter].
  Future<void> write(Map<String, Object?> map) async {
    final encoded = '${const JsonEncoder.withIndent('  ').convert(map)}\n';
    await _writer.write(file, utf8.encode(encoded));
  }
}
