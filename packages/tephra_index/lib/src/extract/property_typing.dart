// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'extracted_note.dart';

List<String> extractTagStrings(Object? value) {
  if (value == null) return const [];
  final rawList = value is List ? value : [value];
  final result = <String>[];
  for (final item in rawList) {
    if (item == null) continue;
    final text = item.toString();
    final parts = text.split(RegExp(r'[\s,]+'));
    for (var part in parts) {
      part = part.trim();
      if (part.startsWith('#')) {
        part = part.substring(1).trim();
      }
      if (part.isNotEmpty) {
        result.add(part);
      }
    }
  }
  return result;
}

List<String> extractAliasStrings(Object? value) {
  if (value == null) return const [];
  final rawList = value is List ? value : [value];
  final result = <String>[];
  final seen = <String>{};
  for (final item in rawList) {
    if (item == null) continue;
    final trimmed = item.toString().trim();
    if (trimmed.isEmpty) continue;
    if (seen.add(trimmed.toLowerCase())) {
      result.add(trimmed);
    }
  }
  return result;
}

/// Infers property rows from a YAML frontmatter entry.
List<ExtractedProperty> inferPropertyRows(String key, Object? value) {
  final lowerKey = key.toLowerCase();

  if (lowerKey == 'tags' || lowerKey == 'tag') {
    final tags = extractTagStrings(value);
    return [
      for (var i = 0; i < tags.length; i++)
        ExtractedProperty(
          key: key,
          valueType: 'tags',
          ordinal: i,
          valueText: tags[i],
        ),
    ];
  }

  if (lowerKey == 'aliases' || lowerKey == 'alias') {
    final aliases = extractAliasStrings(value);
    return [
      for (var i = 0; i < aliases.length; i++)
        ExtractedProperty(
          key: key,
          valueType: 'aliases',
          ordinal: i,
          valueText: aliases[i],
        ),
    ];
  }

  if (value is bool) {
    return [
      ExtractedProperty(
        key: key,
        valueType: 'checkbox',
        ordinal: 0,
        valueBool: value,
        valueText: value ? 'true' : 'false',
      ),
    ];
  }

  if (value is num) {
    return [
      ExtractedProperty(
        key: key,
        valueType: 'number',
        ordinal: 0,
        valueNum: value.toDouble(),
        valueText: value.toString(),
      ),
    ];
  }

  if (value is String) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return [
        ExtractedProperty(
          key: key,
          valueType: 'date',
          ordinal: 0,
          valueDate: value,
          valueText: value,
        ),
      ];
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$').hasMatch(value)) {
      return [
        ExtractedProperty(
          key: key,
          valueType: 'datetime',
          ordinal: 0,
          valueDate: value,
          valueText: value,
        ),
      ];
    }
    return [
      ExtractedProperty(
        key: key,
        valueType: 'text',
        ordinal: 0,
        valueText: value,
      ),
    ];
  }

  if (value is List) {
    if (value.isEmpty) {
      return [
        ExtractedProperty(
          key: key,
          valueType: 'multitext',
          ordinal: 0,
          valueText: null,
        ),
      ];
    }
    return [
      for (var i = 0; i < value.length; i++)
        ExtractedProperty(
          key: key,
          valueType: 'multitext',
          ordinal: i,
          valueText: value[i]?.toString(),
        ),
    ];
  }

  if (value is Map) {
    return [
      ExtractedProperty(
        key: key,
        valueType: 'text',
        ordinal: 0,
        valueText: jsonEncode(value),
      ),
    ];
  }

  if (value == null) {
    return [
      ExtractedProperty(
        key: key,
        valueType: 'text',
        ordinal: 0,
        valueText: null,
      ),
    ];
  }

  return [
    ExtractedProperty(
      key: key,
      valueType: 'text',
      ordinal: 0,
      valueText: value.toString(),
    ),
  ];
}
