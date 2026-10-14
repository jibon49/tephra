// © 2026 Tephra. All rights reserved.

import '../model/link_record.dart';

/// Extracted heading record before database insertion.
final class ExtractedHeading {
  const ExtractedHeading({
    required this.level,
    required this.text,
    required this.key,
    required this.start,
    required this.end,
    required this.line,
    required this.ordinal,
  });

  final int level;
  final String text;
  final String key;
  final int start;
  final int end;
  final int line;
  final int ordinal;
}

/// Extracted block identifier record before database insertion.
final class ExtractedBlock {
  const ExtractedBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.line,
    required this.preview,
  });

  final String id;
  final int start;
  final int end;
  final int line;
  final String preview;
}

/// Extracted link or embed record before database resolution.
final class ExtractedLink {
  const ExtractedLink({
    required this.targetRaw,
    required this.targetKey,
    required this.kind,
    required this.syntax,
    this.heading,
    this.blockRef,
    this.alias,
    this.embedSize,
    required this.start,
    required this.end,
    required this.line,
  });

  final String targetRaw;
  final String targetKey;
  final LinkKind kind;
  final LinkSyntax syntax;
  final String? heading;
  final String? blockRef;
  final String? alias;
  final String? embedSize;
  final int start;
  final int end;
  final int line;
}

/// Extracted tag record before database insertion.
final class ExtractedTag {
  const ExtractedTag({required this.tag, this.start, this.line});

  final String tag;
  final int? start;
  final int? line;
}

/// Extracted frontmatter property record.
final class ExtractedProperty {
  const ExtractedProperty({
    required this.key,
    required this.valueType,
    required this.ordinal,
    this.valueText,
    this.valueNum,
    this.valueBool,
    this.valueDate,
  });

  final String key;
  final String valueType;
  final int ordinal;
  final String? valueText;
  final double? valueNum;
  final bool? valueBool;
  final String? valueDate;

  String get keyLower => key.toLowerCase();
  String? get valueLower => valueText?.toLowerCase();
}

/// Extracted task checklist item record.
final class ExtractedTask {
  const ExtractedTask({
    required this.line,
    required this.statusChar,
    required this.text,
    required this.start,
    required this.end,
    this.due,
  });

  final int line;
  final String statusChar;
  final String text;
  final int start;
  final int end;
  final String? due;
}

/// Complete extracted entities from a single parsed note.
final class ExtractedNote {
  const ExtractedNote({
    required this.title,
    required this.frontmatterJson,
    required this.frontmatterValid,
    required this.wordCount,
    required this.aliases,
    required this.headings,
    required this.blocks,
    required this.links,
    required this.tags,
    required this.properties,
    required this.tasks,
    required this.ftsName,
    required this.ftsBody,
  });

  final String title;
  final String frontmatterJson;
  final bool frontmatterValid;
  final int wordCount;
  final List<String> aliases;
  final List<ExtractedHeading> headings;
  final List<ExtractedBlock> blocks;
  final List<ExtractedLink> links;
  final List<ExtractedTag> tags;
  final List<ExtractedProperty> properties;
  final List<ExtractedTask> tasks;
  final String ftsName;
  final String ftsBody;
}
