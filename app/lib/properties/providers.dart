// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_index/tephra_index.dart';

import '../core/providers.dart';
import '../vault/providers.dart';
import 'property_type.dart';
import 'property_type_registry.dart';

/// Notifier coordinating the [PropertyTypeRegistry] stored in `.tephra/types.json`.
class PropertyTypeRegistryNotifier extends AsyncNotifier<PropertyTypeRegistry> {
  @override
  Future<PropertyTypeRegistry> build() async {
    final session = ref.watch(vaultSessionProvider);
    final registry = PropertyTypeRegistry(session?.fs);
    await registry.load();
    return registry;
  }

  Future<void> setType(String key, PropertyType type) async {
    final registry = state.value;
    if (registry == null) return;
    await registry.setType(key, type);
    state = AsyncData(registry);
  }
}

final propertyTypeRegistryProvider =
    AsyncNotifierProvider<PropertyTypeRegistryNotifier, PropertyTypeRegistry>(
      PropertyTypeRegistryNotifier.new,
    );

/// Provider for list of all indexed property keys.
final propertyKeysProvider = FutureProvider<List<PropertyKeyCount>>((
  ref,
) async {
  final changes = ref.watch(indexChangesProvider);
  if (changes.hasValue) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  final index = await ref.watch(noteIndexProvider.future);
  return index.propertyKeys();
});
