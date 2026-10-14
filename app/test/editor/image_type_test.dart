// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/image_type.dart';

void main() {
  group('detectImageExtension', () {
    test('detects real PNG file bytes from test fixtures', () {
      final file =
          File('test_vaults/syntax/attachments/sample.png').existsSync()
          ? File('test_vaults/syntax/attachments/sample.png')
          : File('../test_vaults/syntax/attachments/sample.png');
      final bytes = file.readAsBytesSync();
      expect(detectImageExtension(bytes), equals('png'));
    });

    test('detects handmade PNG signature', () {
      final bytes = [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
      ];
      expect(detectImageExtension(bytes), equals('png'));
    });

    test('detects JPEG signature', () {
      final bytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];
      expect(detectImageExtension(bytes), equals('jpg'));
    });

    test('detects GIF87a and GIF89a signatures', () {
      final gif87 = 'GIF87a'.codeUnits;
      final gif89 = 'GIF89a'.codeUnits;
      expect(detectImageExtension(gif87), equals('gif'));
      expect(detectImageExtension(gif89), equals('gif'));
    });

    test('detects WebP signature', () {
      // RIFF....WEBP
      final webp = [
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // length
        0x57, 0x45, 0x42, 0x50, // WEBP
      ];
      expect(detectImageExtension(webp), equals('webp'));
    });

    test('detects BMP signature', () {
      final bmp = [0x42, 0x4D, 0x00, 0x00, 0x00, 0x00];
      expect(detectImageExtension(bmp), equals('bmp'));
    });

    test('returns null for random or too short bytes', () {
      expect(detectImageExtension([]), isNull);
      expect(detectImageExtension([0x01, 0x02, 0x03]), isNull);
      expect(
        detectImageExtension([0x89, 0x50, 0x4E]),
        isNull,
      ); // Incomplete PNG
      expect(detectImageExtension('Random text content'.codeUnits), isNull);
    });
  });
}
