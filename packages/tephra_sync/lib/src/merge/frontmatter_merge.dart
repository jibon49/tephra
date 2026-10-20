// © 2026 Tephra. All rights reserved.

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'three_way_merge.dart';

class _FrontmatterSplit {
  const _FrontmatterSplit({
    required this.hasFrontmatter,
    required this.yamlText,
    required this.bodyText,
  });

  final bool hasFrontmatter;
  final String yamlText;
  final String bodyText;
}

/// Splits text into YAML frontmatter and Markdown body according to conventions §6.4.
_FrontmatterSplit _splitFrontmatter(String text) {
  final firstNewline = text.indexOf('\n');
  if (firstNewline == -1) {
    return _FrontmatterSplit(
      hasFrontmatter: false,
      yamlText: '',
      bodyText: text,
    );
  }

  final firstLine = text.substring(0, firstNewline).trimRight();
  if (firstLine != '---') {
    return _FrontmatterSplit(
      hasFrontmatter: false,
      yamlText: '',
      bodyText: text,
    );
  }

  var pos = firstNewline + 1;
  while (pos <= text.length) {
    final nextNewline = text.indexOf('\n', pos);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final line = text.substring(pos, lineEnd).trimRight();

    if (line == '---') {
      final yaml = text.substring(firstNewline + 1, pos);
      final body = nextNewline == -1 ? '' : text.substring(nextNewline + 1);
      return _FrontmatterSplit(
        hasFrontmatter: true,
        yamlText: yaml,
        bodyText: body,
      );
    }

    if (nextNewline == -1) break;
    pos = nextNewline + 1;
  }

  return _FrontmatterSplit(hasFrontmatter: false, yamlText: '', bodyText: text);
}

Map<String, Object?>? _parseYamlMap(String yamlText) {
  if (yamlText.trim().isEmpty) {
    return <String, Object?>{};
  }
  try {
    final doc = loadYaml(yamlText);
    if (doc == null) return <String, Object?>{};
    if (doc is YamlMap) {
      final map = <String, Object?>{};
      for (final entry in doc.entries) {
        map[entry.key.toString()] = entry.value;
      }
      return map;
    }
    return null;
  } catch (_) {
    return null;
  }
}

bool _deepYamlEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepYamlEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepYamlEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Performs a frontmatter-aware three-way merge on Markdown documents.
///
/// Falls back to plain [merge3] if any document has malformed YAML or non-map frontmatter.
MergeOutcome mergeMarkdown(String base, String local, String remote) {
  final baseSplit = _splitFrontmatter(base);
  final localSplit = _splitFrontmatter(local);
  final remoteSplit = _splitFrontmatter(remote);

  // If none have frontmatter, run standard merge3
  if (!baseSplit.hasFrontmatter &&
      !localSplit.hasFrontmatter &&
      !remoteSplit.hasFrontmatter) {
    return merge3(base, local, remote);
  }

  final baseMap = _parseYamlMap(baseSplit.yamlText);
  final localMap = _parseYamlMap(localSplit.yamlText);
  final remoteMap = _parseYamlMap(remoteSplit.yamlText);

  // If any frontmatter is invalid or not a map, fall back to plain merge3
  if (baseMap == null || localMap == null || remoteMap == null) {
    return merge3(base, local, remote);
  }

  final allKeys = <String>{
    ...baseMap.keys,
    ...localMap.keys,
    ...remoteMap.keys,
  };

  final remoteKeysToUpdate = <String, Object?>{};
  final remoteKeysToRemove = <String>{};
  var frontmatterChanged = false;

  for (final key in allKeys) {
    final inBase = baseMap.containsKey(key);
    final inLocal = localMap.containsKey(key);
    final inRemote = remoteMap.containsKey(key);

    final baseVal = baseMap[key];
    final localVal = localMap[key];
    final remoteVal = remoteMap[key];

    final localSameAsBase =
        inLocal == inBase && _deepYamlEquals(localVal, baseVal);
    final remoteSameAsBase =
        inRemote == inBase && _deepYamlEquals(remoteVal, baseVal);

    if (localSameAsBase && remoteSameAsBase) {
      continue;
    }

    frontmatterChanged = true;

    if (localSameAsBase) {
      // Remote changed, local unchanged -> take remote
      if (inRemote) {
        remoteKeysToUpdate[key] = remoteVal;
      } else {
        remoteKeysToRemove.add(key);
      }
    } else if (remoteSameAsBase) {
      // Local changed, remote unchanged -> keep local
      continue;
    } else {
      // Both sides changed
      if (inLocal == inRemote && _deepYamlEquals(localVal, remoteVal)) {
        // Changed identically
        continue;
      } else {
        // Conflicting changes on the same key
        return const MergeOutcome.conflict();
      }
    }
  }

  // Merge bodies using three-way line merge
  final bodyOutcome = merge3(
    baseSplit.bodyText,
    localSplit.bodyText,
    remoteSplit.bodyText,
  );
  if (!bodyOutcome.isClean || bodyOutcome.text == null) {
    return const MergeOutcome.conflict();
  }

  // If no side changed the frontmatter, keep local frontmatter byte-for-byte
  if (!frontmatterChanged) {
    if (!localSplit.hasFrontmatter) {
      return MergeOutcome.clean(bodyOutcome.text!);
    }
    final mergedText = '---\n${localSplit.yamlText}---\n${bodyOutcome.text!}';
    return MergeOutcome.clean(mergedText);
  }

  // Apply remote changes on top of local frontmatter
  if (!localSplit.hasFrontmatter) {
    // Local had no frontmatter; use remote frontmatter directly if clean
    if (!remoteSplit.hasFrontmatter || remoteMap.isEmpty) {
      return MergeOutcome.clean(bodyOutcome.text!);
    }
    final mergedText = '---\n${remoteSplit.yamlText}---\n${bodyOutcome.text!}';
    return MergeOutcome.clean(mergedText);
  }

  // Local has frontmatter: use YamlEditor to preserve local comments & formatting
  try {
    final editor = YamlEditor(localSplit.yamlText);
    for (final key in remoteKeysToRemove) {
      try {
        editor.remove([key]);
      } catch (_) {}
    }
    for (final entry in remoteKeysToUpdate.entries) {
      try {
        editor.update([entry.key], entry.value);
      } catch (_) {}
    }

    final mergedYaml = editor.toString();
    final trailing = mergedYaml.endsWith('\n') ? '' : '\n';
    final mergedText = '---\n$mergedYaml$trailing---\n${bodyOutcome.text!}';
    return MergeOutcome.clean(mergedText);
  } catch (_) {
    // If YamlEditor fails to update, fall back to plain merge3
    return merge3(base, local, remote);
  }
}
