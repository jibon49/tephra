// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/search/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_search/tephra_search.dart';

class _FakeSearchRunner {
  int runCount = 0;
  CancelToken? lastCancelToken;
  Stream<SearchResult> Function(SearchExpr expr, CancelToken? cancel)? onRun;

  Stream<SearchResult> call(
    SearchExpr expr, {
    CancelToken? cancel,
    SearchSort sort = SearchSort.fileNameAsc,
    bool matchCase = false,
  }) {
    runCount++;
    lastCancelToken = cancel;
    if (onRun != null) {
      return onRun!(expr, cancel);
    }
    return Stream.value(
      SearchResult(VaultPath('Test.md'), const [
        SearchMatch(
          line: 0,
          start: 0,
          end: 4,
          snippet: 'test snippet',
          snippetStart: 0,
          snippetEnd: 4,
        ),
      ]),
    );
  }
}

void main() {
  late _FakeSearchRunner fakeRunner;
  late ProviderContainer container;

  setUp(() {
    fakeRunner = _FakeSearchRunner();
    container = ProviderContainer(
      overrides: [searchRunnerProvider.overrideWithValue(fakeRunner.call)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('typing 3 characters within 250 ms triggers one run', () async {
    final controller = container.read(searchControllerProvider.notifier);

    controller.setQuery('a');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    controller.setQuery('ab');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    controller.setQuery('abc');

    expect(fakeRunner.runCount, equals(0));

    // Wait past the 250 ms debounce
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(fakeRunner.runCount, equals(1));
    expect(container.read(searchControllerProvider).query, equals('abc'));
    expect(container.read(searchControllerProvider).results, isNotEmpty);
  });

  test('a new query cancels the previous token', () async {
    final streamController = StreamController<SearchResult>();
    fakeRunner.onRun = (expr, cancel) => streamController.stream;

    final controller = container.read(searchControllerProvider.notifier);

    controller.setQuery('first');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(fakeRunner.runCount, equals(1));
    final token1 = fakeRunner.lastCancelToken;
    expect(token1, isNotNull);
    expect(token1!.isCancelled, isFalse);

    // New query before previous completes
    controller.setQuery('second');
    expect(token1.isCancelled, isTrue);

    await streamController.close();
  });

  test('syntax error sets error and clears results', () async {
    final controller = container.read(searchControllerProvider.notifier);

    // First run a valid query
    controller.setQuery('valid');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(container.read(searchControllerProvider).results, isNotEmpty);
    expect(container.read(searchControllerProvider).error, isNull);

    // Now input query with unclosed parenthesis which fails syntax parse
    controller.setQuery('(unclosed');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final state = container.read(searchControllerProvider);
    expect(state.error, isNotNull);
    expect(state.error, contains('Search syntax error'));
    expect(state.results, isEmpty);
    expect(state.running, isFalse);
  });
}
