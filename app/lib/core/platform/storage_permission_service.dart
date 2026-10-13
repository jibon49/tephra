// © 2026 Tephra. All rights reserved.

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Storage permission status states.
enum StorageAccess { granted, denied, permanentlyDenied, notNeeded }

/// Abstract interface for querying and requesting storage access permissions.
abstract interface class StoragePermissionService {
  Future<StorageAccess> status();
  Future<StorageAccess> request();
  Future<void> openSystemSettings();
}

/// No-op implementation for platforms where explicit storage permissions are not needed (Windows, Web).
final class NoopStoragePermissionService implements StoragePermissionService {
  const NoopStoragePermissionService();

  @override
  Future<StorageAccess> status() async => StorageAccess.notNeeded;

  @override
  Future<StorageAccess> request() async => StorageAccess.notNeeded;

  @override
  Future<void> openSystemSettings() async {}
}

/// Android-specific storage permission service using [permission_handler] and [device_info_plus].
final class AndroidStoragePermissionService
    implements StoragePermissionService {
  AndroidStoragePermissionService({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;
  int? _sdkInt;

  Future<int> _getSdkInt() async {
    if (_sdkInt != null) return _sdkInt!;
    final info = await _deviceInfo.androidInfo;
    _sdkInt = info.version.sdkInt;
    return _sdkInt!;
  }

  Future<Permission> _getPermission() async {
    final sdk = await _getSdkInt();
    return sdk >= 30 ? Permission.manageExternalStorage : Permission.storage;
  }

  StorageAccess _mapStatus(PermissionStatus s) {
    if (s.isGranted) return StorageAccess.granted;
    if (s.isPermanentlyDenied) return StorageAccess.permanentlyDenied;
    return StorageAccess.denied;
  }

  @override
  Future<StorageAccess> status() async {
    final perm = await _getPermission();
    final s = await perm.status;
    return _mapStatus(s);
  }

  @override
  Future<StorageAccess> request() async {
    final perm = await _getPermission();
    final s = await perm.request();
    return _mapStatus(s);
  }

  @override
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}
