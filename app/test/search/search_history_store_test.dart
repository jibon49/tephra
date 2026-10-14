// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/search/search_history_store.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  late MemoryVaultFileSystem fs;
  late SearchHistoryStore store;

  setUp(() {
    fs = MemoryVaultFileSystem();
    store = SearchHistoryStore(fs);
  });

  test('missing file returns empty history', () async {
    final list = await store.load();
    expect(list, isEmpty);
  });

  test('add 25 queries -> 20 kept newest first', () async {
    for (var i = 1; i <= 25; i++) {
      await store.addQuery('query $i');
    }

    final list = await store.load();
    expect(list.length, equals(20));
    expect(list.first, equals('query 25'));
    expect(list.last, equals('query 6'));
  });

  test('re-adding an old query moves it to the front', () async {
    await store.addQuery('first');
    await store.addQuery('second');
    await store.addQuery('third');

    final updated = await store.addQuery('first');
    expect(updated, equals(['first', 'third', 'second']));

    final loaded = await store.load();
    expect(loaded, equals(['first', 'third', 'second']));
  });

  test('corrupt JSON returns empty list without throwing', () async {
    await fs.writeText(
      SearchHistoryStore.historyPath,
      const TextDocument(text: '{ invalid json [ ]'),
    );

    final list = await store.load();
    expect(list, isEmpty);
  });

  test('clearing removes history file', () async {
    await store.addQuery('alpha');
    expect(await store.load(), isNotEmpty);

    await store.clear();
    expect(await store.load(), isEmpty);
  });
}
