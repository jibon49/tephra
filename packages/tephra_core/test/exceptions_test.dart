// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:test/test.dart';

void main() {
  test('exceptions inherit from TephraException and format toString', () {
    const inv = InvalidPathException('bad path');
    expect(inv, isA<TephraException>());
    expect(inv.toString(), equals('InvalidPathException: bad path'));

    final fnf = FileNotFoundException(VaultPath('a.md'));
    expect(fnf, isA<TephraException>());
    expect(fnf.message, contains('a.md'));
    expect(
      fnf.toString(),
      equals('FileNotFoundException: File not found: a.md'),
    );

    final fcf = FileConflictException(VaultPath('a.md'));
    expect(fcf, isA<TephraException>());
    expect(fcf.message, contains('a.md'));
    expect(
      fcf.toString(),
      equals('FileConflictException: Target already exists: a.md'),
    );

    const perm = PermissionDeniedException('denied');
    expect(perm, isA<TephraException>());
    expect(perm.toString(), equals('PermissionDeniedException: denied'));

    const parse = ParseException('syntax error');
    expect(parse, isA<TephraException>());
    expect(parse.toString(), equals('ParseException: syntax error'));

    const sync = SyncException('remote error');
    expect(sync, isA<TephraException>());
    expect(sync.toString(), equals('SyncException: remote error'));

    const crypto = CryptoException('key error');
    expect(crypto, isA<TephraException>());
    expect(crypto.toString(), equals('CryptoException: key error'));
  });
}
