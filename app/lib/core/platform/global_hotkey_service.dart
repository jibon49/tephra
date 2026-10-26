// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:logging/logging.dart';

import '../../stickies/windows/accelerator.dart';

final _log = Logger('hotkey');

/// System-wide global hotkey service.
abstract interface class GlobalHotkeyService {
  /// Registers a global hotkey accelerator (e.g. 'Ctrl+Alt+N') with an action callback.
  Future<void> register(String accelerator, void Function() onPressed);

  /// Unregisters all registered global hotkeys.
  Future<void> unregisterAll();
}

/// No-op implementation of [GlobalHotkeyService] for unsupported platforms.
class NoopGlobalHotkeyService implements GlobalHotkeyService {
  const NoopGlobalHotkeyService();

  @override
  Future<void> register(String accelerator, void Function() onPressed) async {}

  @override
  Future<void> unregisterAll() async {}
}

/// Abstraction over the native hotkey backend, injectable for testing.
abstract interface class HotKeyBackend {
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  });
  Future<void> unregister(HotKey hotKey);
  Future<void> unregisterAll();
}

/// Native implementation of [HotKeyBackend] using `package:hotkey_manager`.
class NativeHotKeyBackend implements HotKeyBackend {
  const NativeHotKeyBackend();

  @override
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) {
    return hotKeyManager.register(
      hotKey,
      keyDownHandler: keyDownHandler,
      keyUpHandler: keyUpHandler,
    );
  }

  @override
  Future<void> unregister(HotKey hotKey) {
    return hotKeyManager.unregister(hotKey);
  }

  @override
  Future<void> unregisterAll() {
    return hotKeyManager.unregisterAll();
  }
}

/// Windows implementation of [GlobalHotkeyService] using [HotKeyBackend].
class WindowsGlobalHotkeyService implements GlobalHotkeyService {
  WindowsGlobalHotkeyService({HotKeyBackend? backend, this.onNotice})
    : _backend = backend ?? const NativeHotKeyBackend();

  final HotKeyBackend _backend;
  final void Function(String notice)? onNotice;
  bool _initialized = false;
  HotKey? _currentHotKey;

  /// The currently registered hotkey, if any.
  HotKey? get currentHotKey => _currentHotKey;

  @override
  Future<void> register(String accelerator, void Function() onPressed) async {
    if (!_initialized) {
      try {
        await _backend.unregisterAll();
      } catch (e, st) {
        _log.fine('Failed to unregisterAll during hotkey init', e, st);
      }
      _initialized = true;
    }

    if (_currentHotKey != null) {
      try {
        await _backend.unregister(_currentHotKey!);
      } catch (e, st) {
        _log.fine('Failed to unregister previous hotkey', e, st);
      }
      _currentHotKey = null;
    }

    final parsed = Accelerator.parse(accelerator);
    final physicalKey = acceleratorKeyToPhysicalKeyboardKey(parsed.key);
    if (physicalKey == null) {
      throw FormatException(
        'Unsupported physical key for hotkey: ${parsed.key}',
      );
    }

    final hotKey = HotKey(
      key: physicalKey,
      modifiers: acceleratorModifiersToHotKeyModifiers(parsed.modifiers),
      scope: HotKeyScope.system,
    );

    try {
      await _backend.register(hotKey, keyDownHandler: (_) => onPressed());
      _currentHotKey = hotKey;
    } catch (e, st) {
      _log.warning('Failed to register global hotkey $accelerator', e, st);
      onNotice?.call(
        '$accelerator is used by another app; change it in Settings → Stickies',
      );
    }
  }

  @override
  Future<void> unregisterAll() async {
    _currentHotKey = null;
    try {
      await _backend.unregisterAll();
    } catch (e, st) {
      _log.fine('Failed to unregisterAll', e, st);
    }
  }
}

