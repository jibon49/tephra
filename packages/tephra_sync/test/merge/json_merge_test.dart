// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('mergeJson', () {
    test(
      'workspace.json with two device keys edited on two sides merges cleanly',
      () {
        final base = json.encode({
          'dev-windows': {
            'focused': 0,
            'panes': ['tab1'],
          },
          'dev-android': {
            'focused': 0,
            'panes': ['tabA'],
          },
        });

        final local = json.encode({
          'dev-windows': {
            'focused': 1,
            'panes': ['tab1', 'tab2'],
          },
          'dev-android': {
            'focused': 0,
            'panes': ['tabA'],
          },
        });

        final remote = json.encode({
          'dev-windows': {
            'focused': 0,
            'panes': ['tab1'],
          },
          'dev-android': {
            'focused': 2,
            'panes': ['tabA', 'tabB'],
          },
        });

        final outcome = mergeJson(base, local, remote);
        expect(outcome.isClean, isTrue);

        final decoded = json.decode(outcome.text!) as Map<String, dynamic>;
        final devWin = decoded['dev-windows'] as Map<String, dynamic>;
        final devAnd = decoded['dev-android'] as Map<String, dynamic>;
        expect(devWin['focused'], equals(1));
        expect(devWin['panes'], equals(['tab1', 'tab2']));
        expect(devAnd['focused'], equals(2));
        expect(devAnd['panes'], equals(['tabA', 'tabB']));

        // Must end with a newline
        expect(outcome.text!.endsWith('\n'), isTrue);
      },
    );

    test(
      'recursing one level into device objects merges independent subkeys',
      () {
        final base = json.encode({
          'dev-1': {'theme': 'light', 'fontSize': 14},
        });

        final local = json.encode({
          'dev-1': {
            'theme': 'dark', // changed theme
            'fontSize': 14,
          },
        });

        final remote = json.encode({
          'dev-1': {
            'theme': 'light',
            'fontSize': 16, // changed fontSize
          },
        });

        final outcome = mergeJson(base, local, remote);
        expect(outcome.isClean, isTrue);

        final decoded = json.decode(outcome.text!) as Map<String, dynamic>;
        final dev1 = decoded['dev-1'] as Map<String, dynamic>;
        expect(dev1['theme'], equals('dark'));
        expect(dev1['fontSize'], equals(16));
      },
    );

    test('conflicting edits produce conflict', () {
      final base = json.encode({'key': 'value-base'});

      final local = json.encode({'key': 'value-local'});

      final remote = json.encode({'key': 'value-remote'});

      final outcome = mergeJson(base, local, remote);
      expect(outcome.isClean, isFalse);
    });

    test('invalid JSON syntax produces conflict', () {
      const valid = '{"a": 1}';
      const invalid = '{ broken json ';

      expect(mergeJson(invalid, valid, valid).isClean, isFalse);
      expect(mergeJson(valid, invalid, valid).isClean, isFalse);
      expect(mergeJson(valid, valid, invalid).isClean, isFalse);
    });
  });
}
