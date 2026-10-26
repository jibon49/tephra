// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../settings/app_settings.dart';
import '../settings/vault_settings.dart';
import '../vault/vault_session.dart';

/// Configuration for daily notes within [HeadlessConfig].
@immutable
final class HeadlessDailyNoteConfig {
  const HeadlessDailyNoteConfig({
    required this.folder,
    required this.format,
    required this.template,
  });

  factory HeadlessDailyNoteConfig.fromJson(Map<String, Object?> json) =>
      HeadlessDailyNoteConfig(
        folder: json['folder'] as String? ?? '',
        format: json['format'] as String? ?? 'YYYY-MM-DD',
        template: json['template'] as String? ?? '',
      );

  final String folder;
  final String format;
  final String template;

  Map<String, Object?> toJson() => {
    'folder': folder,
    'format': format,
    'template': template,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeadlessDailyNoteConfig &&
          runtimeType == other.runtimeType &&
          folder == other.folder &&
          format == other.format &&
          template == other.template;

  @override
  int get hashCode => Object.hash(folder, format, template);
}

/// Headless configuration persisted to `<appSupportDir>/headless.json` for background
/// isolates, widgets, and notification quick replies that do not run full Riverpod state.
@immutable
final class HeadlessConfig {
  const HeadlessConfig({
    this.version = currentVersion,
    required this.vaultId,
    required this.vaultRoot,
    required this.fsKind,
    required this.stickyFolder,
    required this.dailyNote,
    required this.quickTarget,
    required this.inboxPath,
    required this.deviceName,
  });

  factory HeadlessConfig.fromSession({
    required VaultSession session,
    required VaultSettings vaultSettings,
    required AppSettings appSettings,
  }) {
    final String fsKind;
    if (session.fs is IoVaultFileSystem) {
      fsKind = 'io';
    } else {
      fsKind = session.isAppPrivate ? 'saf' : 'io';
    }

    return HeadlessConfig(
      version: currentVersion,
      vaultId: session.vaultId,
      vaultRoot: session.rootDir,
      fsKind: fsKind,
      stickyFolder: vaultSettings.stickyFolder,
      dailyNote: HeadlessDailyNoteConfig(
        folder: vaultSettings.dailyNotesSettings.folder,
        format: vaultSettings.dailyNotesSettings.format,
        template: vaultSettings.dailyNotesSettings.template,
      ),
      quickTarget: vaultSettings.quickCaptureTarget,
      inboxPath: vaultSettings.inboxNotePath,
      deviceName: appSettings.deviceName,
    );
  }

  static const int currentVersion = 1;
  static const String defaultFileName = 'headless.json';

  final int version;
  final String vaultId;
  final String vaultRoot;
  final String fsKind;
  final String stickyFolder;
  final HeadlessDailyNoteConfig dailyNote;
  final String quickTarget;
  final String inboxPath;
  final String deviceName;

  static HeadlessConfig? fromJson(Map<String, Object?> json) {
    final v = json['v'];
    if (v != currentVersion) return null;

    final vaultId = json['vaultId'] as String?;
    final vaultRoot = json['vaultRoot'] as String?;
    final fsKind = json['fsKind'] as String?;
    final stickyFolder = json['stickyFolder'] as String?;
    final dailyNoteMap = json['dailyNote'] as Map?;
    final quickTarget = json['quickTarget'] as String?;
    final inboxPath = json['inboxPath'] as String?;
    final deviceName = json['deviceName'] as String?;

    if (vaultId == null ||
        vaultRoot == null ||
        fsKind == null ||
        stickyFolder == null ||
        dailyNoteMap == null ||
        quickTarget == null ||
        inboxPath == null ||
        deviceName == null) {
      return null;
    }

    return HeadlessConfig(
      version: v as int,
      vaultId: vaultId,
      vaultRoot: vaultRoot,
      fsKind: fsKind,
      stickyFolder: stickyFolder,
      dailyNote: HeadlessDailyNoteConfig.fromJson(
        Map<String, Object?>.from(dailyNoteMap),
      ),
      quickTarget: quickTarget,
      inboxPath: inboxPath,
      deviceName: deviceName,
    );
  }

  Map<String, Object?> toJson() => {
    'v': version,
    'vaultId': vaultId,
    'vaultRoot': vaultRoot,
    'fsKind': fsKind,
    'stickyFolder': stickyFolder,
    'dailyNote': dailyNote.toJson(),
    'quickTarget': quickTarget,
    'inboxPath': inboxPath,
    'deviceName': deviceName,
  };

  static Future<HeadlessConfig?> load(File file) async {
    if (!file.existsSync()) return null;
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) return null;
      return HeadlessConfig.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static HeadlessConfig? loadSync(File file) {
    if (!file.existsSync()) return null;
    try {
      final text = file.readAsStringSync();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) return null;
      return HeadlessConfig.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Writes the configuration atomically to [targetFile] via a temporary file rename.
  Future<void> save(File targetFile) async {
    final parent = targetFile.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
    final tmpFile = File(
      '${targetFile.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final content = const JsonEncoder.withIndent('  ').convert(toJson());
      await tmpFile.writeAsString(content, flush: true);
      if (!kIsWeb && Platform.isWindows && targetFile.existsSync()) {
        await targetFile.delete();
      }
      await tmpFile.rename(targetFile.path);
    } finally {
      if (tmpFile.existsSync()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Synchronous atomic write for background scripts or synchronous handlers.
  void saveSync(File targetFile) {
    final parent = targetFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final tmpFile = File(
      '${targetFile.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final content = const JsonEncoder.withIndent('  ').convert(toJson());
      tmpFile.writeAsStringSync(content, flush: true);
      if (!kIsWeb && Platform.isWindows && targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      tmpFile.renameSync(targetFile.path);
    } finally {
      if (tmpFile.existsSync()) {
        try {
          tmpFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeadlessConfig &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          vaultId == other.vaultId &&
          vaultRoot == other.vaultRoot &&
          fsKind == other.fsKind &&
          stickyFolder == other.stickyFolder &&
          dailyNote == other.dailyNote &&
          quickTarget == other.quickTarget &&
          inboxPath == other.inboxPath &&
          deviceName == other.deviceName;

  @override
  int get hashCode => Object.hash(
    version,
    vaultId,
    vaultRoot,
    fsKind,
    stickyFolder,
    dailyNote,
    quickTarget,
    inboxPath,
    deviceName,
  );
}
