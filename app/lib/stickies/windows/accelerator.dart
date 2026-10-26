// © 2026 Tephra. All rights reserved.

/// Modifiers that can be used in an accelerator shortcut.
enum AcceleratorModifier { control, alt, shift, meta }

/// Pure Dart accelerator model representing a global key shortcut.
class Accelerator {
  const Accelerator({required this.modifiers, required this.key});

  /// Parses an accelerator string like `'Ctrl+Alt+N'`.
  ///
  /// Case-insensitive. Accepts modifiers: `Ctrl`, `Control`, `Alt`, `Shift`,
  /// `Win`, `Meta`, `Cmd`, `Command`, `Super`.
  /// Accepts primary keys: `A`–`Z`, `0`–`9`, `F1`–`F12`.
  /// Rejects combinations without at least one of Ctrl, Alt, or Win/Meta.
  /// Throws [FormatException] if input is invalid or unsupported.
  factory Accelerator.parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Accelerator string cannot be empty');
    }

    final rawTokens = trimmed.split('+').map((s) => s.trim()).toList();
    if (rawTokens.any((t) => t.isEmpty)) {
      throw FormatException('Invalid accelerator syntax: $input');
    }

    final parsedModifiers = <AcceleratorModifier>{};
    String? parsedKey;

    for (final rawToken in rawTokens) {
      final tokenLower = rawToken.toLowerCase();

      switch (tokenLower) {
        case 'ctrl':
        case 'control':
          parsedModifiers.add(AcceleratorModifier.control);
        case 'alt':
          parsedModifiers.add(AcceleratorModifier.alt);
        case 'shift':
          parsedModifiers.add(AcceleratorModifier.shift);
        case 'win':
        case 'meta':
        case 'cmd':
        case 'command':
        case 'super':
          parsedModifiers.add(AcceleratorModifier.meta);
        default:
          final normalizedKey = _normalizeKey(rawToken);
          if (normalizedKey == null) {
            throw FormatException('Unknown or invalid key: $rawToken');
          }
          if (parsedKey != null) {
            throw FormatException(
              'Multiple primary keys found: $parsedKey and $normalizedKey',
            );
          }
          parsedKey = normalizedKey;
      }
    }

    if (parsedKey == null) {
      throw FormatException('Missing primary key in accelerator: $input');
    }

    // Must have at least one of Ctrl, Alt, or Win/Meta
    final hasMainModifier =
        parsedModifiers.contains(AcceleratorModifier.control) ||
        parsedModifiers.contains(AcceleratorModifier.alt) ||
        parsedModifiers.contains(AcceleratorModifier.meta);

    if (!hasMainModifier) {
      throw FormatException(
        'Accelerator must include at least one of Ctrl, Alt, or Win/Meta: $input',
      );
    }

    return Accelerator(modifiers: parsedModifiers, key: parsedKey);
  }

  /// Modifiers pressed with the key.
  final Set<AcceleratorModifier> modifiers;

  /// Primary key in canonical uppercase (e.g. `'N'`, `'0'`, `'F5'`).
  final String key;

  bool get hasControl => modifiers.contains(AcceleratorModifier.control);
  bool get hasAlt => modifiers.contains(AcceleratorModifier.alt);
  bool get hasShift => modifiers.contains(AcceleratorModifier.shift);
  bool get hasMeta => modifiers.contains(AcceleratorModifier.meta);

  static String? _normalizeKey(String token) {
    final upper = token.toUpperCase();
    if (upper.length == 1) {
      final code = upper.codeUnitAt(0);
      // 'A'..'Z' (65..90)
      if (code >= 65 && code <= 90) return upper;
      // '0'..'9' (48..57)
      if (code >= 48 && code <= 57) return upper;
      return null;
    }

    // 'F1'..'F12'
    final fMatch = RegExp(r'^F([1-9]|1[0-2])$').hasMatch(upper);
    if (fMatch) return upper;

    return null;
  }

  /// Formats the accelerator into canonical representation (e.g. `Ctrl+Alt+N`).
  String format() {
    final parts = <String>[];
    if (hasControl) parts.add('Ctrl');
    if (hasAlt) parts.add('Alt');
    if (hasShift) parts.add('Shift');
    if (hasMeta) parts.add('Win');
    parts.add(key);
    return parts.join('+');
  }

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Accelerator &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          modifiers.length == other.modifiers.length &&
          modifiers.containsAll(other.modifiers);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(modifiers));
}
