// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Where new files should be created by default.
enum NewFileLocation {
  root,
  current,
  folder;

  static NewFileLocation fromString(String val) {
    switch (val) {
      case 'current':
        return NewFileLocation.current;
      case 'folder':
        return NewFileLocation.folder;
      default:
        return NewFileLocation.root;
    }
  }

  String toJson() => name;
}

/// User's preferred trash handling mode.
enum TrashChoice {
  system,
  vaultTrash,
  permanent;

  static TrashChoice fromString(String val) {
    switch (val) {
      case 'system':
        return TrashChoice.system;
      case 'permanent':
        return TrashChoice.permanent;
      default:
        return TrashChoice.vaultTrash;
    }
  }

  TrashMode toTrashMode() {
    switch (this) {
      case TrashChoice.system:
        return TrashMode.system;
      case TrashChoice.permanent:
        return TrashMode.permanent;
      case TrashChoice.vaultTrash:
        return TrashMode.vaultTrash;
    }
  }

  String toJson() => name;
}

/// Default view mode when opening a tab.
enum ViewModeSetting {
  reading,
  source;

  static ViewModeSetting fromString(String val) {
    switch (val) {
      case 'source':
        return ViewModeSetting.source;
      default:
        return ViewModeSetting.reading;
    }
  }

  String toJson() => name;
}

/// Sort order for files in file explorer.
enum ExplorerSort {
  nameAsc,
  nameDesc,
  modifiedNew,
  modifiedOld,
  createdNew,
  createdOld;

  static ExplorerSort fromString(String val) {
    for (final e in ExplorerSort.values) {
      if (e.name == val) return e;
    }
    return ExplorerSort.nameAsc;
  }

  String toJson() => name;
}

/// Templates settings model.
@immutable
final class TemplatesSettings {
  const TemplatesSettings({
    this.folder = '',
    this.dateFormat = 'YYYY-MM-DD',
    this.timeFormat = 'HH:mm',
  });

  factory TemplatesSettings.fromMap(Map<String, Object?> map) {
    return TemplatesSettings(
      folder: map['folder'] as String? ?? '',
      dateFormat: map['dateFormat'] as String? ?? 'YYYY-MM-DD',
      timeFormat: map['timeFormat'] as String? ?? 'HH:mm',
    );
  }

  final String folder;
  final String dateFormat;
  final String timeFormat;

  Map<String, Object?> toMap() => {
    'folder': folder,
    'dateFormat': dateFormat,
    'timeFormat': timeFormat,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplatesSettings &&
          folder == other.folder &&
          dateFormat == other.dateFormat &&
          timeFormat == other.timeFormat;

  @override
  int get hashCode => Object.hash(folder, dateFormat, timeFormat);
}

/// Core plugins settings model.
@immutable
final class CorePluginsSettings {
  const CorePluginsSettings({this.slashCommands = true});

  factory CorePluginsSettings.fromMap(Map<String, Object?> map) {
    return CorePluginsSettings(
      slashCommands: map['slashCommands'] as bool? ?? true,
    );
  }

  final bool slashCommands;

  Map<String, Object?> toMap() => {'slashCommands': slashCommands};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CorePluginsSettings && slashCommands == other.slashCommands;

  @override
  int get hashCode => slashCommands.hashCode;
}

/// Default editor settings.
const defaultEditor = <String, Object?>{'defaultEditingMode': 'livePreview'};

/// Editor settings model.
@immutable
final class EditorSettings {
  const EditorSettings({this.defaultEditingMode = 'livePreview'});

  factory EditorSettings.fromMap(Map<String, Object?> map) {
    var mode = map['defaultEditingMode'] as String? ?? 'livePreview';
    if (mode != 'livePreview' && mode != 'source') {
      mode = 'livePreview';
    }
    return EditorSettings(defaultEditingMode: mode);
  }

  final String defaultEditingMode;

  Map<String, Object?> toMap() => {'defaultEditingMode': defaultEditingMode};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorSettings && defaultEditingMode == other.defaultEditingMode;

