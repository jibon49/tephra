// © 2026 Tephra. All rights reserved.

import 'vault_path.dart';

abstract class TephraException implements Exception {
  const TephraException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class InvalidPathException extends TephraException {
  const InvalidPathException(super.message);
}

class FileNotFoundException extends TephraException {
  FileNotFoundException(this.path) : super('File not found: ${path.value}');
  final VaultPath path;
}

class FileConflictException extends TephraException {
  FileConflictException(this.path)
    : super('Target already exists: ${path.value}');
  final VaultPath path;
}

class PermissionDeniedException extends TephraException {
  const PermissionDeniedException(super.message);
}

class ParseException extends TephraException {
  const ParseException(super.message);
}

class SyncException extends TephraException {
  const SyncException(super.message);
}

class CryptoException extends TephraException {
  const CryptoException(super.message);
}