/// Converts a canonical accelerator key name to a Flutter [PhysicalKeyboardKey].
PhysicalKeyboardKey? acceleratorKeyToPhysicalKeyboardKey(String key) {
  final upper = key.toUpperCase();
  switch (upper) {
    case 'A':
      return PhysicalKeyboardKey.keyA;
    case 'B':
      return PhysicalKeyboardKey.keyB;
    case 'C':
      return PhysicalKeyboardKey.keyC;
    case 'D':
      return PhysicalKeyboardKey.keyD;
    case 'E':
      return PhysicalKeyboardKey.keyE;
    case 'F':
      return PhysicalKeyboardKey.keyF;
    case 'G':
      return PhysicalKeyboardKey.keyG;
    case 'H':
      return PhysicalKeyboardKey.keyH;
    case 'I':
      return PhysicalKeyboardKey.keyI;
    case 'J':
      return PhysicalKeyboardKey.keyJ;
    case 'K':
      return PhysicalKeyboardKey.keyK;
    case 'L':
      return PhysicalKeyboardKey.keyL;
    case 'M':
      return PhysicalKeyboardKey.keyM;
    case 'N':
      return PhysicalKeyboardKey.keyN;
    case 'O':
      return PhysicalKeyboardKey.keyO;
    case 'P':
      return PhysicalKeyboardKey.keyP;
    case 'Q':
      return PhysicalKeyboardKey.keyQ;
    case 'R':
      return PhysicalKeyboardKey.keyR;
    case 'S':
      return PhysicalKeyboardKey.keyS;
    case 'T':
      return PhysicalKeyboardKey.keyT;
    case 'U':
      return PhysicalKeyboardKey.keyU;
    case 'V':
      return PhysicalKeyboardKey.keyV;
    case 'W':
      return PhysicalKeyboardKey.keyW;
    case 'X':
      return PhysicalKeyboardKey.keyX;
    case 'Y':
      return PhysicalKeyboardKey.keyY;
    case 'Z':
      return PhysicalKeyboardKey.keyZ;
    case '0':
      return PhysicalKeyboardKey.digit0;
    case '1':
      return PhysicalKeyboardKey.digit1;
    case '2':
      return PhysicalKeyboardKey.digit2;
    case '3':
      return PhysicalKeyboardKey.digit3;
    case '4':
      return PhysicalKeyboardKey.digit4;
    case '5':
      return PhysicalKeyboardKey.digit5;
    case '6':
      return PhysicalKeyboardKey.digit6;
    case '7':
      return PhysicalKeyboardKey.digit7;
    case '8':
      return PhysicalKeyboardKey.digit8;
    case '9':
      return PhysicalKeyboardKey.digit9;
    case 'F1':
      return PhysicalKeyboardKey.f1;
    case 'F2':
      return PhysicalKeyboardKey.f2;
    case 'F3':
      return PhysicalKeyboardKey.f3;
    case 'F4':
      return PhysicalKeyboardKey.f4;
    case 'F5':
      return PhysicalKeyboardKey.f5;
    case 'F6':
      return PhysicalKeyboardKey.f6;
    case 'F7':
      return PhysicalKeyboardKey.f7;
    case 'F8':
      return PhysicalKeyboardKey.f8;
    case 'F9':
      return PhysicalKeyboardKey.f9;
    case 'F10':
      return PhysicalKeyboardKey.f10;
    case 'F11':
      return PhysicalKeyboardKey.f11;
    case 'F12':
      return PhysicalKeyboardKey.f12;
    default:
      return null;
  }
}

/// Converts a set of [AcceleratorModifier]s to a list of [HotKeyModifier]s.
List<HotKeyModifier> acceleratorModifiersToHotKeyModifiers(
  Set<AcceleratorModifier> modifiers,
) {
  final result = <HotKeyModifier>[];
  if (modifiers.contains(AcceleratorModifier.control)) {
    result.add(HotKeyModifier.control);
  }
  if (modifiers.contains(AcceleratorModifier.alt)) {
    result.add(HotKeyModifier.alt);
  }
  if (modifiers.contains(AcceleratorModifier.shift)) {
    result.add(HotKeyModifier.shift);
  }
  if (modifiers.contains(AcceleratorModifier.meta)) {
    result.add(HotKeyModifier.meta);
  }
  return result;
}
