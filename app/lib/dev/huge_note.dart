// © 2026 Tephra. All rights reserved.

String generateHugeNote() {
  final buffer = StringBuffer();
  for (var i = 1; i <= 5000; i++) {
    final mod200 = i % 200;
    final mod50 = i % 50;
    final mod7 = i % 7;
    final mod11 = i % 11;

    String line;
    if (mod200 == 100) {
      line = '```dart';
    } else if (mod200 >= 101 && mod200 <= 108) {
      line = '  final value$i = ${i * 2}; // code line';
    } else if (mod200 == 109) {
      line = '```';
    } else if (mod50 == 1) {
      line = '## Section ${(i ~/ 50) + 1}';
    } else if (mod50 == 2 || mod50 == 0) {
      line = '';
    } else if (mod7 == 0) {
      line = '- [ ] Task number $i with #tag${i % 13}';
    } else if (mod7 == 1) {
      line = '- Bullet $i linking [[Note ${i % 97}]]';
    } else if (mod11 == 0) {
      line = '> Quote line $i with ==highlight==';
    } else {
      line =
          'Line $i: The quick brown fox jumps over the lazy dog with **bold**, *italic* and `code`.';
    }
    buffer.write('$line\n');
  }
  return buffer.toString();
}
