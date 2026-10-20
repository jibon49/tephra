// © 2026 Tephra. All rights reserved.

import 'dart:typed_data';

/// RFC 4648 Base32 alphabet (A-Z, 2-7).
const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

final Map<String, int> _decodeMap = {
  for (var i = 0; i < _alphabet.length; i++) _alphabet[i]: i,
};

/// Encodes [bytes] to RFC 4648 Base32 string without '=' padding.
String base32Encode(List<int> bytes) {
  if (bytes.isEmpty) return '';

  final buffer = StringBuffer();
  var bitBuffer = 0;
  var bitCount = 0;

  for (final byte in bytes) {
    bitBuffer = (bitBuffer << 8) | (byte & 0xFF);
    bitCount += 8;

    while (bitCount >= 5) {
      bitCount -= 5;
      final index = (bitBuffer >> bitCount) & 0x1F;
      buffer.write(_alphabet[index]);
    }
  }

  if (bitCount > 0) {
    final index = (bitBuffer << (5 - bitCount)) & 0x1F;
    buffer.write(_alphabet[index]);
  }

  return buffer.toString();
}

/// Decodes an RFC 4648 Base32 string without padding into [Uint8List].
///
/// Throws [FormatException] if [input] contains invalid Base32 characters.
Uint8List base32Decode(String input) {
  if (input.isEmpty) return Uint8List(0);

  final upper = input.toUpperCase();
  var bitBuffer = 0;
  var bitCount = 0;
  final output = <int>[];

  for (var i = 0; i < upper.length; i++) {
    final char = upper[i];
    final value = _decodeMap[char];
    if (value == null) {
      throw FormatException('Invalid Base32 character: $char', input, i);
    }

    bitBuffer = (bitBuffer << 5) | value;
    bitCount += 5;

    if (bitCount >= 8) {
      bitCount -= 8;
      output.add((bitBuffer >> bitCount) & 0xFF);
    }
  }

  return Uint8List.fromList(output);
}
