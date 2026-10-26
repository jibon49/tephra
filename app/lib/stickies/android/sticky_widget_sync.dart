// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../core/platform/home_widget_service.dart';
import '../data/sticky_repository.dart';
import 'widget_data.dart';

/// Syncs sticky notes to Android Home Screen Widgets.
final class StickyWidgetSync with WidgetsBindingObserver {
  StickyWidgetSync({
    required this.repo,
    required this.homeWidgets,
    required this.vaultId,
  });

  final StickyRepository repo;
  final HomeWidgetService homeWidgets;
  final String vaultId;

  Timer? _debounceTimer;
  StreamSubscription<StickyChange>? _changesSub;
  final Map<String, String> _lastWrittenJson = {};
  bool _isDisposed = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _changesSub = repo.changes.listen((_) => trigger());
    unawaited(syncNow());
  }

  void trigger() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      if (!_isDisposed) {
        unawaited(syncNow());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(syncNow());
    }
  }

  Future<void> syncNow() async {
    if (_isDisposed) return;

    try {
      final installedIds = await homeWidgets.installedStickyWidgetIds();
      final pathsRaw = await homeWidgets.readJson('sticky_widget_paths');
      final pathsMap = pathsRaw != null
          ? Map<String, Object?>.from(pathsRaw)
          : <String, Object?>{};

      var pathsChanged = false;
      final staleKeys = <String>[];
      for (final entry in pathsMap.entries) {
        final id = int.tryParse(entry.key);
        if (id != null && !installedIds.contains(id)) {
          staleKeys.add(entry.key);
          _lastWrittenJson.remove('sticky_widget_$id');
          unawaited(
            homeWidgets.saveJson('sticky_widget_$id', {
              'v': 1,
              'configured': false,
            }),
          );
        }
      }

      for (final k in staleKeys) {
        pathsMap.remove(k);
        pathsChanged = true;
      }

      if (pathsChanged) {
        await homeWidgets.saveJson('sticky_widget_paths', pathsMap);
      }

      var updatedSingle = false;
      for (final widgetId in installedIds) {
        final pathStr = pathsMap[widgetId.toString()] as String?;
        final Map<String, Object?> singleJson;
        if (pathStr == null || pathStr.isEmpty) {
          singleJson = stickyWidgetJson(
            null,
            vaultId: vaultId,
            configured: false,
          );
        } else {
          final sticky = repo.byPath(VaultPath(pathStr));
          singleJson = stickyWidgetJson(
            sticky,
            vaultId: vaultId,
            configured: true,
            missingPath: pathStr,
          );
        }

        final encoded = jsonEncode(singleJson);
        final key = 'sticky_widget_$widgetId';
        if (_lastWrittenJson[key] != encoded) {
          await homeWidgets.saveJson(key, singleJson);
          _lastWrittenJson[key] = encoded;
          updatedSingle = true;
        }
      }

      if (updatedSingle) {
        await homeWidgets.updateStickyWidgets();
      }

      // Stack widget
      final active = repo.all;
      final stackJson = stackWidgetJson(active, vaultId: vaultId);
      final stackEncoded = jsonEncode(stackJson);
      const stackKey = 'sticky_stack';
      if (_lastWrittenJson[stackKey] != stackEncoded) {
        await homeWidgets.saveJson(stackKey, stackJson);
        _lastWrittenJson[stackKey] = stackEncoded;
        await homeWidgets.updateStackWidgets();
      }
    } catch (_) {
      // Platform communication errors during widget sync should not crash the app
    }
  }

  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _changesSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
