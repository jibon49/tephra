// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';

import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../editor/autocomplete/yaml_scalar.dart';
import '../editor/offset_map_utils.dart';
import 'properties_exceptions.dart';

/// Pure functions for safely reading and modifying YAML frontmatter in Markdown text.
abstract final class FrontmatterEditor {
  /// Reads frontmatter into standard Dart maps and lists, preserving insertion order.
  /// Returns an empty map if no frontmatter is present or if frontmatter is invalid.
  static Map<String, Object?> read(String text) {
    final split = splitFrontmatter(text);
    if (split == null || split.yaml.trim().isEmpty) return const {};
    final decoded = decodeFrontmatterYaml(split.yaml);
    return decoded ?? const {};
  }

  /// Sets or replaces [key] with [value] in the frontmatter.
  ///
  /// Returns a [TextEdit] against the whole note, or `null` if nothing changed.
  static TextEdit? setValue(String text, String key, Object? value) {
    final split = splitFrontmatter(text);
    if (split == null) {
      final block = _formatEntryByHand(key, value);
      return TextEdit(0, 0, '---\n$block\n---\n');
    }

    final yaml = split.yaml;
    if (yaml.trim().isEmpty) {
      final block = _formatEntryByHand(key, value);
      return TextEdit(split.contentStart, split.contentStart, '$block\n');
    }

    final dynamic parsed;
    try {
      parsed = loadYaml(yaml);
    } catch (_) {
      return null;
    }

    String targetKey = key;
    if (parsed is Map) {
      for (final k in parsed.keys) {
        if (k.toString() == key) {
          targetKey = k.toString();
          break;
        }
      }
      if (targetKey == key) {
        final lowerKey = key.toLowerCase();
        for (final k in parsed.keys) {
          if (k.toString().toLowerCase() == lowerKey) {
            targetKey = k.toString();
            break;
          }
        }
      }
    }

    final editor = YamlEditor(yaml);
    final wrappedVal = _wrapValueForEditor(value);
    editor.update([targetKey], wrappedVal);
    final newYaml = editor.toString();
    return _computeEdit(split.contentStart, yaml, newYaml);
  }

  /// Removes [key] from the frontmatter.
  ///
  /// Returns a [TextEdit] against the whole note, or `null` if the key is not present.
  static TextEdit? removeKey(String text, String key) {
    final split = splitFrontmatter(text);
    if (split == null) return null;

    final yaml = split.yaml;
    if (yaml.trim().isEmpty) return null;

    final dynamic parsed;
    try {
      parsed = loadYaml(yaml);
    } catch (_) {
      return null;
    }
    if (parsed is! Map) return null;

    String? matchingKey;
    for (final k in parsed.keys) {
      if (k.toString() == key) {
        matchingKey = k.toString();
        break;
      }
    }
    if (matchingKey == null) {
      final lowerKey = key.toLowerCase();
      for (final k in parsed.keys) {
        if (k.toString().toLowerCase() == lowerKey) {
          matchingKey = k.toString();
          break;
        }
      }
    }
    if (matchingKey == null) return null;

    final editor = YamlEditor(yaml);
    editor.remove([matchingKey]);
    final newYaml = editor.toString();
    return _computeEdit(split.contentStart, yaml, newYaml);
  }

