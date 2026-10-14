// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

sealed class VaultChange {
  const VaultChange(this.path);
  final VaultPath path;
}

final class FileCreated extends VaultChange {
  const FileCreated(super.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FileCreated && other.path == path);

  @override
  int get hashCode => Object.hash(runtimeType, path);

  @override
  String toString() => 'FileCreated($path)';
}

final class FileModified extends VaultChange {
  const FileModified(super.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FileModified && other.path == path);

  @override
  int get hashCode => Object.hash(runtimeType, path);

  @override
  String toString() => 'FileModified($path)';
}

final class FileDeleted extends VaultChange {
  const FileDeleted(super.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FileDeleted && other.path == path);

  @override
  int get hashCode => Object.hash(runtimeType, path);

  @override
  String toString() => 'FileDeleted($path)';
}

final class FileMoved extends VaultChange {
  const FileMoved(super.path, {required this.from});

  final VaultPath from;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileMoved && other.path == path && other.from == from);

  @override
  int get hashCode => Object.hash(runtimeType, path, from);

  @override
  String toString() => 'FileMoved($path, from: $from)';
}
