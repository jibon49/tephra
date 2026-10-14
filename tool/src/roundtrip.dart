// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

final class RoundtripResult {
  const RoundtripResult({
    required this.vaultDir,
    required this.files,
    required this.notes,
    required this.unchanged,
    required this.mixed,
    required this.malformed,
    required this.changed,
    required this.parseErrors,
  });

  final String vaultDir;
  final int files;
  final int notes;
  final int unchanged;
  final int mixed;
  final int malformed;
  final int changed;
  final int parseErrors;

  bool get isSuccess => changed == 0 && parseErrors == 0;

  String toSummary() =>
      'vault=$vaultDir files=$files notes=$notes unchanged=$unchanged mixed=$mixed malformed=$malformed changed=$changed parseErrors=$parseErrors';
}

void _checkInvariants(MdNode node, int textLength) {
  if (node.start < 0 || node.end < node.start || node.end > textLength) {
    throw StateError(
      'Invariant failed: ${node.runtimeType} [${node.start}, ${node.end}] outside [0, $textLength]',
    );
  }
  for (var i = 0; i < node.children.length; i++) {
    final child = node.children[i];
    if (child.start < node.start || child.end > node.end) {
      throw StateError(
        'Child ${child.runtimeType} [${child.start}, ${child.end}] outside parent ${node.runtimeType} [${node.start}, ${node.end}]',
      );
    }
    if (i + 1 < node.children.length) {
      final next = node.children[i + 1];
      if (child.end > next.start) {
        throw StateError(
          'Siblings overlap: ${child.runtimeType} [${child.start}, ${child.end}] vs ${next.runtimeType} [${next.start}, ${next.end}]',
        );
      }
    }
    _checkInvariants(child, textLength);
  }
}

List<int> _normalizeCrlf(List<int> bytes) {
  final out = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0x0D && i + 1 < bytes.length && bytes[i + 1] == 0x0A) {
      continue;
    }
    out.add(bytes[i]);
  }
  return out;
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<RoundtripResult> checkVaultRoundtrip(String vaultDir) async {
  final fs = IoVaultFileSystem(
    vaultDir,
    ignore: const VaultIgnore(showHidden: true),
  );

  final entries = await fs.list(recursive: true);
  var fileCount = 0;
  var noteCount = 0;
  var unchangedCount = 0;
  var mixedCount = 0;
  var malformedCount = 0;
  var changedCount = 0;
  var parseErrorCount = 0;

  for (final entry in entries) {
    if (entry.isFolder) continue;
    fileCount++;

    if (entry.path.extension.toLowerCase() != 'md') continue;
    noteCount++;

    final bytes = await fs.readBytes(entry.path);
    final doc = TextDocument.decode(bytes);

    // Codec law check
    if (doc.malformed) {
      malformedCount++;
    } else {
      // Check for mixed endings using same counters as TextDocument.decode
      final hasBom =
          bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF;
      final body = hasBom ? bytes.sublist(3) : bytes;
      final raw = utf8.decode(body, allowMalformed: true);

      var crlf = 0;
      var lf = 0;
      var cr = 0;
      for (var i = 0; i < raw.length; i++) {
        final code = raw.codeUnitAt(i);
        if (code == 0x0D) {
          if (i + 1 < raw.length && raw.codeUnitAt(i + 1) == 0x0A) {
            crlf++;
            i++;
          } else {
            cr++;
          }
        } else if (code == 0x0A) {
          lf++;
        }
      }

      final isMixed = crlf > 0 && (lf > 0 || cr > 0);
      final encoded = doc.encode();

      if (!isMixed) {
        if (_bytesEqual(encoded, bytes)) {
          unchangedCount++;
        } else {
          changedCount++;
        }
      } else {
        if (_bytesEqual(_normalizeCrlf(encoded), _normalizeCrlf(bytes))) {
          mixedCount++;
        } else {
          changedCount++;
        }
      }
    }

    // Parse safety check
    try {
      final parsed = MarkdownParser.parse(doc.text);
      _checkInvariants(parsed.root, doc.text.length);
    } catch (_) {
      parseErrorCount++;
    }
  }

  return RoundtripResult(
    vaultDir: vaultDir,
    files: fileCount,
    notes: noteCount,
    unchanged: unchangedCount,
    mixed: mixedCount,
    malformed: malformedCount,
    changed: changedCount,
    parseErrors: parseErrorCount,
  );
}
