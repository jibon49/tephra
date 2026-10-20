// © 2026 Tephra. All rights reserved.

/// Utilities for validating and sanitizing file and directory segment names
/// on Windows filesystems.
final class WindowsNames {
  WindowsNames._();

  /// Regex pattern matching characters not allowed in Windows filenames:
  /// `< > : " / \ | ? *` and ASCII control characters (0x00 to 0x1F).
  static final RegExp invalidCharPattern = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Regex pattern matching trailing dots and spaces.
  static final RegExp trailingDotsSpacesPattern = RegExp(r'[. ]+$');

  /// Reserved device names in DOS/Windows.
  static const Set<String> reservedBaseNames = {
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

  /// Returns `true` if [segment] is a valid Windows filename/directory segment.
  static bool isValid(String segment) {
    if (segment.isEmpty) return false;

    // Check invalid characters (< > : " / \ | ? * or ASCII < 32)
    if (invalidCharPattern.hasMatch(segment)) return false;

    // Must not end with dot or space
    if (segment.endsWith('.') || segment.endsWith(' ')) return false;

    // Base name (before first dot) must not be a reserved device name
    final dotIdx = segment.indexOf('.');
    final baseName = (dotIdx == -1 ? segment : segment.substring(0, dotIdx))
        .toUpperCase();
    if (reservedBaseNames.contains(baseName)) return false;

    return true;
  }

  /// Sanitizes [segment] into a valid Windows filename:
  /// 1. Replaces each invalid character with `_`.
  /// 2. Replaces trailing dots and spaces with `_`.
  /// 3. Appends `_` to reserved base names.
  static String sanitize(String segment) {
    if (segment.isEmpty) return '_';

    // 1. Replace invalid characters with '_'
    var s = segment.replaceAll(invalidCharPattern, '_');

    // 2. Strip trailing dots/spaces (replace each with '_')
    final match = trailingDotsSpacesPattern.firstMatch(s);
    if (match != null) {
      final count = match.end - match.start;
      s = s.substring(0, match.start) + ('_' * count);
    }

    // 3. Append '_' to reserved base names
    final dotIdx = s.indexOf('.');
    final baseName = dotIdx == -1 ? s : s.substring(0, dotIdx);
    final rest = dotIdx == -1 ? '' : s.substring(dotIdx);

    if (reservedBaseNames.contains(baseName.toUpperCase())) {
      s = '${baseName}_$rest';
    }

    return s;
  }
}
