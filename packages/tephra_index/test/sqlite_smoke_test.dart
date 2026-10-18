// © 2026 Tephra. All rights reserved.

import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  final logger = Logger('index');
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
  });

  tearDown(() {
    db.close();
  });

  test('sqlite version is at least 3.45', () {
    final result = db.select('SELECT sqlite_version() AS v');
    expect(result, isNotEmpty);
    final versionStr = result.first['v'] as String;
    logger.info('SQLite version: $versionStr');

    final parts = versionStr.split('.').map(int.parse).toList();
    expect(parts.length, greaterThanOrEqualTo(2));
    final major = parts[0];
    final minor = parts[1];

    final isAtLeast345 = major > 3 || (major == 3 && minor >= 45);
    expect(
      isAtLeast345,
      isTrue,
      reason: 'Expected SQLite >= 3.45, got $versionStr',
    );
  });

  test('fts5 is compiled in', () {
    db.execute('CREATE VIRTUAL TABLE t USING fts5(body)');
    db.execute("INSERT INTO t(body) VALUES ('hello world')");
    final rows = db.select("SELECT rowid FROM t WHERE t MATCH 'hello'");
    expect(rows.length, equals(1));
  });

  test('contentless_delete works', () {
    db.execute(
      "CREATE VIRTUAL TABLE c USING fts5(body, content='', contentless_delete=1)",
    );
    db.execute("INSERT INTO c(rowid, body) VALUES (7, 'alpha beta')");
    db.execute('DELETE FROM c WHERE rowid = 7');
    final rows = db.select("SELECT rowid FROM c WHERE c MATCH 'alpha'");
    expect(rows.length, equals(0));
  });

  test('trigram finds substrings case-insensitively', () {
    db.execute(
      "CREATE VIRTUAL TABLE g USING fts5(body, content='', contentless_delete=1, tokenize='trigram case_sensitive 0')",
    );
    db.execute("INSERT INTO g(body) VALUES ('The Meeting is on Monday')");

    final r1 = db.select("SELECT rowid FROM g WHERE g MATCH '\"eetin\"'");
    expect(r1.length, equals(1));

    final r2 = db.select("SELECT rowid FROM g WHERE g MATCH '\"MEETING\"'");
    expect(r2.length, equals(1));

    final r3 = db.select("SELECT rowid FROM g WHERE g MATCH '\"meetings\"'");
    expect(r3.length, equals(0));
  });

  test('trigram finds Bangla substrings', () {
    db.execute(
      "CREATE VIRTUAL TABLE g USING fts5(body, content='', contentless_delete=1, tokenize='trigram case_sensitive 0')",
    );
    db.execute("INSERT INTO g(body) VALUES ('আমি বাংলায় গান গাই।')");

    final rows = db.select("SELECT rowid FROM g WHERE g MATCH '\"বাংলা\"'");
    expect(rows.length, equals(1));
  });

  test('unicode61 with mark categories keeps Bangla words whole', () {
    db.execute('''
      CREATE VIRTUAL TABLE w USING fts5(body, content='', contentless_delete=1,
        tokenize="unicode61 remove_diacritics 2 categories 'L* N* Co M*'");
    ''');
    db.execute("CREATE VIRTUAL TABLE wv USING fts5vocab('w', 'row')");

    db.execute("INSERT INTO w(body) VALUES ('আমি বাংলায় গান গাই। কম্পিউটার')");

    final vocabRows = db.select('SELECT term FROM wv ORDER BY term');
    final terms = vocabRows.map((r) => r['term'] as String).toSet();
    expect(terms, equals({'আমি', 'বাংলায়', 'গান', 'গাই', 'কম্পিউটার'}));

    final m1 = db.select("SELECT rowid FROM w WHERE w MATCH 'বাংলায়'");
    expect(m1.length, equals(1));

    final m2 = db.select("SELECT rowid FROM w WHERE w MATCH 'কম্পিউটার'");
    expect(m2.length, equals(1));
  });

  test('unicode61 folds Latin diacritics', () {
    db.execute('''
      CREATE VIRTUAL TABLE w USING fts5(body, content='', contentless_delete=1,
        tokenize="unicode61 remove_diacritics 2 categories 'L* N* Co M*'");
    ''');
    db.execute("INSERT INTO w(body) VALUES ('Café crème')");

    final r1 = db.select("SELECT rowid FROM w WHERE w MATCH 'cafe'");
    expect(r1.length, equals(1));

    final r2 = db.select("SELECT rowid FROM w WHERE w MATCH 'creme'");
    expect(r2.length, equals(1));
  });

  test(
    'default unicode61 splits Bangla (documents why categories is needed)',
    () {
      db.execute('''
      CREATE VIRTUAL TABLE w_default USING fts5(body, content='', contentless_delete=1,
        tokenize='unicode61 remove_diacritics 2');
    ''');
      db.execute(
        "CREATE VIRTUAL TABLE wv_default USING fts5vocab('w_default', 'row')",
      );
      db.execute(
        "INSERT INTO w_default(body) VALUES ('আমি বাংলায় গান গাই। কম্পিউটার')",
      );

      final vocabRows = db.select('SELECT term FROM wv_default ORDER BY term');
      expect(vocabRows.length, greaterThan(5));
    },
  );
}
