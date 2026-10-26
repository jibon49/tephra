// © 2026 Tephra. All rights reserved.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tephra/core/platform/global_hotkey_service.dart';

class FakeHotKeyBackend implements HotKeyBackend {
  final List<HotKey> registeredHotKeys = [];
  final List<HotKey> unregisteredHotKeys = [];
  int unregisterAllCallCount = 0;
  HotKeyHandler? lastKeyDownHandler;
  bool shouldThrowOnRegister = false;

  @override
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    if (shouldThrowOnRegister) {
      throw PlatformException(
        code: 'hotkey_already_registered',
        message: 'Hotkey is already registered by another application',
      );
    }
    registeredHotKeys.add(hotKey);
    lastKeyDownHandler = keyDownHandler;
  }

  @override
  Future<void> unregister(HotKey hotKey) async {
    unregisteredHotKeys.add(hotKey);
    registeredHotKeys.remove(hotKey);
  }

  @override
  Future<void> unregisterAll() async {
    unregisterAllCallCount++;
    registeredHotKeys.clear();
  }
}

void main() {
  group('WindowsGlobalHotkeyService', () {
    late FakeHotKeyBackend backend;
    late List<String> notices;
    late WindowsGlobalHotkeyService service;

    setUp(() {
      backend = FakeHotKeyBackend();
      notices = [];
      service = WindowsGlobalHotkeyService(
        backend: backend,
        onNotice: notices.add,
      );
    });

    test('registers Ctrl+Alt+N and cleans up previous registrations', () async {
      var pressed = false;
      await service.register('Ctrl+Alt+N', () {
        pressed = true;
      });

      expect(backend.unregisterAllCallCount, 1);
      expect(backend.registeredHotKeys.length, 1);
      final registered = backend.registeredHotKeys.first;
      expect(registered.key, equals(PhysicalKeyboardKey.keyN));
      expect(registered.modifiers, contains(HotKeyModifier.control));
      expect(registered.modifiers, contains(HotKeyModifier.alt));
      expect(registered.scope, HotKeyScope.system);

      // Simulate key press
      backend.lastKeyDownHandler?.call(registered);
      expect(pressed, isTrue);
    });

    test('replaces previous hotkey on second register call', () async {
      await service.register('Ctrl+Alt+N', () {});
      expect(backend.registeredHotKeys.length, 1);

      await service.register('Ctrl+Alt+M', () {});
      expect(backend.unregisteredHotKeys.length, 1);
      expect(backend.registeredHotKeys.length, 1);
      expect(
        backend.registeredHotKeys.first.key,
        equals(PhysicalKeyboardKey.keyM),
      );
    });

    test('handles registration failure by notifying listener', () async {
      backend.shouldThrowOnRegister = true;
      await service.register('Ctrl+Alt+N', () {});

      expect(
        notices,
        contains(
          'Ctrl+Alt+N is used by another app; change it in Settings → Stickies',
        ),
      );
      expect(service.currentHotKey, isNull);
    });

    test('unregisterAll unregisters and resets state', () async {
      await service.register('Ctrl+Alt+N', () {});
      expect(service.currentHotKey, isNotNull);

      await service.unregisterAll();
      expect(service.currentHotKey, isNull);
      expect(backend.registeredHotKeys, isEmpty);
    });
  });
}
