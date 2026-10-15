// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../editor/live_preview/editing_mode.dart';

sealed class TabContent {
  const TabContent();

  Map<String, Object?> toJson();

  static TabContent? fromJson(Map<String, Object?> j) {
    final kind = j['kind'] as String?;
    if (kind == null || kind == 'file') {
      final pathStr = j['path'] as String?;
      if (pathStr == null) return null;
      final path = VaultPath.tryParse(pathStr);
      if (path == null) return null;
      final subpath = j['subpath'] as String?;
      final modeStr = j['mode'] as String?;
      final editingMode = modeStr == 'source'
          ? EditingMode.source
          : EditingMode.livePreview;
      return FileTabContent(path, subpath: subpath, editingMode: editingMode);
    }
    return null;
  }
}

final class FileTabContent extends TabContent {
  const FileTabContent(
    this.path, {
    this.subpath,
    this.editingMode = EditingMode.livePreview,
  });

  final VaultPath path;
  final String? subpath;
  final EditingMode editingMode;

  FileTabContent copyWith({
    VaultPath? path,
    String? subpath,
    EditingMode? editingMode,
  }) => FileTabContent(
    path ?? this.path,
    subpath: subpath ?? this.subpath,
    editingMode: editingMode ?? this.editingMode,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'file',
    'path': path.value,
    if (subpath != null) 'subpath': subpath,
    'mode': editingMode.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTabContent &&
          other.runtimeType == runtimeType &&
          other.path == path &&
          other.subpath == subpath &&
          other.editingMode == editingMode;

  @override
  int get hashCode => Object.hash(path, subpath, editingMode);

  @override
  String toString() =>
      'FileTabContent(path: $path, subpath: $subpath, mode: $editingMode)';
}
