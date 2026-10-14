// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../model/link_record.dart';
import 'link_format_settings.dart';
import 'link_resolver.dart';
import 'name_table.dart';

/// Builds link strings conforming to vault link format settings.
final class LinkFormatter {
  const LinkFormatter(this.lookup, this.settings);

  final LinkTargetLookup lookup;
  final LinkFormatSettings settings;

  /// Link path text (no brackets) from [from] to [target] for [syntax].
  String linkPath(
    VaultPath target, {
    required VaultPath from,
    required LinkSyntax syntax,
  }) {
    String name(VaultPath p) =>
        syntax == LinkSyntax.wiki && p.isMarkdown ? p.stem : p.name;

    String full(VaultPath p) {
      if (syntax == LinkSyntax.wiki && p.isMarkdown) {
        if (p.value.toLowerCase().endsWith('.md')) {
          return p.value.substring(0, p.value.length - 3);
        }
      }
      return p.value;
    }

    final String rawPath;
    switch (settings.format) {
      case NewLinkFormat.absolute:
        rawPath = full(target);
      case NewLinkFormat.relative:
        if (from.parent == target.parent) {
          rawPath = name(target);
        } else {
          List<String> folderSegments(VaultPath? p) =>
              (p == null || p.isRoot) ? const <String>[] : p.value.split('/');
          final fromFolder = folderSegments(from.parent);
          final targetFolder = folderSegments(target.parent);
          var common = 0;
          while (common < fromFolder.length &&
              common < targetFolder.length &&
              fromFolder[common] == targetFolder[common]) {
            common++;
          }
          final upCount = fromFolder.length - common;
          final parts = <String>[
            for (var i = 0; i < upCount; i++) '..',
            ...targetFolder.sublist(common),
            name(target),
          ];
          rawPath = parts.join('/');
        }
      case NewLinkFormat.shortest:
        final bare = name(target);
        final resolved = LinkResolver(lookup)
            .resolve(decodeMarkdownPath(bare), from: from);
        if (resolved != null && resolved.path == target && !resolved.viaAlias) {
          rawPath = bare;
        } else {
          rawPath = full(target);
        }
    }

    if (syntax == LinkSyntax.markdown) {
      return encodeMarkdownPath(rawPath);
    }
    return rawPath;
  }

  /// Complete new link in the syntax chosen by settings.useMarkdownLinks.
  String buildLink(
    VaultPath target, {
    required VaultPath from,
    String? heading,
    String? blockRef,
    String? alias,
    bool embed = false,
    String? embedSize,
  }) {
    final subpath = heading != null
        ? '#${sanitizeHeadingForLink(heading)}'
        : blockRef != null
        ? '#^$blockRef'
        : '';

    if (settings.useMarkdownLinks) {
      final linkText = alias ?? target.stem;
      final path = linkPath(target, from: from, syntax: LinkSyntax.markdown);
      final String encodedSubpath;
      if (subpath.startsWith('#')) {
        encodedSubpath = '#${encodeMarkdownPath(subpath.substring(1))}';
      } else {
        encodedSubpath = '';
      }
      final prefix = embed ? '!' : '';
      return '$prefix[$linkText]($path$encodedSubpath)';
    } else {
      final path = linkPath(target, from: from, syntax: LinkSyntax.wiki);
      final nameTarget = target.isMarkdown ? target.stem : target.name;
      final aliasPart = (alias != null && alias != nameTarget) ? '|$alias' : '';
      final embedSizePart = embedSize != null ? '|$embedSize' : '';
      final prefix = embed ? '!' : '';
      return '$prefix[[$path$subpath$aliasPart$embedSizePart]]';
    }
  }

  static const _toEncode = {
    0x20: '%20', // space
    0x25: '%25', // %
    0x28: '%28', // (
    0x29: '%29', // )
    0x5B: '%5B', // [
    0x5D: '%5D', // ]
    0x3C: '%3C', // <
    0x3E: '%3E', // >
    0x23: '%23', // #
    0x5E: '%5E', // ^
    0x7C: '%7C', // |
    0x3F: '%3F', // ?
    0x60: '%60', // `
    0x22: '%22', // "
    0x5C: '%5C', // \
    0x7B: '%7B', // {
    0x7D: '%7D', // }
  };

  /// Encodes Markdown path characters with percent-encoding.
  static String encodeMarkdownPath(String path) {
    final buffer = StringBuffer();
    for (var i = 0; i < path.length; i++) {
      final charCode = path.codeUnitAt(i);
      final encoded = _toEncode[charCode];
      if (encoded != null) {
        buffer.write(encoded);
      } else {
        buffer.writeCharCode(charCode);
      }
    }
    return buffer.toString();
  }

  /// Decodes a Markdown path with Uri.decodeComponent fallback.
  static String decodeMarkdownPath(String path) {
    try {
      return Uri.decodeComponent(path);
    } on ArgumentError {
      return path;
    } on FormatException {
      return path;
    }
  }

  /// Sanitizes heading text for use in a link subpath.
  static String sanitizeHeadingForLink(String heading) {
    var s = heading.replaceAll('%%', '');
    s = s.replaceAll(RegExp(r'[\[\]\|#\^\\]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }
}
