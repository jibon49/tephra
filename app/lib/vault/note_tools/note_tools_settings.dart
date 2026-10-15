// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';

/// Settings for daily notes (.obsidian/daily-notes.json / dailyNotes.*).
@immutable
final class DailyNotesSettings {
  const DailyNotesSettings({
    this.format = 'YYYY-MM-DD',
    this.folder = '',
    this.template = '',
    this.openOnStartup = false,
  });

  factory DailyNotesSettings.fromMap(Map<String, Object?> map) {
    final rawFormat = map['format'] as String?;
    final format = (rawFormat == null || rawFormat.isEmpty)
        ? 'YYYY-MM-DD'
        : rawFormat;
    final folder = map['folder'] as String? ?? '';
    final template = map['template'] as String? ?? '';
    final openOnStartup =
        map['openOnStartup'] as bool? ?? map['autorun'] as bool? ?? false;
    return DailyNotesSettings(
      format: format,
      folder: folder,
      template: template,
      openOnStartup: openOnStartup,
    );
  }

  final String format;
  final String folder;
  final String template;
  final bool openOnStartup;

  Map<String, Object?> toMap() => {
    'format': format,
    'folder': folder,
    'template': template,
    'openOnStartup': openOnStartup,
  };

  DailyNotesSettings copyWith({
    String? format,
    String? folder,
    String? template,
    bool? openOnStartup,
  }) {
    return DailyNotesSettings(
      format: format ?? this.format,
      folder: folder ?? this.folder,
      template: template ?? this.template,
      openOnStartup: openOnStartup ?? this.openOnStartup,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyNotesSettings &&
          format == other.format &&
          folder == other.folder &&
          template == other.template &&
          openOnStartup == other.openOnStartup;

  @override
  int get hashCode => Object.hash(format, folder, template, openOnStartup);
}

/// Settings for unique note creator (.obsidian/zk-prefixer.json / uniqueNote.*).
@immutable
final class UniqueNoteSettings {
  const UniqueNoteSettings({
    this.prefixFormat = 'YYYYMMDDHHmm',
    this.folder = '',
    this.template = '',
  });

  factory UniqueNoteSettings.fromMap(Map<String, Object?> map) {
    final rawPrefix = (map['prefixFormat'] ?? map['format']) as String?;
    final prefixFormat = (rawPrefix == null || rawPrefix.isEmpty)
        ? 'YYYYMMDDHHmm'
        : rawPrefix;
    final folder = map['folder'] as String? ?? '';
    final template = map['template'] as String? ?? '';
    return UniqueNoteSettings(
      prefixFormat: prefixFormat,
      folder: folder,
      template: template,
    );
  }

  final String prefixFormat;
  final String folder;
  final String template;

  Map<String, Object?> toMap() => {
    'prefixFormat': prefixFormat,
    'folder': folder,
    'template': template,
  };

  UniqueNoteSettings copyWith({
    String? prefixFormat,
    String? folder,
    String? template,
  }) {
    return UniqueNoteSettings(
      prefixFormat: prefixFormat ?? this.prefixFormat,
      folder: folder ?? this.folder,
      template: template ?? this.template,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UniqueNoteSettings &&
          prefixFormat == other.prefixFormat &&
          folder == other.folder &&
          template == other.template;

  @override
  int get hashCode => Object.hash(prefixFormat, folder, template);
}
