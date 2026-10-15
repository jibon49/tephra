// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_index/tephra_index.dart';

import '../../core/providers.dart';

export '../../tags/providers.dart' show tagListProvider;

/// FutureProvider for the raw list of [PropertyKeyCount] from the index,
/// supplemented with the standard keys `tags`, `aliases`, `cssclasses` (count 0 when absent),
/// refreshed on index changes (debounced 500 ms).
final propertyKeysProvider = FutureProvider<List<PropertyKeyCount>>((
  ref,
) async {
  final changes = ref.watch(indexChangesProvider);
  if (changes.hasValue) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  final index = await ref.watch(noteIndexProvider.future);
  final indexed = await index.propertyKeys();

  final result = List<PropertyKeyCount>.from(indexed);
  final existing = {for (final k in indexed) k.key.toLowerCase()};

  if (!existing.contains('tags')) {
    result.add(
      const PropertyKeyCount(key: 'tags', valueType: 'tags', count: 0),
    );
  }
  if (!existing.contains('aliases')) {
    result.add(
      const PropertyKeyCount(key: 'aliases', valueType: 'aliases', count: 0),
    );
  }
  if (!existing.contains('cssclasses')) {
    result.add(
      const PropertyKeyCount(
        key: 'cssclasses',
        valueType: 'multitext',
        count: 0,
      ),
    );
  }

  return result;
});

/// FutureProvider for distinct values of a given property [key],
/// refreshed on index changes (debounced 500 ms).
final propertyValuesProvider = FutureProvider.family<List<String>, String>((
  ref,
  key,
) async {
  final changes = ref.watch(indexChangesProvider);
  if (changes.hasValue) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  final index = await ref.watch(noteIndexProvider.future);
  return index.propertyValues(key, limit: 50);
});
