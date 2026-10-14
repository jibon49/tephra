// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Sealed base class for bookmarks matching Obsidian's `bookmarks.json` structure.
sealed class Bookmark {
  const Bookmark();

  int get ctime;
  String? get title;
  Map<String, Object?> get extra;

  Map<String, Object?> toJson();

  static Bookmark fromJson(Map<String, Object?> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'file':
        return FileBookmark.fromJson(json);
      case 'folder':
        return FolderBookmark.fromJson(json);
      case 'search':
        return SearchBookmark.fromJson(json);
      case 'group':
        return GroupBookmark.fromJson(json);
      default:
        return UnknownBookmark.fromJson(json);
    }
  }
}

/// A bookmark referencing a vault file, optionally with a subpath (#Heading or #^id).
final class FileBookmark extends Bookmark {
  const FileBookmark({
    required this.ctime,
    required this.path,
    this.title,
    this.subpath,
    this.extra = const {},
  });

  @override
  final int ctime;

  @override
  final String? title;

  final VaultPath path;
  final String? subpath;

  @override
  final Map<String, Object?> extra;

  FileBookmark copyWith({
    int? ctime,
    String? title,
    VaultPath? path,
    String? subpath,
    Map<String, Object?>? extra,
  }) => FileBookmark(
    ctime: ctime ?? this.ctime,
    title: title ?? this.title,
    path: path ?? this.path,
    subpath: subpath ?? this.subpath,
    extra: extra ?? this.extra,
  );

  @override
  Map<String, Object?> toJson() => {
    'type': 'file',
    'ctime': ctime,
    'path': path.value,
    if (subpath != null) 'subpath': subpath,
    if (title != null) 'title': title,
    ...extra,
  };