  /// Renames [oldKey] to [newKey].
  ///
  /// Throws [PropertyKeyExistsException] if [newKey] exists (case-insensitive).
  static TextEdit? renameKey(String text, String oldKey, String newKey) {
    final split = splitFrontmatter(text);
    if (split == null) return null;
    final yaml = split.yaml;

    final dynamic rootNode;
    try {
      rootNode = loadYamlNode(yaml);
    } catch (_) {
      return null;
    }
    if (rootNode is! YamlMap) return null;

    final lowerNewKey = newKey.toLowerCase();
    YamlNode? targetKeyNode;
    String? matchedOldKey;

    for (final entry in rootNode.nodes.entries) {
      final keyNode = entry.key as YamlNode;
      final kStr = keyNode.value.toString();
      if (kStr == oldKey) {
        targetKeyNode = keyNode;
        matchedOldKey = kStr;
        break;
      }
    }

    if (targetKeyNode == null) {
      final lowerOldKey = oldKey.toLowerCase();
      for (final entry in rootNode.nodes.entries) {
        final keyNode = entry.key as YamlNode;
        final kStr = keyNode.value.toString();
        if (kStr.toLowerCase() == lowerOldKey) {
          targetKeyNode = keyNode;
          matchedOldKey = kStr;
          break;
        }
      }
    }

    if (targetKeyNode == null || matchedOldKey == null) return null;

    // Check if newKey already exists (case-insensitive) other than matchedOldKey
    for (final entry in rootNode.nodes.entries) {
      final keyNode = entry.key as YamlNode;
      final kStr = keyNode.value.toString();
      if (kStr.toLowerCase() == lowerNewKey &&
          kStr.toLowerCase() != matchedOldKey.toLowerCase()) {
        throw PropertyKeyExistsException(newKey);
      }
    }

    if (matchedOldKey == newKey) return null;

    final formattedNewKey = _formatKey(newKey);
    final keySpan = targetKeyNode.span;
    final editStart = split.contentStart + keySpan.start.offset;
    final editEnd = split.contentStart + keySpan.end.offset;
    return TextEdit(editStart, editEnd, formattedNewKey);
  }

  /// Moves [key] to [newIndex] in the key order.
  static TextEdit? moveKey(String text, String key, int newIndex) {
    final split = splitFrontmatter(text);
    if (split == null) return null;
    final yaml = split.yaml;

    final dynamic rootNode;
    try {
      rootNode = loadYamlNode(yaml);
    } catch (_) {
      return null;
    }
    if (rootNode is! YamlMap || rootNode.nodes.isEmpty) return null;

    final lineStarts = <int>[0];
    for (var i = 0; i < yaml.length; i++) {
      if (yaml.codeUnitAt(i) == 0x0A) {
        lineStarts.add(i + 1);
      }
    }

    int lineOfOffset(int offset) {
      var low = 0;
      var high = lineStarts.length - 1;
      while (low <= high) {
        final mid = (low + high) >> 1;
        if (lineStarts[mid] <= offset) {
          if (mid == lineStarts.length - 1 || lineStarts[mid + 1] > offset) {
            return mid;
          }
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }
      return 0;
    }

    final entries = rootNode.nodes.entries.toList();
    final segStarts = <int>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final keyStart = (entry.key as YamlNode).span.start.offset;
      final keyLine = lineOfOffset(keyStart);

      var segStartLine = keyLine;
      for (var l = keyLine - 1; l >= 0; l--) {
        final lineEnd = l + 1 < lineStarts.length
            ? lineStarts[l + 1] - 1
            : yaml.length;
        final lineText = yaml.substring(lineStarts[l], lineEnd);
        if (lineText.trim().isEmpty) break;
        if (lineText.trim().startsWith('#')) {
          segStartLine = l;
        } else {
          break;
        }
      }
      segStarts.add(lineStarts[segStartLine]);
    }

    final prefix = yaml.substring(0, segStarts.first);
    final segments = <String>[];
    for (var i = 0; i < entries.length; i++) {
      final start = segStarts[i];
      final end = (i + 1 < segStarts.length) ? segStarts[i + 1] : yaml.length;
      segments.add(yaml.substring(start, end));
    }

    int? targetIndex;
    final lowerKey = key.toLowerCase();
    for (var i = 0; i < entries.length; i++) {
      final k = (entries[i].key as YamlNode).value.toString();
      if (k == key || k.toLowerCase() == lowerKey) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex == null) return null;

    final boundedNewIndex = newIndex.clamp(0, segments.length - 1);
    if (boundedNewIndex == targetIndex) return null;

    final movingSeg = segments.removeAt(targetIndex);
    segments.insert(boundedNewIndex, movingSeg);

    final originalEndsWithNewline = yaml.endsWith('\n');
    final buffer = StringBuffer(prefix);
    for (var i = 0; i < segments.length; i++) {
      var seg = segments[i];
      if (i < segments.length - 1 && !seg.endsWith('\n')) {
        seg = '$seg\n';
      }
      buffer.write(seg);
    }
    var newYaml = buffer.toString();
    if (!originalEndsWithNewline && newYaml.endsWith('\n')) {
      newYaml = newYaml.substring(0, newYaml.length - 1);
    }

    // Verification
    final dynamic check;
    try {
      check = loadYaml(newYaml);
    } catch (e) {
      throw StateError('moveKey produced invalid YAML: $e');
    }
    if (check is! Map || check.length != entries.length) {
      throw StateError('moveKey verification failed');
    }

    return _computeEdit(split.contentStart, yaml, newYaml);
  }

