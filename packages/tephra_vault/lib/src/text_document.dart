// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

enum LineEnding { lf, crlf }

final class TextDocument {
  const TextDocument({
    required this.text,
    this.hasBom = false,
    this.lineEnding = LineEnding.lf,
    this.malformed = false,
  });

  final String text;
  final bool hasBom;
  final LineEnding lineEnding;
  final bool malformed;

  TextDocument copyWith({
    String? text,
    bool? hasBom,
    LineEnding? lineEnding,
    bool? malformed,
  }) {
    return TextDocument(
      text: text ?? this.text,
      hasBom: hasBom ?? this.hasBom,
      lineEnding: lineEnding ?? this.lineEnding,
      malformed: malformed ?? this.malformed,
    );
  }

  /// Decodes raw bytes into a normalized [TextDocument].
  ///
  /// Strips any UTF-8 BOM, identifies dominant line endings, normalizes all
  /// in-memory newlines to `\n`, and flags malformed UTF-8 without throwing.
  static TextDocument decode(List<int> bytes) {
    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;

    final List<int> body;
    if (hasBom) {
      body = bytes is Uint8List
          ? Uint8List.sublistView(bytes, 3)
          : bytes.sublist(3);
    } else {
      body = bytes;
    }

    var malformed = false;
    String raw;
    try {
      raw = const Utf8Decoder().convert(body);
    } on FormatException {
      malformed = true;
      raw = const Utf8Decoder(allowMalformed: true).convert(body);
    }

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

    final lineEnding = crlf > (lf + cr) ? LineEnding.crlf : LineEnding.lf;

    final String text;
    if (!raw.contains('\r')) {
      text = raw;
    } else {
      text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    }

    return TextDocument(
      text: text,
      hasBom: hasBom,
      lineEnding: lineEnding,
      malformed: malformed,
    );
  }

  /// Encodes [text] back to raw bytes, applying [lineEnding] and [hasBom].
  Uint8List encode() {
    final body = lineEnding == LineEnding.crlf
        ? text.replaceAll('\n', '\r\n')
        : text;
    final encoded = utf8.encode(body);
    if (!hasBom) {
      return encoded;
    }
    final out = Uint8List(3 + encoded.length);
    out[0] = 0xEF;
    out[1] = 0xBB;
    out[2] = 0xBF;
    out.setRange(3, 3 + encoded.length, encoded);
    return out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextDocument &&
          other.text == text &&
          other.hasBom == hasBom &&
          other.lineEnding == lineEnding &&
          other.malformed == malformed);

  @override
  int get hashCode => Object.hash(text, hasBom, lineEnding, malformed);

  @override
  String toString() =>
      'TextDocument(length: ${text.length}, hasBom: $hasBom, lineEnding: $lineEnding, malformed: $malformed)';
}
