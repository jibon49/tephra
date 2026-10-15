// © 2026 Tephra. All rights reserved.

import 'property_type.dart';

/// The result of converting a property value to a new [PropertyType].
final class ConvertResult {
  const ConvertResult(this.value, {required this.ok});

  final Object? value;
  final bool ok;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConvertResult &&
          ok == other.ok &&
          (value == other.value ||
              (value is List &&
                  other.value is List &&
                  _listEquals(value as List, other.value as List)));

  @override
  int get hashCode => Object.hash(value, ok);

  @override
  String toString() => 'ConvertResult($value, ok: $ok)';

  static bool _listEquals(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Converts [value] to [to] property type.
///
/// If conversion fails, [ConvertResult.ok] is false and [ConvertResult.value]
/// preserves the original unconverted value.
ConvertResult convert(Object? value, PropertyType to) {
  if (value == null) {
    switch (to) {
      case PropertyType.text:
        return const ConvertResult(null, ok: true);
      case PropertyType.multitext:
      case PropertyType.aliases:
      case PropertyType.tags:
        return const ConvertResult(<String>[], ok: true);
      case PropertyType.checkbox:
        return const ConvertResult(false, ok: true);
      case PropertyType.number:
      case PropertyType.date:
      case PropertyType.datetime:
        return const ConvertResult(null, ok: true);
    }
  }

  switch (to) {
    case PropertyType.text:
      if (value is List) {
        return ConvertResult(
          value.map((e) => e.toString()).join(', '),
          ok: true,
        );
      }
      return ConvertResult(value.toString(), ok: true);

    case PropertyType.multitext:
    case PropertyType.aliases:
      if (value is String) {
        final parts = value
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return ConvertResult(parts, ok: true);
      }
      if (value is num || value is bool) {
        return ConvertResult([value.toString()], ok: true);
      }
      if (value is List) {
        final parts = value
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        return ConvertResult(parts, ok: true);
      }
      return ConvertResult([value.toString()], ok: true);

    case PropertyType.tags:
      final tokens = <String>[];
      if (value is List) {
        for (final item in value) {
          if (item != null) {
            tokens.addAll(
              item
                  .toString()
                  .split(RegExp(r'[\s,]+'))
                  .where((s) => s.isNotEmpty),
            );
          }
        }
      } else {
        tokens.addAll(
          value.toString().split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty),
        );
      }

      final tags = <String>[];
      for (var token in tokens) {
        token = token.replaceFirst(RegExp(r'^#+'), '');
        token = token.replaceAll(
          RegExp(r'[^\p{L}\p{N}_\-/]', unicode: true),
          '',
        );
        if (token.isEmpty) continue;
        if (RegExp(r'^\d+$').hasMatch(token)) continue;
        tags.add(token);
      }
      return ConvertResult(tags, ok: true);

    case PropertyType.number:
      if (value is num) {
        return ConvertResult(value, ok: true);
      }
      if (value is String) {
        final trimmed = value.trim();
        final parsed = num.tryParse(trimmed);
        if (parsed != null) {
          return ConvertResult(parsed, ok: true);
        }
      }
      return ConvertResult(value, ok: false);

    case PropertyType.checkbox:
      if (value is bool) {
        return ConvertResult(value, ok: true);
      }
      if (value is String) {
        final lower = value.trim().toLowerCase();
        if (lower == 'true' || lower == 'yes') {
          return const ConvertResult(true, ok: true);
        }
        if (lower == 'false' || lower == 'no') {
          return const ConvertResult(false, ok: true);
        }
      }
      return ConvertResult(value, ok: false);

    case PropertyType.date:
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.length >= 10) {
          final prefix = trimmed.substring(0, 10);
          if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(prefix)) {
            return ConvertResult(prefix, ok: true);
          }
        }
      }
      return ConvertResult(value, ok: false);

    case PropertyType.datetime:
      if (value is String) {
        final trimmed = value.trim();
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
          return ConvertResult('${trimmed}T00:00', ok: true);
        }
        if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$')
            .hasMatch(trimmed)) {
          return ConvertResult(trimmed, ok: true);
        }
      }
      return ConvertResult(value, ok: false);
  }
}

/// Namespace providing [convert] for property values.
abstract final class PropertyValueCodec {
  /// Converts [value] to [to] property type.
  static ConvertResult convert(Object? value, PropertyType to) =>
      propertyValueConvert(value, to);
}

/// Internal alias for top-level convert.
const propertyValueConvert = convert;
