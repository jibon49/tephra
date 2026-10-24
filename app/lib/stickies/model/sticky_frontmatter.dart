// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'sticky_color.dart';
import 'sticky_meta.dart';

/// An optional value container representing set, remove, or untouched states.
final class Optional<T> {
  const Optional.of(T this.value) : isPresent = true;
  const Optional.none() : value = null, isPresent = false;

  final T? value;
  final bool isPresent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Optional<T> &&
          isPresent == other.isPresent &&
          value == other.value;

  @override
  int get hashCode => Object.hash(isPresent, value);

  @override
  String toString() => isPresent ? 'Optional.of($value)' : 'Optional.none()';
}

/// A patch specifying modifications to sticky frontmatter keys.
final class StickyPatch {
  const StickyPatch({
    this.sticky,
    this.color,
    this.pinned,
    this.remind,
    this.expire,
    this.locked,
    this.removeAll = false,
  });

  /// true -> set 'tephra-sticky: true'; false -> remove key.
  final bool? sticky;

  /// New color to set.
  final StickyColor? color;

  /// true -> set true; false -> remove key (defaults are not stored).
  final bool? pinned;

  /// true -> set true; false -> remove key (defaults are not stored).
  final bool? locked;

  /// Optional.of(dt) -> set; Optional.none() -> remove; null -> untouched.
  final Optional<LocalDateTime>? remind;

  /// Optional.of(d) -> set; Optional.none() -> remove; null -> untouched.
  final Optional<LocalDate>? expire;

  /// If true, removes all six sticky keys (unpins the sticky note). Other fields ignored.
  final bool removeAll;
}

/// Applies [patch] to [noteText], preserving existing frontmatter and note body byte-for-byte.
String applyStickyPatch(String noteText, StickyPatch patch) {
  final split = splitFrontmatter(noteText);

  // 1. If there is no frontmatter
  if (split == null) {
    if (patch.removeAll) return noteText;

    // Check if patch only removes keys
    final isRemovalsOnly =
        (patch.sticky != true) &&
        (patch.color == null) &&
        (patch.pinned != true) &&
        (patch.locked != true) &&
        (patch.remind == null || !patch.remind!.isPresent) &&
        (patch.expire == null || !patch.expire!.isPresent);

    if (isRemovalsOnly) return noteText;

    // Build frontmatter lines in fixed order:
    // tephra-sticky, sticky-color, sticky-pinned, sticky-remind, sticky-expire, sticky-locked
    final buf = StringBuffer();
    if (patch.sticky == true) {
      buf.writeln('tephra-sticky: true');
    }
    if (patch.color != null) {
      final c = patch.color!;
      if (c is HexStickyColor) {
        buf.writeln("sticky-color: '${c.yamlValue}'");
      } else {
        buf.writeln('sticky-color: ${c.yamlValue}');
      }
    }
    if (patch.pinned == true) {
      buf.writeln('sticky-pinned: true');
    }
    if (patch.remind != null && patch.remind!.isPresent) {
      buf.writeln('sticky-remind: ${patch.remind!.value!.format()}');
    }
    if (patch.expire != null && patch.expire!.isPresent) {
      buf.writeln('sticky-expire: ${patch.expire!.value!.format()}');
    }
    if (patch.locked == true) {
      buf.writeln('sticky-locked: true');
    }

    final yaml = buf.toString();
    if (yaml.isEmpty) return noteText;
    return '---\n$yaml---\n$noteText';
  }

  // 2. Frontmatter exists
  final yamlText = split.yaml;

  if (yamlText.trim().isEmpty) {
    final isRemovalsOnly =
        patch.removeAll ||
        ((patch.sticky != true) &&
            (patch.color == null) &&
            (patch.pinned != true) &&
            (patch.locked != true) &&
            (patch.remind == null || !patch.remind!.isPresent) &&
            (patch.expire == null || !patch.expire!.isPresent));

    if (isRemovalsOnly) {
      return noteText.substring(split.bodyStart);
    }

    final buf = StringBuffer();
    if (patch.sticky == true) buf.writeln('tephra-sticky: true');
    if (patch.color != null) {
      final c = patch.color!;
      if (c is HexStickyColor) {
        buf.writeln("sticky-color: '${c.yamlValue}'");
      } else {
        buf.writeln('sticky-color: ${c.yamlValue}');
      }
    }
    if (patch.pinned == true) buf.writeln('sticky-pinned: true');
    if (patch.remind != null && patch.remind!.isPresent) {
      buf.writeln('sticky-remind: ${patch.remind!.value!.format()}');
    }
    if (patch.expire != null && patch.expire!.isPresent) {
      buf.writeln('sticky-expire: ${patch.expire!.value!.format()}');
    }
    if (patch.locked == true) buf.writeln('sticky-locked: true');

    final yaml = buf.toString();
    return '---\n$yaml---\n${noteText.substring(split.bodyStart)}';
  }

  final YamlEditor editor;
  try {
    editor = YamlEditor(yamlText);
    final node = editor.parseAt([]);
    if (node is! Map) {
      throw ParseException('frontmatter is not a map');
    }
  } catch (e) {
    if (e is ParseException) rethrow;
    throw ParseException('frontmatter is not a map: $e');
  }

  final rootMap = editor.parseAt([]) as Map;

  // Apply edits
  if (patch.removeAll || patch.sticky == false) {
    if (rootMap.containsKey('tephra-sticky')) editor.remove(['tephra-sticky']);
  } else if (patch.sticky == true) {
    editor.update(['tephra-sticky'], true);
  }

  if (patch.removeAll) {
    if (rootMap.containsKey('sticky-color')) editor.remove(['sticky-color']);
  } else if (patch.color != null) {
    editor.update(['sticky-color'], patch.color!.yamlValue);
  }

  if (patch.removeAll || patch.pinned == false) {
    if (rootMap.containsKey('sticky-pinned')) editor.remove(['sticky-pinned']);
  } else if (patch.pinned == true) {
    editor.update(['sticky-pinned'], true);
  }

  if (patch.removeAll || (patch.remind != null && !patch.remind!.isPresent)) {
    if (rootMap.containsKey('sticky-remind')) editor.remove(['sticky-remind']);
  } else if (patch.remind != null && patch.remind!.isPresent) {
    editor.update(['sticky-remind'], patch.remind!.value!.format());
  }

  if (patch.removeAll || (patch.expire != null && !patch.expire!.isPresent)) {
    if (rootMap.containsKey('sticky-expire')) editor.remove(['sticky-expire']);
  } else if (patch.expire != null && patch.expire!.isPresent) {
    editor.update(['sticky-expire'], patch.expire!.value!.format());
  }

  if (patch.removeAll || patch.locked == false) {
    if (rootMap.containsKey('sticky-locked')) editor.remove(['sticky-locked']);
  } else if (patch.locked == true) {
    editor.update(['sticky-locked'], true);
  }

  final newYaml = editor.toString();
  if (newYaml == yamlText) {
    return noteText;
  }

  final updatedRoot = editor.parseAt([]);
  if (updatedRoot is YamlMap &&
      updatedRoot.isEmpty &&
      (patch.removeAll || patch.sticky == false)) {
    // If all keys were removed, remove the frontmatter block entirely
    return noteText.substring(split.bodyStart);
  }

  final formattedYaml = newYaml.endsWith('\n') ? newYaml : '$newYaml\n';
  final closingLineStart = split.end - 3;
  return noteText.substring(0, split.contentStart) +
      formattedYaml +
      noteText.substring(closingLineStart);
}