  @override
  int get hashCode => defaultEditingMode.hashCode;
}

/// Configuration settings for a single vault stored in `.tephra/settings.json`.
@immutable
final class VaultSettings {
  const VaultSettings({
    this.attachmentFolder = '/',
    this.newFileLocation = 'root',
    this.newFileFolder = '',
    this.trashMode = 'vaultTrash',
    this.showHidden = false,
    this.useTab = true,
    this.tabSize = 4,
    this.readableLineLength = true,
    this.defaultViewMode = 'reading',
    this.fontSize = 16.0,
    this.explorerSort = 'nameAsc',
    this.dailyNotes = const {},
    this.templates = defaultTemplates,
    this.corePlugins = defaultCorePlugins,
    this.editor = defaultEditor,
    this.importedFromObsidian = false,
    this.newLinkFormat = 'shortest',
    this.useMarkdownLinks = false,
    this.alwaysUpdateLinks = true,
    this.excludedFolders = const [],
    this.extra = const {},
  });

  factory VaultSettings.fromJson(Map<String, Object?> json) {
    final attachmentFolder = json['attachmentFolder'] as String? ?? '/';

    var newFileLocation = json['newFileLocation'] as String? ?? 'root';
    if (newFileLocation != 'root' &&
        newFileLocation != 'current' &&
        newFileLocation != 'folder') {
      newFileLocation = 'root';
    }

    final newFileFolder = json['newFileFolder'] as String? ?? '';

    var trashMode = json['trashMode'] as String? ?? 'vaultTrash';
    if (trashMode != 'system' &&
        trashMode != 'vaultTrash' &&
        trashMode != 'permanent') {
      trashMode = 'vaultTrash';
    }

    final showHidden = json['showHidden'] as bool? ?? false;
    final useTab = json['useTab'] as bool? ?? true;

    var tabSize = json['tabSize'] as int? ?? 4;
    if (tabSize < 2 || tabSize > 8) {
      tabSize = 4;
    }

    final readableLineLength = json['readableLineLength'] as bool? ?? true;

    var defaultViewMode = json['defaultViewMode'] as String? ?? 'reading';
    if (defaultViewMode != 'reading' && defaultViewMode != 'source') {
      defaultViewMode = 'reading';
    }

    var fontSize = (json['fontSize'] as num?)?.toDouble() ?? 16.0;
    if (fontSize < 12.0 || fontSize > 32.0) {
      fontSize = 16.0;
    }

    var explorerSort = json['explorerSort'] as String? ?? 'nameAsc';
    if (!ExplorerSort.values.any((e) => e.name == explorerSort)) {
      explorerSort = 'nameAsc';
    }

    final rawDaily = json['dailyNotes'];
    final dailyNotes = rawDaily is Map
        ? rawDaily.cast<String, Object?>()
        : const <String, Object?>{};

    final rawTemplates = json['templates'];
    final Map<String, Object?> templates;
    if (rawTemplates is Map) {
      templates = rawTemplates.cast<String, Object?>();
    } else {
      templates = defaultTemplates;
    }

    final rawCorePlugins = json['corePlugins'];
    final Map<String, Object?> corePlugins;
    if (rawCorePlugins is Map) {
      corePlugins = rawCorePlugins.cast<String, Object?>();
    } else {
      corePlugins = defaultCorePlugins;
    }

    final rawEditor = json['editor'];
    final Map<String, Object?> editor;
    if (rawEditor is Map) {
      editor = rawEditor.cast<String, Object?>();
    } else {
      editor = defaultEditor;
    }

    final importedFromObsidian = json['importedFromObsidian'] as bool? ?? false;

    var newLinkFormat = json['newLinkFormat'] as String? ?? 'shortest';
    if (newLinkFormat != 'shortest' &&
        newLinkFormat != 'relative' &&
        newLinkFormat != 'absolute') {
      newLinkFormat = 'shortest';
    }

    final useMarkdownLinks = json['useMarkdownLinks'] as bool? ?? false;
    final alwaysUpdateLinks = json['alwaysUpdateLinks'] as bool? ?? true;

    final rawExcluded = json['excludedFolders'];
    final excludedFolders = rawExcluded is List
        ? rawExcluded
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : const <String>[];

    const knownKeys = {
      'attachmentFolder',
      'newFileLocation',
      'newFileFolder',
      'trashMode',
      'showHidden',
      'useTab',
      'tabSize',
      'readableLineLength',
      'defaultViewMode',
      'fontSize',
      'explorerSort',
      'dailyNotes',
      'templates',
      'corePlugins',
      'editor',
      'importedFromObsidian',
      'newLinkFormat',
      'useMarkdownLinks',
      'alwaysUpdateLinks',
      'excludedFolders',
    };

    final extra = <String, Object?>{};
    for (final entry in json.entries) {
      if (!knownKeys.contains(entry.key)) {
        extra[entry.key] = entry.value;
      }
    }

    return VaultSettings(
      attachmentFolder: attachmentFolder,
      newFileLocation: newFileLocation,
      newFileFolder: newFileFolder,
      trashMode: trashMode,
      showHidden: showHidden,
      useTab: useTab,
      tabSize: tabSize,
      readableLineLength: readableLineLength,
      defaultViewMode: defaultViewMode,
      fontSize: fontSize,
      explorerSort: explorerSort,
      dailyNotes: Map.unmodifiable(dailyNotes),
      templates: Map.unmodifiable(templates),
      corePlugins: Map.unmodifiable(corePlugins),
      editor: Map.unmodifiable(editor),
      importedFromObsidian: importedFromObsidian,
      newLinkFormat: newLinkFormat,
      useMarkdownLinks: useMarkdownLinks,
      alwaysUpdateLinks: alwaysUpdateLinks,
      excludedFolders: List.unmodifiable(excludedFolders),
      extra: Map.unmodifiable(extra),
    );
  }

