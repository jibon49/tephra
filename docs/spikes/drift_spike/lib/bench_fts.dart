// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'spike_db.dart';

class QueryMetric {
  QueryMetric({
    required this.query,
    required this.runs,
    required this.medianMs,
    required this.maxMs,
    required this.resultCount,
  });

  final String query;
  final List<double> runs;
  final double medianMs;
  final double maxMs;
  final int resultCount;
}

class BenchmarkResults {
  BenchmarkResults({
    required this.sqliteVersion,
    required this.hasFts5,
    required this.unicode61InsertMs,
    required this.unicode61Queries,
    required this.trigramInsertMs,
    required this.trigramQueries,
    required this.banglaSubstringUnicode61Count,
    required this.banglaSubstringTrigramCount,
  });

  final String sqliteVersion;
  final bool hasFts5;
  final double unicode61InsertMs;
  final List<QueryMetric> unicode61Queries;
  final double trigramInsertMs;
  final List<QueryMetric> trigramQueries;
  final int banglaSubstringUnicode61Count;
  final int banglaSubstringTrigramCount;

  String formatSummary(String platform) {
    final sb = StringBuffer();
    sb.writeln(
      '================ DRIFT FTS5 RESULTS ($platform) ================',
    );
    sb.writeln('SQLite version: $sqliteVersion');
    sb.writeln('ENABLE_FTS5 present: $hasFts5');
    sb.writeln(
      'Unicode61 10k rows insert: ${unicode61InsertMs.toStringAsFixed(1)} ms',
    );
    sb.writeln(
      'Trigram 10k rows insert: ${trigramInsertMs.toStringAsFixed(1)} ms',
    );
    sb.writeln('--- Unicode61 Queries ---');
    for (final q in unicode61Queries) {
      sb.writeln(
        '  Query: "${q.query}" -> count=${q.resultCount}, median=${q.medianMs.toStringAsFixed(2)} ms, max=${q.maxMs.toStringAsFixed(2)} ms',
      );
    }
    sb.writeln('--- Trigram Queries ---');
    for (final q in trigramQueries) {
      sb.writeln(
        '  Query: "${q.query}" -> count=${q.resultCount}, median=${q.medianMs.toStringAsFixed(2)} ms, max=${q.maxMs.toStringAsFixed(2)} ms',
      );
    }
    sb.writeln('Bangla substring "ংলা":');
    sb.writeln('  unicode61 matches: $banglaSubstringUnicode61Count');
    sb.writeln('  trigram matches: $banglaSubstringTrigramCount');
    return sb.toString();
  }
}

class FtsBenchmark {
  static final List<String> _words = _generateWordPool();

  static List<String> _generateWordPool() {
    const baseWords = [
      'apple',
      'apron',
      'arch',
      'armor',
      'arrow',
      'artist',
      'asset',
      'atom',
      'audit',
      'author',
      'baker',
      'ball',
      'banner',
      'bark',
      'barrel',
      'basket',
      'battle',
      'beach',
      'beacon',
      'beam',
      'cabin',
      'cable',
      'cage',
      'cake',
      'camera',
      'camp',
      'canal',
      'candle',
      'cannon',
      'canvas',
      'dairy',
      'daisy',
      'dance',
      'danger',
      'dawn',
      'day',
      'deal',
      'decade',
      'deck',
      'deer',
      'eagle',
      'early',
      'earth',
      'echo',
      'edge',
      'effort',
      'eight',
      'elbow',
      'elder',
      'element',
      'fabric',
      'face',
      'fact',
      'fade',
      'fail',
      'faint',
      'fair',
      'faith',
      'fall',
      'false',
      'galaxy',
      'game',
      'garden',
      'garlic',
      'gas',
      'gate',
      'gather',
      'gear',
      'gem',
      'gender',
      'habit',
      'hail',
      'hair',
      'half',
      'hall',
      'hammer',
      'hand',
      'handle',
      'harbor',
      'hard',
      'ice',
      'icon',
      'idea',
      'ideal',
      'idle',
      'igloo',
      'image',
      'impact',
      'inch',
      'income',
      'jacket',
      'jade',
      'jail',
      'jam',
      'jar',
      'jaw',
      'jazz',
      'jeans',
      'jelly',
      'jewel',
      'kettle',
      'key',
      'kick',
      'kid',
      'kill',
      'kind',
      'king',
      'kiss',
      'kite',
      'kitten',
      'label',
      'labor',
      'lace',
      'ladder',
      'lady',
      'lake',
      'lamb',
      'lamp',
      'land',
      'lane',
      'machine',
      'mad',
      'magic',
      'magnet',
      'maid',
      'mail',
      'main',
      'major',
      'maker',
      'male',
      'nail',
      'name',
      'narrow',
      'nation',
      'native',
      'nature',
      'navy',
      'near',
      'neat',
      'neck',
      'oak',
      'oar',
      'oath',
      'ocean',
      'olive',
      'omen',
      'onion',
      'online',
      'open',
      'opera',
      'pack',
      'packet',
      'page',
      'pain',
      'paint',
      'pair',
      'palace',
      'pale',
      'palm',
      'pan',
      'rabbit',
      'race',
      'radar',
      'radio',
      'raft',
      'rail',
      'rain',
      'rally',
      'ranch',
      'range',
      'sail',
      'salad',
      'salary',
      'sale',
      'salmon',
      'salon',
      'salt',
      'sample',
      'sand',
      'sauce',
      'table',
      'tag',
      'tail',
      'talent',
      'talk',
      'tall',
      'tank',
      'tap',
      'tape',
      'target',
      'umbrella',
      'uncle',
      'under',
      'unit',
      'unite',
      'unity',
      'upper',
      'urban',
      'urge',
      'usage',
      'valley',
      'value',
      'valve',
      'vapor',
      'vase',
      'vault',
      'vector',
      'veil',
      'vein',
      'velvet',
      'wagon',
      'waist',
      'wait',
      'wake',
      'walk',
      'wall',
      'wallet',
      'walnut',
      'wander',
      'want',
      'yard',
      'yarn',
      'yawn',
      'year',
      'yeast',
      'yell',
      'yellow',
      'yield',
      'yoga',
      'yolk',
      'zebra',
      'zenith',
      'zero',
      'zinc',
      'zone',
      'zoom',
    ];
    final list = <String>[...baseWords];
    var counter = 1;
    while (list.length < 500) {
      list.add('term$counter');
      counter++;
    }
    return list;
  }

