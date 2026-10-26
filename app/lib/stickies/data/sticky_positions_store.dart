// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

final _log = Logger('sticky_positions_store');

/// The stored geometry and monitor key for a sticky note window.
final class StickyGeometry {
  const StickyGeometry({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.screen,
    this.collapsed = false,
  });

  /// Work-area-relative logical X coordinate.
  final int x;

  /// Work-area-relative logical Y coordinate.
  final int y;

  /// Width in logical pixels.
  final int w;

  /// Height in logical pixels (uncollapsed).
  final int h;

  /// Stable screen key (`<display name>|<width>x<height>`).
  final String screen;

  /// Whether the window was collapsed to title-bar height (32dp).
  final bool collapsed;

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'screen': screen,
    'collapsed': collapsed,
  };

  static StickyGeometry? fromJson(Map<String, Object?> json) {
    final x = json['x'];
    final y = json['y'];
    final w = json['w'];
    final h = json['h'];
    final screen = json['screen'];
    final collapsed = json['collapsed'];
    if (x is! num || y is! num || w is! num || h is! num || screen is! String) {
      return null;
    }
    return StickyGeometry(
      x: x.toInt(),
      y: y.toInt(),
      w: w.toInt(),
      h: h.toInt(),
      screen: screen,
      collapsed: collapsed is bool ? collapsed : false,
    );
  }

  StickyGeometry copyWith({
    int? x,
    int? y,
    int? w,
    int? h,
    String? screen,
    bool? collapsed,
  }) {
    return StickyGeometry(
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      screen: screen ?? this.screen,
      collapsed: collapsed ?? this.collapsed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickyGeometry &&
          x == other.x &&
          y == other.y &&
          w == other.w &&
          h == other.h &&
          screen == other.screen &&
          collapsed == other.collapsed;

  @override
  int get hashCode => Object.hash(x, y, w, h, screen, collapsed);

  @override
  String toString() =>
      'StickyGeometry(x: $x, y: $y, w: $w, h: $h, screen: $screen, collapsed: $collapsed)';
}

/// Stores per-device sticky window geometries in `.tephra/stickies.json`.
class StickyPositionsStore {
  StickyPositionsStore({required this.fs, required this.deviceId});

  final VaultFileSystem fs;
  final String deviceId;

  static final _storePath = VaultPath('.tephra/stickies.json');
  static final _bakPath = VaultPath('.tephra/stickies.json.bak');

  final Map<String, Map<String, StickyGeometry>> _allDevices = {};
  final Map<VaultPath, StickyGeometry> _mine = {};
  Timer? _debounceTimer;
  String _lastSavedJson = '';
  bool _isCorruptedOnDisk = false;
  String _corruptedRawText = '';

  /// All sticky positions for the current device.
  Map<VaultPath, StickyGeometry> get mine => Map.unmodifiable(_mine);

  /// Loads positions from `.tephra/stickies.json`.
  Future<void> load() async {
    _mine.clear();
    _allDevices.clear();
    _isCorruptedOnDisk = false;
    _corruptedRawText = '';

    final stat = await fs.stat(_storePath);
    if (stat == null) {
      _lastSavedJson = '';
      return;
    }

    try {
      final doc = await fs.readText(_storePath);
      final content = doc.text;
      _lastSavedJson = content;
      final dynamic decoded = jsonDecode(content);
      if (decoded is! Map) {
        throw const FormatException('Root is not a JSON map');
      }

      for (final deviceEntry in decoded.entries) {
        final devId = deviceEntry.key.toString();
        final devMap = deviceEntry.value;
        if (devMap is! Map) continue;

        final deviceGeometries = <String, StickyGeometry>{};
        for (final noteEntry in devMap.entries) {
          final notePath = noteEntry.key.toString();
          final val = noteEntry.value;
          if (val is Map) {
            final geom = StickyGeometry.fromJson(val.cast<String, Object?>());
            if (geom != null) {
              deviceGeometries[notePath] = geom;
              if (devId == deviceId) {
                _mine[VaultPath(notePath)] = geom;
              }
            }
          }
        }
        _allDevices[devId] = deviceGeometries;
      }
    } catch (e, st) {
      _log.warning(
        'Malformed .tephra/stickies.json; keeping untouched on disk',
        e,
        st,
      );
      _isCorruptedOnDisk = true;
      try {
        final doc = await fs.readText(_storePath);
        _corruptedRawText = doc.text;
      } catch (_) {}
    }
  }

  /// Updates or records the position of [path] for this device.
  Future<void> save(VaultPath path, StickyGeometry g) async {
    _mine[path] = g;
    final myMap = _allDevices.putIfAbsent(deviceId, () => {});
    myMap[path.value] = g;
    _scheduleDebounce();
  }

  /// Removes the position entry for [path] on this device.
  Future<void> remove(VaultPath path) async {
    _mine.remove(path);
    final myMap = _allDevices[deviceId];
    if (myMap != null) {
      myMap.remove(path.value);
    }
    _scheduleDebounce();
  }

  /// Moves the position entry from [from] to [to].
  Future<void> rename(VaultPath from, VaultPath to) async {
    final g = _mine.remove(from);
    final myMap = _allDevices[deviceId];
    if (myMap != null) {
      myMap.remove(from.value);
    }
    if (g != null) {
      _mine[to] = g;
      myMap?[to.value] = g;
    }
    _scheduleDebounce();
  }

  void _scheduleDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      unawaited(flush());
    });
  }

  /// Flushes pending changes to `.tephra/stickies.json`.
  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    final encoded = _encodeJson();
    if (encoded == _lastSavedJson) return;

    if (_isCorruptedOnDisk) {
      try {
        await fs.writeText(_bakPath, TextDocument(text: _corruptedRawText));
      } catch (e, st) {
        _log.warning(
          'Failed to write backup of corrupted stickies.json',
          e,
          st,
        );
      }
      _isCorruptedOnDisk = false;
      _corruptedRawText = '';
    }

    await fs.writeText(_storePath, TextDocument(text: encoded));
    _lastSavedJson = encoded;
  }

  String _encodeJson() {
    final sortedDeviceKeys = _allDevices.keys.toList()..sort();
    final buffer = StringBuffer('{\n');
    for (var i = 0; i < sortedDeviceKeys.length; i++) {
      final devId = sortedDeviceKeys[i];
      final pathsMap = _allDevices[devId] ?? {};
      final sortedPaths = pathsMap.keys.toList()..sort();
      final isLastDev = i == sortedDeviceKeys.length - 1;

      buffer.write('  ${jsonEncode(devId)}: {\n');
      for (var j = 0; j < sortedPaths.length; j++) {
        final path = sortedPaths[j];
        final g = pathsMap[path]!;
        final isLastPath = j == sortedPaths.length - 1;

        buffer.write('    ${jsonEncode(path)}: {\n');
        buffer.write('      "x": ${g.x},\n');
        buffer.write('      "y": ${g.y},\n');
        buffer.write('      "w": ${g.w},\n');
        buffer.write('      "h": ${g.h},\n');
        buffer.write('      "screen": ${jsonEncode(g.screen)},\n');
        buffer.write('      "collapsed": ${g.collapsed}\n');
        buffer.write('    }${isLastPath ? '' : ','}\n');
      }
      buffer.write('  }${isLastDev ? '' : ','}\n');
    }
    buffer.write('}\n');
    return buffer.toString();
  }

  /// Cancels debounce timer and flushes.
  Future<void> dispose() async {
    await flush();
  }
}
