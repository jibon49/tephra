// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/providers.dart';
import '../vault/providers.dart';
import 'builtin_commands.dart';
import 'command_registry.dart';
import 'hotkey_store.dart';

final phoneScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>((ref) {
  return GlobalKey<ScaffoldState>();
});

final commandRegistryProvider = Provider<CommandRegistry>((ref) {
  final registry = CommandRegistry();
  registerBuiltinCommands(registry);
  return registry;
});

final class HotkeyOverridesNotifier
    extends Notifier<Map<String, List<SingleActivator>>> {
  @override
  Map<String, List<SingleActivator>> build() {
    final session = ref.watch(vaultSessionProvider);
    if (session == null) return const {};

    final store = HotkeyStore(
      session.fs,
      registry: ref.watch(commandRegistryProvider),
    );
    store.load().then((loaded) {
      state = loaded;
    });

    return const {};
  }

  Future<void> update(
    Map<String, List<SingleActivator>> Function(
      Map<String, List<SingleActivator>>,
    )
    mutate,
  ) async {
    final next = mutate(Map.of(state));
    state = next;

    final session = ref.read(vaultSessionProvider);
    if (session == null) return;
    final store = HotkeyStore(
      session.fs,
      registry: ref.read(commandRegistryProvider),
    );
    await store.save(next);
  }

  Future<void> resetAll() async {
    state = const {};
    final session = ref.read(vaultSessionProvider);
    if (session == null) return;
    final store = HotkeyStore(
      session.fs,
      registry: ref.read(commandRegistryProvider),
    );
    await store.save(const {});
  }
}

final hotkeyOverridesProvider =
    NotifierProvider<
      HotkeyOverridesNotifier,
      Map<String, List<SingleActivator>>
    >(HotkeyOverridesNotifier.new);

final recentCommandsProvider = Provider<List<String>>((ref) {
  return ref.watch(appSettingsProvider.select((s) => s.recentCommands));
});