  static Future<BenchmarkResults> run(
    SpikeDb db, {
    void Function(String msg)? onProgress,
  }) async {
    void log(String msg) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[FTS_BENCH] $msg');
      }
      onProgress?.call(msg);
    }

    log('1. Checking SQLite version & compile options...');
    final versionRows = await db
        .customSelect('SELECT sqlite_version() AS v')
        .get();
    final sqliteVersion = versionRows.first.read<String>('v');
    log('SQLite version: $sqliteVersion');

    final compileOptRows = await db
        .customSelect('PRAGMA compile_options')
        .get();
    final compileOptions = compileOptRows
        .map((r) => r.data.values.first.toString())
        .toSet();
    final hasFts5 = compileOptions.contains('ENABLE_FTS5');
    log('PRAGMA compile_options contains ENABLE_FTS5: $hasFts5');

    // 2. Setup unicode61 virtual table
    log('2. Creating notes_fts table with unicode61 tokenizer...');
    await db.customStatement('DROP TABLE IF EXISTS notes_fts');
    await db.customStatement(
      "CREATE VIRTUAL TABLE notes_fts USING fts5(path, body, tokenize = 'unicode61 remove_diacritics 2')",
    );

    // 3. Insert 10,000 rows
    log('3. Inserting 10,000 rows into notes_fts in a single transaction...');
    final rng = Random(1);
    final rowPaths = <String>[];
    final rowBodies = <String>[];

    for (var i = 0; i < 10000; i++) {
      rowPaths.add('note-$i.md');
      final wordCount = 150 + rng.nextInt(301); // 150..450 words
      final words = <String>[];
      for (var w = 0; w < wordCount; w++) {
        words.add(_words[rng.nextInt(_words.length)]);
      }

      // 2% contain "quick brown fox"
      if (rng.nextDouble() < 0.02) {
        words.insert(rng.nextInt(words.length), 'quick brown fox');
      }

      // 1% contain "বাংলা লেখা"
      if (rng.nextDouble() < 0.01) {
        words.insert(rng.nextInt(words.length), 'বাংলা লেখা');
      }

      // every row contains topic<i % 100>
      words.insert(rng.nextInt(words.length), 'topic${i % 100}');

      rowBodies.add(words.join(' '));
    }

    final swInsertUnicode = Stopwatch()..start();
    await db.transaction(() async {
      for (var chunk = 0; chunk < 10000; chunk += 100) {
        final end = (chunk + 100).clamp(0, 10000);
        final count = end - chunk;
        final placeholders = List.filled(count, '(?, ?)').join(', ');
        final vars = <Variable>[];
        for (var i = chunk; i < end; i++) {
          vars.add(Variable.withString(rowPaths[i]));
          vars.add(Variable.withString(rowBodies[i]));
        }
        await db.customInsert(
          'INSERT INTO notes_fts(path, body) VALUES $placeholders',
          variables: vars,
        );
      }
    });
    swInsertUnicode.stop();
    final unicodeInsertMs = swInsertUnicode.elapsedMicroseconds / 1000.0;
    log(
      'Unicode61 insert complete in ${unicodeInsertMs.toStringAsFixed(1)} ms',
    );

    // 4. Queries on notes_fts (unicode61)
    final testQueries = [
      'topic42',
      'quick AND brown',
      '"quick brown fox"',
      'top*',
      'বাংলা',
      'লেখা',
      'topic7 OR topic8',
      'topic2 NOT topic3',
    ];

    log('4. Running unicode61 test queries (5 runs each)...');
    final unicodeQueryMetrics = <QueryMetric>[];
    for (final q in testQueries) {
      final runs = <double>[];
      var count = 0;
      for (var run = 0; run < 5; run++) {
        final sw = Stopwatch()..start();
        final rows = await db
            .customSelect(
              'SELECT path FROM notes_fts WHERE notes_fts MATCH ? LIMIT 200',
              variables: [Variable.withString(q)],
            )
            .get();
        sw.stop();
        runs.add(sw.elapsedMicroseconds / 1000.0);
        count = rows.length;
      }
      runs.sort();
      final medianMs = runs[2];
      final maxMs = runs.last;
      unicodeQueryMetrics.add(
        QueryMetric(
          query: q,
          runs: runs,
          medianMs: medianMs,
          maxMs: maxMs,
          resultCount: count,
        ),
      );
      log(
        '  Query "$q" -> count=$count, median=${medianMs.toStringAsFixed(2)} ms, max=${maxMs.toStringAsFixed(2)} ms',
      );
    }

    // Bangla substring search check on unicode61
    final unicodeSubRows = await db
        .customSelect(
          'SELECT path FROM notes_fts WHERE notes_fts MATCH ? LIMIT 200',
          variables: [Variable.withString('ংলা*')],
        )
        .get();
    final banglaSubUnicodeCount = unicodeSubRows.length;
    log(
      'Unicode61 bangla substring query ("ংলা*") matches: $banglaSubUnicodeCount',
    );

    // 5. Setup notes_trigram virtual table
    log('5. Creating notes_trigram table with trigram tokenizer...');
    await db.customStatement('DROP TABLE IF EXISTS notes_trigram');
    await db.customStatement(
      "CREATE VIRTUAL TABLE notes_trigram USING fts5(path, body, tokenize = 'trigram')",
    );

    log('Inserting 10,000 rows into notes_trigram...');
    final swInsertTrigram = Stopwatch()..start();
    await db.customStatement(
      'INSERT INTO notes_trigram(path, body) SELECT path, body FROM notes_fts;',
    );
    swInsertTrigram.stop();
    final trigramInsertMs = swInsertTrigram.elapsedMicroseconds / 1000.0;
    log('Trigram insert complete in ${trigramInsertMs.toStringAsFixed(1)} ms');

    final trigramTestQueries = [
      'topic42',
      'quick AND brown',
      '"quick brown fox"',
      'বাংলা',
      'লেখা',
      'ংলা', // Substring query of বাংলা!
    ];

    log('Running trigram test queries (5 runs each)...');
    final trigramQueryMetrics = <QueryMetric>[];
    for (final q in trigramTestQueries) {
      final runs = <double>[];
      var count = 0;
      for (var run = 0; run < 5; run++) {
        final sw = Stopwatch()..start();
        final rows = await db
            .customSelect(
              'SELECT path FROM notes_trigram WHERE notes_trigram MATCH ? LIMIT 200',
              variables: [Variable.withString(q)],
            )
            .get();
        sw.stop();
        runs.add(sw.elapsedMicroseconds / 1000.0);
        count = rows.length;
      }
      runs.sort();
      final medianMs = runs[2];
      final maxMs = runs.last;
      trigramQueryMetrics.add(
        QueryMetric(
          query: q,
          runs: runs,
          medianMs: medianMs,
          maxMs: maxMs,
          resultCount: count,
        ),
      );
      log(
        '  Trigram "$q" -> count=$count, median=${medianMs.toStringAsFixed(2)} ms, max=${maxMs.toStringAsFixed(2)} ms',
      );
    }

    final banglaSubTrigramMetric = trigramQueryMetrics.firstWhere(
      (m) => m.query == 'ংলা',
    );

    final result = BenchmarkResults(
      sqliteVersion: sqliteVersion,
      hasFts5: hasFts5,
      unicode61InsertMs: unicodeInsertMs,
      unicode61Queries: unicodeQueryMetrics,
      trigramInsertMs: trigramInsertMs,
      trigramQueries: trigramQueryMetrics,
      banglaSubstringUnicode61Count: banglaSubUnicodeCount,
      banglaSubstringTrigramCount: banglaSubTrigramMetric.resultCount,
    );

    return result;
  }
}