  static const defaultTemplates = <String, Object?>{
    'folder': '',
    'dateFormat': 'YYYY-MM-DD',
    'timeFormat': 'HH:mm',
  };

  static const defaultCorePlugins = <String, Object?>{'slashCommands': true};

  final String attachmentFolder;
  final String newFileLocation;
  final String newFileFolder;
  final String trashMode;
  final bool showHidden;
  final bool useTab;
  final int tabSize;
  final bool readableLineLength;
  final String defaultViewMode;
  final double fontSize;
  final String explorerSort;
  final Map<String, Object?> dailyNotes;
  final Map<String, Object?> templates;
  final Map<String, Object?> corePlugins;
  final Map<String, Object?> editor;
  final bool importedFromObsidian;
  final String newLinkFormat;
  final bool useMarkdownLinks;
  final bool alwaysUpdateLinks;
  final List<String> excludedFolders;
  final Map<String, Object?> extra;

  NewFileLocation get newFileLocationEnum =>
      NewFileLocation.fromString(newFileLocation);

  TrashChoice get trashChoice => TrashChoice.fromString(trashMode);

  TrashMode get trashModeEnum => trashChoice.toTrashMode();

  ViewModeSetting get viewMode => ViewModeSetting.fromString(defaultViewMode);

  ExplorerSort get explorerSortEnum => ExplorerSort.fromString(explorerSort);

  NewLinkFormat get newLinkFormatEnum => NewLinkFormat.fromJson(newLinkFormat);

  LinkFormatSettings get linkFormatSettings => LinkFormatSettings(
    format: newLinkFormatEnum,
    useMarkdownLinks: useMarkdownLinks,
  );

  TemplatesSettings get templatesSettings =>
      TemplatesSettings.fromMap(templates);

  CorePluginsSettings get corePluginsSettings =>
      CorePluginsSettings.fromMap(corePlugins);

  EditorSettings get editorSettings => EditorSettings.fromMap(editor);

