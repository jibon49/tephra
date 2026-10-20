// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';

/// A vault recently opened by the user.
@immutable
final class RecentVault {
  const RecentVault({
    required this.path,
    required this.name,
    required this.lastOpened,
  });

  factory RecentVault.fromJson(Map<String, Object?> json) {
    return RecentVault(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastOpened: json['lastOpened'] != null
          ? DateTime.tryParse(json['lastOpened'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String path;
  final String name;
  final DateTime lastOpened;

  Map<String, Object?> toJson() => {
    'path': path,
    'name': name,
    'lastOpened': lastOpened.toIso8601String(),
  };

  RecentVault copyWith({String? path, String? name, DateTime? lastOpened}) {
    return RecentVault(
      path: path ?? this.path,
      name: name ?? this.name,
      lastOpened: lastOpened ?? this.lastOpened,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentVault &&
          path == other.path &&
          name == other.name &&
          lastOpened == other.lastOpened;

  @override
  int get hashCode => Object.hash(path, name, lastOpened);

  @override
  String toString() => 'RecentVault($name, $path, $lastOpened)';
}

/// Global application settings stored in `<appSupportDir>/settings.json`.
@immutable
final class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.recentVaults = const [],
    required this.deviceId,
    this.deviceName = '',
    this.lastVaultPath,
    this.recentCommands = const [],
    this.pagePreviewReadingRequiresCtrl = false,
    this.pagePreviewEditorRequiresCtrl = true,
    this.switcherShowAttachments = false,
    this.keepSyncingWhenClosed = false,
    this.extra = const {},
  });

  factory AppSettings.fromJson(
    Map<String, Object?> json, {
    required String Function() newDeviceId,
  }) {
    final deviceId = json['deviceId'] as String? ?? newDeviceId();
    final themeMode = json['themeMode'] as String? ?? 'system';
    final deviceName = json['deviceName'] as String? ?? '';
    final lastVaultPath = json['lastVaultPath'] as String?;
    final pagePreviewReadingRequiresCtrl =
        json['pagePreviewReadingRequiresCtrl'] as bool? ?? false;
    final pagePreviewEditorRequiresCtrl =
        json['pagePreviewEditorRequiresCtrl'] as bool? ?? true;
    final switcherShowAttachments =
        json['switcherShowAttachments'] as bool? ?? false;
    final keepSyncingWhenClosed =
        json['keepSyncingWhenClosed'] as bool? ??
        (json['app.keepRunningInTray'] as bool? ?? false);

    final rawRecentVaults = json['recentVaults'];
    final recentVaults = <RecentVault>[];
    if (rawRecentVaults is List) {
      for (final item in rawRecentVaults) {
        if (item is Map) {
          recentVaults.add(RecentVault.fromJson(item.cast<String, Object?>()));
        }
      }
    }

    final rawRecentCommands = json['recentCommands'];
    final recentCommands = <String>[];
    if (rawRecentCommands is List) {
      for (final item in rawRecentCommands) {
        if (item is String) {
          recentCommands.add(item);
        }
      }
    }

    const knownKeys = {
      'deviceId',
      'themeMode',
      'deviceName',
      'lastVaultPath',
      'recentVaults',
      'recentCommands',
      'pagePreviewReadingRequiresCtrl',
      'pagePreviewEditorRequiresCtrl',
      'switcherShowAttachments',
      'keepSyncingWhenClosed',
      'app.keepRunningInTray',
    };
    final extra = <String, Object?>{};
    for (final entry in json.entries) {
      if (!knownKeys.contains(entry.key)) {
        extra[entry.key] = entry.value;
      }
    }

    return AppSettings(
      deviceId: deviceId,
      themeMode: themeMode,
      deviceName: deviceName,
      lastVaultPath: lastVaultPath,
      recentVaults: List.unmodifiable(recentVaults.take(12)),
      recentCommands: List.unmodifiable(recentCommands.take(10)),
      pagePreviewReadingRequiresCtrl: pagePreviewReadingRequiresCtrl,
      pagePreviewEditorRequiresCtrl: pagePreviewEditorRequiresCtrl,
      switcherShowAttachments: switcherShowAttachments,
      keepSyncingWhenClosed: keepSyncingWhenClosed,
      extra: Map.unmodifiable(extra),
    );
  }

  /// 'system' | 'light' | 'dark'
  final String themeMode;

  /// Newest first, max 12.
  final List<RecentVault> recentVaults;

  /// UUID v4 generated on first run.
  final String deviceId;

  /// User-facing device name.
  final String deviceName;

  /// Path of the last opened vault to re-open on startup.
  final String? lastVaultPath;

  /// IDs of recently used palette commands, newest first, max 10.
  final List<String> recentCommands;

  /// Whether hovering over internal links in reading view requires holding Ctrl to show page preview.
  final bool pagePreviewReadingRequiresCtrl;

  /// Whether hovering over internal links in editor view requires holding Ctrl to show page preview.
  final bool pagePreviewEditorRequiresCtrl;

  /// Whether the quick switcher includes non-markdown attachments.
  final bool switcherShowAttachments;

  /// Whether to keep the app and sync workers running in the system tray when the window is closed.
  final bool keepSyncingWhenClosed;

  /// Unknown keys preserved on read/write.
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'themeMode': themeMode,
      'recentVaults': recentVaults.map((v) => v.toJson()).toList(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      if (lastVaultPath != null) 'lastVaultPath': lastVaultPath,
      'recentCommands': recentCommands,
      'pagePreviewReadingRequiresCtrl': pagePreviewReadingRequiresCtrl,
      'pagePreviewEditorRequiresCtrl': pagePreviewEditorRequiresCtrl,
      'switcherShowAttachments': switcherShowAttachments,
      'keepSyncingWhenClosed': keepSyncingWhenClosed,
    };
    map.addAll(extra);
    return map;
  }

  AppSettings copyWith({
    String? themeMode,
    List<RecentVault>? recentVaults,
    String? deviceId,
    String? deviceName,
    String? Function()? lastVaultPath,
    List<String>? recentCommands,
    bool? pagePreviewReadingRequiresCtrl,
    bool? pagePreviewEditorRequiresCtrl,
    bool? switcherShowAttachments,
    bool? keepSyncingWhenClosed,
    Map<String, Object?>? extra,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      recentVaults: recentVaults ?? this.recentVaults,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      lastVaultPath: lastVaultPath != null
          ? lastVaultPath()
          : this.lastVaultPath,
      recentCommands: recentCommands ?? this.recentCommands,
      pagePreviewReadingRequiresCtrl:
          pagePreviewReadingRequiresCtrl ?? this.pagePreviewReadingRequiresCtrl,
      pagePreviewEditorRequiresCtrl:
          pagePreviewEditorRequiresCtrl ?? this.pagePreviewEditorRequiresCtrl,
      switcherShowAttachments:
          switcherShowAttachments ?? this.switcherShowAttachments,
      keepSyncingWhenClosed:
          keepSyncingWhenClosed ?? this.keepSyncingWhenClosed,
      extra: extra ?? this.extra,
    );
  }

  /// Adds [path] to [recentVaults], moving it to front if already present. Max 12.
  AppSettings addRecentVault(String path, String name, [DateTime? time]) {
    final now = time ?? DateTime.now();
    final updated = <RecentVault>[
      RecentVault(path: path, name: name, lastOpened: now),
    ];
    for (final v in recentVaults) {
      if (v.path != path) {
        updated.add(v);
      }
    }
    return copyWith(
      recentVaults: List.unmodifiable(updated.take(12)),
      lastVaultPath: () => path,
    );
  }

  /// Removes [path] from [recentVaults] and clears [lastVaultPath] if matched.
  AppSettings removeRecentVault(String path) {
    final updated = recentVaults.where((v) => v.path != path).toList();
    final newLast = lastVaultPath == path ? null : lastVaultPath;
    return copyWith(
      recentVaults: List.unmodifiable(updated),
      lastVaultPath: () => newLast,
    );
  }

  /// Inserts [commandId] at the front of [recentCommands], removing any prior occurrence. Max 10.
  AppSettings touchCommand(String commandId) {
    final updated = <String>[commandId];
    for (final id in recentCommands) {
      if (id != commandId) {
        updated.add(id);
      }
    }
    return copyWith(recentCommands: List.unmodifiable(updated.take(10)));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          themeMode == other.themeMode &&
          listEquals(recentVaults, other.recentVaults) &&
          deviceId == other.deviceId &&
          deviceName == other.deviceName &&
          lastVaultPath == other.lastVaultPath &&
          listEquals(recentCommands, other.recentCommands) &&
          pagePreviewReadingRequiresCtrl ==
              other.pagePreviewReadingRequiresCtrl &&
          pagePreviewEditorRequiresCtrl ==
              other.pagePreviewEditorRequiresCtrl &&
          switcherShowAttachments == other.switcherShowAttachments &&
          keepSyncingWhenClosed == other.keepSyncingWhenClosed &&
          mapEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    themeMode,
    Object.hashAll(recentVaults),
    deviceId,
    deviceName,
    lastVaultPath,
    Object.hashAll(recentCommands),
    pagePreviewReadingRequiresCtrl,
    pagePreviewEditorRequiresCtrl,
    switcherShowAttachments,
    keepSyncingWhenClosed,
    Object.hashAll(extra.entries),
  );
}