  /// Replaces the entire frontmatter with [newYaml].
  ///
  /// Throws [PropertiesYamlException] if [newYaml] is invalid YAML or not a map.
  static TextEdit? replaceRaw(String text, String newYaml) {
    if (newYaml.trim().isNotEmpty) {
      final dynamic parsed;
      try {
        parsed = loadYaml(newYaml);
      } on YamlException catch (e) {
        throw PropertiesYamlException(e.message, e.span?.start.line ?? 0);
      } catch (e) {
        throw PropertiesYamlException(e.toString(), 0);
      }
      if (parsed != null && parsed is! YamlMap && parsed is! Map) {
        throw const PropertiesYamlException(
          'YAML frontmatter must be a map',
          0,
        );
      }
    }

    final split = splitFrontmatter(text);
    if (split == null) {
      return TextEdit(0, 0, '---\n$newYaml\n---\n');
    }

    return TextEdit(
      split.contentStart,
      split.contentStart + split.yaml.length,
      newYaml,
    );
  }

  static TextEdit? _computeEdit(int contentStart, String yaml, String newYaml) {
    if (yaml == newYaml) return null;

    final prefix = commonPrefixLength(yaml, newYaml);
    final maxSuffix = min(yaml.length - prefix, newYaml.length - prefix);
    final suffix = commonSuffixLength(yaml, newYaml, maxSuffix);

    final editStart = contentStart + prefix;
    final editEnd = contentStart + yaml.length - suffix;
    final replacement = newYaml.substring(prefix, newYaml.length - suffix);

    if (editStart == editEnd && replacement.isEmpty) return null;
    return TextEdit(editStart, editEnd, replacement);
  }

  static String _formatEntryByHand(String key, Object? value) {
    final formattedKey = _formatKey(key);
    if (value == null) {
      return '$formattedKey:';
    }
    if (value is List) {
      if (value.isEmpty) {
        return '$formattedKey: []';
      }
      final buffer = StringBuffer('$formattedKey:');
      for (final item in value) {
        buffer.write('\n  - ${_formatScalar(item)}');
      }
      return buffer.toString();
    }
    return '$formattedKey: ${_formatScalar(value)}';
  }

  static String _formatScalar(Object? v) {
    if (v == null) return '';
    if (v is bool || v is num) return v.toString();
    final s = v.toString();
    return yamlScalarForInsert(s);
  }

  static String _formatKey(String key) {
    if (RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_ .\-]*$').hasMatch(key)) {
      return key;
    }
    if (RegExp(r'^[\p{L}\p{N}]+$', unicode: true).hasMatch(key)) {
      return key;
    }
    return jsonEncode(key);
  }

  static Object? _wrapValueForEditor(Object? v) {
    if (v is String) {
      final scalar = yamlScalarForInsert(v);
      if (scalar.startsWith('"') && scalar.endsWith('"')) {
        return wrapAsYamlNode(v, scalarStyle: ScalarStyle.DOUBLE_QUOTED);
      }
      return v;
    }
    if (v is List) {
      return v.map(_wrapValueForEditor).toList();
    }
    return v;
  }
}
