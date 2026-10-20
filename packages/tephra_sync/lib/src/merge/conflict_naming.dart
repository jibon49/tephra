// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Sanitizes a device name for inclusion in conflict file names:
/// - removes `\ / : * ? " < > |` and control characters (code < 32)
/// - collapses consecutive whitespace into a single space
/// - trims leading and trailing whitespace
/// - limits length to at most 40 characters
/// - defaults to `'Device'` if empty
String sanitizeDeviceName(String deviceName) {
  var s = deviceName.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length > 40) {
    s = s.substring(0, 40).trim();
  }
  return s.isEmpty ? 'Device' : s;
}

/// Generates a deterministic conflict copy filename/path in the same folder as [path].
///
/// Format: `<stem> (conflict YYYY-MM-DD HH-mm <DeviceName>).<ext>`
/// Collisions increment an index inside the parentheses: `(... 2)`, `(... 3)`, etc.
/// Files without extension have no trailing dot.
String conflictCopyName(
  VaultPath path,
  DateTime localTime,
  String deviceName,
  bool Function(VaultPath) exists,
) {
  final cleanDevice = sanitizeDeviceName(deviceName);
  final year = localTime.year.toString().padLeft(4, '0');
  final month = localTime.month.toString().padLeft(2, '0');
  final day = localTime.day.toString().padLeft(2, '0');
  final hour = localTime.hour.toString().padLeft(2, '0');
  final minute = localTime.minute.toString().padLeft(2, '0');
  final timeStr = '$year-$month-$day $hour-$minute';

  final stem = path.stem;
  final ext = path.extension;
  final parent = path.parent;

  var counter = 1;
  while (true) {
    final suffix = counter == 1 ? '' : ' $counter';
    final tag = 'conflict $timeStr $cleanDevice$suffix';
    final fileName = ext.isEmpty ? '$stem ($tag)' : '$stem ($tag).$ext';

    final candidate = (parent == null || parent.isRoot)
        ? VaultPath(fileName)
        : parent.join(fileName);

    if (!exists(candidate)) {
      return candidate.value;
    }
    counter++;
  }
}

/// Generates a case-conflict copy filename/path in the same folder as [path].
///
/// Format: `<stem> (case conflict).<ext>`, then `(case conflict 2)`, etc.
/// Files without extension have no trailing dot.
String caseConflictName(VaultPath path, bool Function(VaultPath) exists) {
  final stem = path.stem;
  final ext = path.extension;
  final parent = path.parent;

  var counter = 1;
  while (true) {
    final suffix = counter == 1 ? '' : ' $counter';
    final tag = 'case conflict$suffix';
    final fileName = ext.isEmpty ? '$stem ($tag)' : '$stem ($tag).$ext';

    final candidate = (parent == null || parent.isRoot)
        ? VaultPath(fileName)
        : parent.join(fileName);

    if (!exists(candidate)) {
      return candidate.value;
    }
    counter++;
  }
}
