// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:home_widget/home_widget.dart';

/// Android home-screen widget communication service.
abstract interface class HomeWidgetService {
  Future<void> saveJson(String key, Map<String, Object?> json);
  Future<Map<String, Object?>?> readJson(String key);
  Future<void>
  updateStickyWidgets(); // asks Android to redraw the single-sticky widgets
  Future<void> updateStackWidgets();
  Future<void> updateCaptureWidgets();
  Future<List<int>> installedStickyWidgetIds();
  Stream<Uri>
  get widgetLaunches; // URIs from widget taps that opened/resumed the app
  Future<Uri?> initialWidgetLaunch();
}

/// No-op implementation of [HomeWidgetService] for unsupported platforms.
class NoopHomeWidgetService implements HomeWidgetService {
  const NoopHomeWidgetService();

  @override
  Future<void> saveJson(String key, Map<String, Object?> json) async {}

  @override
  Future<Map<String, Object?>?> readJson(String key) async => null;

  @override
  Future<void> updateStickyWidgets() async {}

  @override
  Future<void> updateStackWidgets() async {}

  @override
  Future<void> updateCaptureWidgets() async {}

  @override
  Future<List<int>> installedStickyWidgetIds() async => const [];

  @override
  Stream<Uri> get widgetLaunches => const Stream.empty();

  @override
  Future<Uri?> initialWidgetLaunch() async => null;
}

/// Android production implementation of [HomeWidgetService].
class AndroidHomeWidgetService implements HomeWidgetService {
  static const String stickyWidgetProviderClass =
      'com.tephra.app.StickyWidgetProvider';
  static const String stickyStackWidgetProviderClass =
      'com.tephra.app.StickyStackWidgetProvider';
  static const String quickCaptureWidgetProviderClass =
      'com.tephra.app.QuickCaptureWidgetProvider';

  @override
  Future<void> saveJson(String key, Map<String, Object?> json) async {
    final jsonString = jsonEncode(json);
    await HomeWidget.saveWidgetData<String>(key, jsonString);
  }

  @override
  Future<Map<String, Object?>?> readJson(String key) async {
    final raw = await HomeWidget.getWidgetData<String>(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return decoded.cast<String, Object?>();
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateStickyWidgets() async {
    await HomeWidget.updateWidget(
      qualifiedAndroidName: stickyWidgetProviderClass,
    );
  }

  @override
  Future<void> updateStackWidgets() async {
    await HomeWidget.updateWidget(
      qualifiedAndroidName: stickyStackWidgetProviderClass,
    );
  }

  @override
  Future<void> updateCaptureWidgets() async {
    try {
      await HomeWidget.updateWidget(
        qualifiedAndroidName: quickCaptureWidgetProviderClass,
      );
    } catch (_) {}
  }

  @override
  Future<List<int>> installedStickyWidgetIds() async {
    try {
      final all = await HomeWidget.getInstalledWidgets();
      return all
          .where(
            (w) =>
                w.androidClassName != null &&
                w.androidClassName!.endsWith('StickyWidgetProvider'),
          )
          .map((w) => w.androidWidgetId)
          .whereType<int>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Stream<Uri> get widgetLaunches =>
      HomeWidget.widgetClicked.where((u) => u != null).cast<Uri>();

  @override
  Future<Uri?> initialWidgetLaunch() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }
}
