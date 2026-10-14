// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

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
      return FileTabContent(path, subpath: subpath);
    }
    return null;
  }
}

final class FileTabContent extends TabContent {
  const FileTabContent(this.path, {this.subpath});

  final VaultPath path;
  final String? subpath;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'file',
    'path': path.value,
    if (subpath != null) 'subpath': subpath,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTabContent &&
          other.runtimeType == runtimeType &&
          other.path == path &&
          other.subpath == subpath;

  @override
  int get hashCode => Object.hash(path, subpath);

  @override
  String toString() => 'FileTabContent(path: $path, subpath: $subpath)';
}