  String get templatesFolder => templates['folder'] as String? ?? '';
  String get templatesDateFormat =>
      templates['dateFormat'] as String? ?? 'YYYY-MM-DD';
  String get templatesTimeFormat =>
      templates['timeFormat'] as String? ?? 'HH:mm';
  bool get slashCommandsEnabled =>
      corePlugins['slashCommands'] as bool? ?? true;

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'attachmentFolder': attachmentFolder,
      'newFileLocation': newFileLocation,
      'newFileFolder': newFileFolder,
      'trashMode': trashMode,
      'showHidden': showHidden,
      'useTab': useTab,
      'tabSize': tabSize,
      'readableLineLength': readableLineLength,
      'defaultViewMode': defaultViewMode,
      'fontSize': fontSize,
      'explorerSort': explorerSort,
      'dailyNotes': dailyNotes,
      'templates': templates,
      'corePlugins': corePlugins,
      'editor': editor,
      'importedFromObsidian': importedFromObsidian,
      'newLinkFormat': newLinkFormat,
      'useMarkdownLinks': useMarkdownLinks,
      'alwaysUpdateLinks': alwaysUpdateLinks,
      'excludedFolders': excludedFolders,
    };
    map.addAll(extra);
    return map;
  }

  VaultSettings copyWith({
    String? attachmentFolder,
    String? newFileLocation,
    String? newFileFolder,
    String? trashMode,
    bool? showHidden,
    bool? useTab,
    int? tabSize,
    bool? readableLineLength,
    String? defaultViewMode,
    double? fontSize,
    String? explorerSort,
    Map<String, Object?>? dailyNotes,
    Map<String, Object?>? templates,
    Map<String, Object?>? corePlugins,
    Map<String, Object?>? editor,
    bool? importedFromObsidian,
    String? newLinkFormat,
    bool? useMarkdownLinks,
    bool? alwaysUpdateLinks,
    List<String>? excludedFolders,
    Map<String, Object?>? extra,
  }) {
    return VaultSettings(
      attachmentFolder: attachmentFolder ?? this.attachmentFolder,
      newFileLocation: newFileLocation ?? this.newFileLocation,
      newFileFolder: newFileFolder ?? this.newFileFolder,
      trashMode: trashMode ?? this.trashMode,
      showHidden: showHidden ?? this.showHidden,
      useTab: useTab ?? this.useTab,
      tabSize: tabSize ?? this.tabSize,
      readableLineLength: readableLineLength ?? this.readableLineLength,
      defaultViewMode: defaultViewMode ?? this.defaultViewMode,
      fontSize: fontSize ?? this.fontSize,
      explorerSort: explorerSort ?? this.explorerSort,
      dailyNotes: dailyNotes ?? this.dailyNotes,
      templates: templates ?? this.templates,
      corePlugins: corePlugins ?? this.corePlugins,
      editor: editor ?? this.editor,
      importedFromObsidian: importedFromObsidian ?? this.importedFromObsidian,
      newLinkFormat: newLinkFormat ?? this.newLinkFormat,
      useMarkdownLinks: useMarkdownLinks ?? this.useMarkdownLinks,
      alwaysUpdateLinks: alwaysUpdateLinks ?? this.alwaysUpdateLinks,
      excludedFolders: excludedFolders ?? this.excludedFolders,
      extra: extra ?? this.extra,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultSettings &&
          attachmentFolder == other.attachmentFolder &&
          newFileLocation == other.newFileLocation &&
          newFileFolder == other.newFileFolder &&
          trashMode == other.trashMode &&
          showHidden == other.showHidden &&
          useTab == other.useTab &&
          tabSize == other.tabSize &&
          readableLineLength == other.readableLineLength &&
          defaultViewMode == other.defaultViewMode &&
          fontSize == other.fontSize &&
          explorerSort == other.explorerSort &&
          mapEquals(dailyNotes, other.dailyNotes) &&
          mapEquals(templates, other.templates) &&
          mapEquals(corePlugins, other.corePlugins) &&
          mapEquals(editor, other.editor) &&
          importedFromObsidian == other.importedFromObsidian &&
          newLinkFormat == other.newLinkFormat &&
          useMarkdownLinks == other.useMarkdownLinks &&
          alwaysUpdateLinks == other.alwaysUpdateLinks &&
          listEquals(excludedFolders, other.excludedFolders) &&
          mapEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll([
    attachmentFolder,
    newFileLocation,
    newFileFolder,
    trashMode,
    showHidden,
    useTab,
    tabSize,
    readableLineLength,
    defaultViewMode,
    fontSize,
    explorerSort,
    Object.hashAll(dailyNotes.entries),
    Object.hashAll(templates.entries),
    Object.hashAll(corePlugins.entries),
    Object.hashAll(editor.entries),
    importedFromObsidian,
    newLinkFormat,
    useMarkdownLinks,
    alwaysUpdateLinks,
    Object.hashAll(excludedFolders),
    Object.hashAll(extra.entries),
  ]);
}
