// © 2026 Tephra. All rights reserved.

import 'dart:math';

/// Generates a RFC 4122 version 4 UUID string.
///
/// Uses [random] if provided, or [Random.secure] by default.
String generateUuidV4([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // Set version 4: bits 4-7 of time_hi_and_version to 0100
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  // Set variant: bits 6-7 of clock_seq_hi_and_reserved to 10
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  String hexByte(int b) => b.toRadixString(16).padLeft(2, '0');

  final buf = StringBuffer();
  for (var i = 0; i < 4; i++) {
    buf.write(hexByte(bytes[i]));
  }
  buf.write('-');
  for (var i = 4; i < 6; i++) {
    buf.write(hexByte(bytes[i]));
  }
  buf.write('-');
  for (var i = 6; i < 8; i++) {
    buf.write(hexByte(bytes[i]));
  }
  buf.write('-');
  for (var i = 8; i < 10; i++) {
    buf.write(hexByte(bytes[i]));
  }
  buf.write('-');
  for (var i = 10; i < 16; i++) {
    buf.write(hexByte(bytes[i]));
  }

  return buf.toString().toLowerCase();
}