  static Bookmark fromJson(Map<String, Object?> json) {
    final rawPath = json['path'] as String?;
    if (rawPath == null) return UnknownBookmark.fromJson(json);

    final ctime = (json['ctime'] as num?)?.toInt() ?? 0;
    final title = json['title'] as String?;
    final subpath = json['subpath'] as String?;
    final extra = Map<String, Object?>.from(json)
      ..remove('type')
      ..remove('ctime')
      ..remove('title')
      ..remove('path')
      ..remove('subpath');

    return FileBookmark(
      ctime: ctime,
      title: title,
      path: VaultPath(rawPath),
      subpath: subpath,
      extra: extra,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileBookmark &&
          other.ctime == ctime &&
          other.title == title &&
          other.path == path &&
          other.subpath == subpath;

  @override
  int get hashCode => Object.hash(ctime, title, path, subpath);
}

/// A bookmark referencing a vault folder.
final class FolderBookmark extends Bookmark {
  const FolderBookmark({
    required this.ctime,
    required this.path,
    this.title,
    this.extra = const {},
  });

  @override
  final int ctime;

  @override
  final String? title;

  final VaultPath path;

  @override
  final Map<String, Object?> extra;

  FolderBookmark copyWith({
    int? ctime,
    String? title,
    VaultPath? path,
    Map<String, Object?>? extra,
  }) => FolderBookmark(
    ctime: ctime ?? this.ctime,
    title: title ?? this.title,
    path: path ?? this.path,
    extra: extra ?? this.extra,
  );

  @override
  Map<String, Object?> toJson() => {
    'type': 'folder',
    'ctime': ctime,
    if (title != null) 'title': title,
    'path': path.value,
    ...extra,
  };

  static Bookmark fromJson(Map<String, Object?> json) {
    final rawPath = json['path'] as String?;
    if (rawPath == null) return UnknownBookmark.fromJson(json);

    final ctime = (json['ctime'] as num?)?.toInt() ?? 0;
    final title = json['title'] as String?;
    final extra = Map<String, Object?>.from(json)
      ..remove('type')
      ..remove('ctime')
      ..remove('title')
      ..remove('path');

    return FolderBookmark(
      ctime: ctime,
      title: title,
      path: VaultPath(rawPath),
      extra: extra,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderBookmark &&
          other.ctime == ctime &&
          other.title == title &&
          other.path == path;

  @override
  int get hashCode => Object.hash(ctime, title, path);
}

/// A bookmark storing a search query.
final class SearchBookmark extends Bookmark {
  const SearchBookmark({
    required this.ctime,
    required this.query,
    this.title,
    this.extra = const {},
  });

  @override
  final int ctime;

  @override
  final String? title;

  final String query;

  @override
  final Map<String, Object?> extra;

  SearchBookmark copyWith({
    int? ctime,
    String? title,
    String? query,
    Map<String, Object?>? extra,
  }) => SearchBookmark(
    ctime: ctime ?? this.ctime,
    title: title ?? this.title,
    query: query ?? this.query,
    extra: extra ?? this.extra,
  );

  @override
  Map<String, Object?> toJson() => {
    'type': 'search',
    'ctime': ctime,
    if (title != null) 'title': title,
    'query': query,
    ...extra,
  };

  static Bookmark fromJson(Map<String, Object?> json) {
    final ctime = (json['ctime'] as num?)?.toInt() ?? 0;
    final title = json['title'] as String?;
    final query = json['query'] as String? ?? '';
    final extra = Map<String, Object?>.from(json)
      ..remove('type')
      ..remove('ctime')
      ..remove('title')
      ..remove('query');

    return SearchBookmark(
      ctime: ctime,
      title: title,
      query: query,
      extra: extra,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchBookmark &&
          other.ctime == ctime &&
          other.title == title &&
          other.query == query;

  @override
  int get hashCode => Object.hash(ctime, title, query);
}

/// A folder-like grouping of bookmarks.
final class GroupBookmark extends Bookmark {
  const GroupBookmark({
    required this.ctime,
    required this.items,
    this.title,
    this.extra = const {},
  });

  @override
  final int ctime;

  @override
  final String? title;

  final List<Bookmark> items;

  @override
  final Map<String, Object?> extra;

  GroupBookmark copyWith({
    int? ctime,
    String? title,
    List<Bookmark>? items,
    Map<String, Object?>? extra,
  }) => GroupBookmark(
    ctime: ctime ?? this.ctime,
    title: title ?? this.title,
    items: items ?? this.items,
    extra: extra ?? this.extra,
  );

  @override
  Map<String, Object?> toJson() => {
    'type': 'group',
    'ctime': ctime,
    if (title != null) 'title': title,
    'items': items.map((i) => i.toJson()).toList(),
    ...extra,
  };

  static Bookmark fromJson(Map<String, Object?> json) {
    final ctime = (json['ctime'] as num?)?.toInt() ?? 0;
    final title = json['title'] as String?;
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = <Bookmark>[];
    for (final item in rawItems) {
      if (item is Map) {
        items.add(Bookmark.fromJson(Map<String, Object?>.from(item)));
      }
    }
    final extra = Map<String, Object?>.from(json)
      ..remove('type')
      ..remove('ctime')
      ..remove('title')
      ..remove('items');

    return GroupBookmark(
      ctime: ctime,
      title: title,
      items: items,
      extra: extra,
    );
  }
}

/// A bookmark with an unrecognized type (e.g. 'graph', 'url'), preserved as-is.
final class UnknownBookmark extends Bookmark {
  const UnknownBookmark({required this.raw});

  final Map<String, Object?> raw;

  @override
  int get ctime => (raw['ctime'] as num?)?.toInt() ?? 0;

  @override
  String? get title => raw['title'] as String?;

  @override
  Map<String, Object?> get extra {
    final copy = Map<String, Object?>.from(raw)
      ..remove('type')
      ..remove('ctime')
      ..remove('title');
    return copy;
  }

  UnknownBookmark copyWith({Map<String, Object?>? raw}) =>
      UnknownBookmark(raw: raw ?? this.raw);

  @override
  Map<String, Object?> toJson() => Map<String, Object?>.from(raw);

  static UnknownBookmark fromJson(Map<String, Object?> json) =>
      UnknownBookmark(raw: Map<String, Object?>.from(json));
}

/// Represents the top-level document of `.tephra/bookmarks.json`.
final class BookmarksDocument {
  const BookmarksDocument({required this.items, this.extra = const {}});

  final List<Bookmark> items;
  final Map<String, Object?> extra;

  BookmarksDocument copyWith({
    List<Bookmark>? items,
    Map<String, Object?>? extra,
  }) =>
      BookmarksDocument(items: items ?? this.items, extra: extra ?? this.extra);

  Map<String, Object?> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    ...extra,
  };

  static BookmarksDocument fromJson(Map<String, Object?> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = <Bookmark>[];
    for (final item in rawItems) {
      if (item is Map) {
        items.add(Bookmark.fromJson(Map<String, Object?>.from(item)));
      }
    }
    final extra = Map<String, Object?>.from(json)..remove('items');
    return BookmarksDocument(items: items, extra: extra);
  }
}
