// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'property_type.dart';

final _logger = Logger('PropertyTypeRegistry');

/// Registry of custom and inferred property types stored in `.tephra/types.json`.
final class PropertyTypeRegistry {
  PropertyTypeRegistry([VaultFileSystem? fs]) : _fs = fs;

  static final typesPath = VaultPath('.tephra/types.json');
  static final typesBackupPath = VaultPath('.tephra/types.json.bak');
  static final obsidianTypesPath = VaultPath('.obsidian/types.json');

  VaultFileSystem? _fs;
  final _types = <String, String>{};
  final _extra = <String, Object?>{};
  bool _hasCorruptFile = false;
  String? _corruptContent;
  String? _lastSavedJson;

  void attachFileSystem(VaultFileSystem fs) {
    _fs = fs;
  }

  /// Map of key -> type json name.
  Map<String, String> get types => Map.unmodifiable(_types);

  /// Loads registry from [.tephra/types.json] or imports from [.obsidian/types.json].
  Future<void> load([VaultFileSystem? fs]) async {
    final vfs = fs ?? _fs;
    if (vfs == null) return;
    _fs = vfs;

    _types.clear();
    _extra.clear();
    _hasCorruptFile = false;
    _corruptContent = null;
    _lastSavedJson = null;

    final stat = await vfs.stat(typesPath);
    if (stat != null) {
      final doc = await vfs.readText(typesPath);
      final content = doc.text;
      try {
        final dynamic decoded = jsonDecode(content);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final k = entry.key.toString();
            if (k == 'types' && entry.value is Map) {
              final typesMap = entry.value as Map;
              for (final typeEntry in typesMap.entries) {
                _types[typeEntry.key.toString()] = typeEntry.value.toString();
              }
            } else {
              _extra[k] = entry.value;
            }
          }
          _lastSavedJson = content;
        } else {
          _hasCorruptFile = true;
          _corruptContent = content;
          _logger.warning('Invalid types.json structure: expected a JSON map');
        }
      } catch (e, st) {
        _hasCorruptFile = true;
        _corruptContent = content;
        _logger.warning('Failed to parse .tephra/types.json', e, st);
      }
      return;
    }

    // Check for Obsidian types import (read-only)
    final obsidianStat = await vfs.stat(obsidianTypesPath);
    if (obsidianStat != null) {
      try {
        final doc = await vfs.readText(obsidianTypesPath);
        final content = doc.text;
        final dynamic decoded = jsonDecode(content);
        if (decoded is Map && decoded['types'] is Map) {
          final typesMap = decoded['types'] as Map;
          for (final typeEntry in typesMap.entries) {
            _types[typeEntry.key.toString()] = typeEntry.value.toString();
          }
          await _save();
        }
      } catch (e, st) {
        _logger.warning('Failed to import .obsidian/types.json', e, st);
      }
    }
  }

  /// Determines the [PropertyType] for [key] with [value].
  ///
  /// Resolution precedence:
  /// 1. Registry entry (exact match, then case-insensitive)
  /// 2. Built-ins: tags -> tags, aliases -> aliases, cssclasses -> multitext
  /// 3. Vault index common valueType
  /// 4. Value inference
  PropertyType typeFor(
    String key,
    Object? value, {
    List<PropertyKeyCount>? indexPropertyKeys,
  }) {
    // 1. Registry
    if (_types.containsKey(key)) {
      final t = PropertyType.fromJson(_types[key]!);
      if (t != null) return t;
    }
    final lowerKey = key.toLowerCase();
    for (final entry in _types.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        final t = PropertyType.fromJson(entry.value);
        if (t != null) return t;
      }
    }

    // 2. Built-ins
    if (lowerKey == 'tags') return PropertyType.tags;
    if (lowerKey == 'aliases') return PropertyType.aliases;
    if (lowerKey == 'cssclasses') return PropertyType.multitext;

    // 3. Vault index
    if (indexPropertyKeys != null) {
      for (final k in indexPropertyKeys) {
        if (k.key.toLowerCase() == lowerKey) {
          final t = PropertyType.fromJson(k.valueType);
          if (t != null) return t;
        }
      }
    }

    // 4. Value inference
    if (value is bool) return PropertyType.checkbox;
    if (value is num) return PropertyType.number;
    if (value is List) return PropertyType.multitext;
    if (value is String) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$').hasMatch(value)) {
        return PropertyType.datetime;
      }
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        return PropertyType.date;
      }
    }

    return PropertyType.text;
  }

  /// Asynchronously resolves the [PropertyType] using [index] if provided.
  Future<PropertyType> typeForAsync(
    String key,
    Object? value, {
    NoteIndex? index,
  }) async {
    List<PropertyKeyCount>? keyCounts;
    if (index != null) {
      try {
        keyCounts = await index.propertyKeys();
      } catch (_) {}
    }
    return typeFor(key, value, indexPropertyKeys: keyCounts);
  }

  /// Sets the type for [key] and persists to [.tephra/types.json].
  Future<void> setType(String key, PropertyType t) async {
    _types[key] = t.jsonName;
    await _save();
  }

  Future<void> _save() async {
    if (_fs == null) return;

    if (_hasCorruptFile && _corruptContent != null) {
      await _fs!.writeText(
        typesBackupPath,
        TextDocument(text: _corruptContent!),
      );
      _hasCorruptFile = false;
      _corruptContent = null;
    }

    final outMap = <String, Object?>{};
    for (final entry in _extra.entries) {
      outMap[entry.key] = entry.value;
    }
    outMap['types'] = Map<String, String>.from(_types);

    final serialized =
        '${const JsonEncoder.withIndent('  ').convert(outMap)}\n';
    if (serialized == _lastSavedJson) return;

    await _fs!.writeText(typesPath, TextDocument(text: serialized));
    _lastSavedJson = serialized;
  }
}
