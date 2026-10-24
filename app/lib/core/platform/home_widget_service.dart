// © 2026 Tephra. All rights reserved.

import 'dart:async';

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

/// Android stub implementation of [HomeWidgetService].
class AndroidHomeWidgetService implements HomeWidgetService {
  @override
  Future<void> saveJson(String key, Map<String, Object?> json) {
    throw UnimplementedError(
      'AndroidHomeWidgetService.saveJson will be implemented in step 04.13',
    );
  }

  @override
  Future<Map<String, Object?>?> readJson(String key) {
    throw UnimplementedError(
      'AndroidHomeWidgetService.readJson will be implemented in step 04.13',
    );
  }

  @override
  Future<void> updateStickyWidgets() {
    throw UnimplementedError(
      'AndroidHomeWidgetService.updateStickyWidgets will be implemented in step 04.13',
    );
  }

  @override
  Future<void> updateStackWidgets() {
    throw UnimplementedError(
      'AndroidHomeWidgetService.updateStackWidgets will be implemented in step 04.13',
    );
  }

  @override
  Future<void> updateCaptureWidgets() {
    throw UnimplementedError(
      'AndroidHomeWidgetService.updateCaptureWidgets will be implemented in step 04.13',
    );
  }

  @override
  Future<List<int>> installedStickyWidgetIds() {
    throw UnimplementedError(
      'AndroidHomeWidgetService.installedStickyWidgetIds will be implemented in step 04.13',
    );
  }

  @override
  Stream<Uri> get widgetLaunches => throw UnimplementedError(
    'AndroidHomeWidgetService.widgetLaunches will be implemented in step 04.13',
  );

  @override
  Future<Uri?> initialWidgetLaunch() {
    throw UnimplementedError(
      'AndroidHomeWidgetService.initialWidgetLaunch will be implemented in step 04.13',
    );
  }
}
