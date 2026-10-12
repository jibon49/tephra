// © 2026 Tephra. All rights reserved.

import 'exceptions.dart';

/// A normalized, relative path within a vault.
///
/// Paths use `/` as separator, have no leading or trailing slashes,
/// collapse consecutive slashes, and resolve `.` and `..` segments.
/// Root is represented by [VaultPath.root] with an empty [value].
///
/// Note: No Unicode normalization is performed; `Café` (NFC) and `Café` (NFD)
/// are preserved as distinct paths.
final class VaultPath implements Comparable<VaultPath> {
  const VaultPath._(this.value);

  /// Creates a normalized [VaultPath] from [raw].
  ///
  /// Throws [InvalidPathException] if [raw] is empty, escapes root via `..`,
  /// or contains invalid path segments.
  factory VaultPath(String raw) {
    final normalized = raw.replaceAll(r'\', '/');
    final segments = normalized.split('/');
    final stack = <String>[];

    for (final seg in segments) {
      if (seg.isEmpty || seg == '.') {
        continue;
      }
      if (seg == '..') {
        if (stack.isEmpty) {
          throw InvalidPathException('Path escapes the vault root: $raw');
        }
        stack.removeLast();
      } else {
        final err = _segmentError(seg);
        if (err != null) {
          throw InvalidPathException('$err: $raw');
        }
        stack.add(seg);
      }
    }

    if (stack.isEmpty) {
      throw InvalidPathException('Empty path: $raw');
    }

    return VaultPath._(stack.join('/'));
  }

  /// The root folder of the vault.
  static const VaultPath root = VaultPath._('');

  /// The normalized relative path string (e.g. `'folder/note.md'`).
  final String value;

  /// The file or directory name after the last `/`, or `''` for root.
  String get name {
    if (isRoot) return '';
    final slash = value.lastIndexOf('/');
    return slash == -1 ? value : value.substring(slash + 1);
  }

  /// The filename without its last extension.
  ///
  /// If the only dot in [name] is at index 0 (e.g. `'.hidden'`), [stem] equals
  /// [name] and [extension] is empty.
  String get stem {
    if (isRoot) return '';
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return name.substring(0, dot);
  }

  /// Lower-case extension without leading dot, or `''` if none.
  String get extension {
    if (isRoot) return '';
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// The parent directory path, or `null` if this is [root].
  ///
  /// Top-level entries have [root] as their parent.
  VaultPath? get parent {
    if (isRoot) return null;
    final slash = value.lastIndexOf('/');
    if (slash == -1) return root;
    return VaultPath._(value.substring(0, slash));
  }

  /// Lower-case path for case-insensitive lookup.
  String get caseKey => value.toLowerCase();

  /// Whether this path has a `.md` extension.
  bool get isMarkdown => extension == 'md';

  /// Whether this is the root folder.
  bool get isRoot => value.isEmpty;

  /// Joins [child] relative to this directory.
  VaultPath join(String child) => VaultPath(isRoot ? child : '$value/$child');

  /// Returns a new path with the same parent but [newName] as its filename.
  VaultPath withName(String newName) {
    if (isRoot) {
      throw const InvalidPathException('Cannot set name on root');
    }
    if (newName.contains('/') || newName.contains(r'\')) {
      throw InvalidPathException('separator: $newName');
    }
    final err = _segmentError(newName);
    if (err != null) {
      throw InvalidPathException('$err: $newName');
    }
    final p = parent!;
    return p.isRoot ? VaultPath._(newName) : VaultPath._('${p.value}/$newName');
  }

  /// Returns whether this path is located inside [folder].
  ///
  /// A path is never within itself.
  bool isWithin(VaultPath folder) =>
      folder.isRoot ? !isRoot : value.startsWith('${folder.value}/');

  @override
  int compareTo(VaultPath other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is VaultPath && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  /// Tries to parse [raw] into a [VaultPath], returning `null` if invalid.
  static VaultPath? tryParse(String raw) {
    try {
      return VaultPath(raw);
    } on InvalidPathException {
      return null;
    }
  }

  /// Validates a single path segment name, returning an error code or `null`.
  static String? checkName(String name) {
    if (name.isEmpty) return 'empty';
    if (name.contains('/') || name.contains(r'\')) return 'separator';
    return _segmentError(name);
  }

  static String? _segmentError(String s) {
    for (var i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if (code == 0) return 'nul';
      if (code < 0x20) return 'control';
    }
    const invalidChars = {'<', '>', ':', '"', '|', '?', '*'};
    for (var i = 0; i < s.length; i++) {
      if (invalidChars.contains(s[i])) return 'invalid-char';
    }
    if (s.endsWith('.') || s.endsWith(' ')) {
      return 'trailing-dot-or-space';
    }
    final dot = s.indexOf('.');
    final base = (dot == -1 ? s : s.substring(0, dot)).toUpperCase();
    const reserved = {
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    };
    if (reserved.contains(base)) {
      return 'reserved-name';
    }
    if (s.length > 255) {
      return 'too-long';
    }
    return null;
  }
}
