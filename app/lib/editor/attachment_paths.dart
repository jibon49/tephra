// © 2026 Tephra. All rights reserved.

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

final _logger = Logger('AttachmentPaths');

const _reservedNames = {
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

/// Resolves the attachment storage folder for [note] based on the vault [setting].
VaultPath attachmentFolderFor(VaultPath note, String setting) {
  final trimmed = setting.trim();
  final parent = note.parent ?? VaultPath.root;

  if (trimmed == '/' || trimmed.isEmpty) {
    return VaultPath.root;
  }
  if (trimmed == './') {
    return parent;
  }
  if (trimmed.startsWith('./')) {
    final sub = trimmed.substring(2).trim();
    if (sub.isEmpty) {
      return parent;
    }
    return parent.join(sub);
  }

  final parsed = VaultPath.tryParse(trimmed);
  if (parsed == null) {
    _logger.warning(
      'Invalid attachment folder setting "$setting", falling back to root',
    );
    return VaultPath.root;
  }
  return parsed;
}

/// Sanitizes a file name for safe filesystem and vault usage.
String sanitizeAttachmentName(String name) {
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final code = name.codeUnitAt(i);
    final ch = name[i];
    if (code < 0x20 ||
        ch == '<' ||
        ch == '>' ||
        ch == ':' ||
        ch == '"' ||
        ch == '|' ||
        ch == '?' ||
        ch == '*' ||
        ch == '/' ||
        ch == r'\') {
      buffer.write('_');
    } else {
      buffer.write(ch);
    }
  }

  var sanitized = buffer.toString();
  // Trim trailing dots and spaces
  while (sanitized.endsWith('.') || sanitized.endsWith(' ')) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }

  if (sanitized.isEmpty) {
    return 'attachment';
  }

  // Check if base is reserved
  final dotIdx = sanitized.indexOf('.');
  final base = (dotIdx == -1 ? sanitized : sanitized.substring(0, dotIdx))
      .toUpperCase();
  if (_reservedNames.contains(base)) {
    return 'attachment';
  }

  // Limit to 200 characters keeping the extension
  if (sanitized.length > 200) {
    final lastDot = sanitized.lastIndexOf('.');
    if (lastDot > 0 && lastDot < sanitized.length - 1) {
      final ext = sanitized.substring(lastDot);
      final maxStem = 200 - ext.length;
      if (maxStem > 0) {
        sanitized = '${sanitized.substring(0, maxStem)}$ext';
      } else {
        sanitized = sanitized.substring(0, 200);
      }
    } else {
      sanitized = sanitized.substring(0, 200);
    }
  }

  return sanitized;
}

/// Generates a timestamped default pasted image name in local time.
String pastedImageName(DateTime t, String ext) {
  final stamp = DateFormat('yyyyMMddHHmmss').format(t);
  final cleanExt = ext.startsWith('.') ? ext.substring(1) : ext;
  return 'Pasted image $stamp.$cleanExt';
}
