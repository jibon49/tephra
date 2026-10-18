// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:test/test.dart';

void main() {
  group('applyTemplate', () {
    final now = DateTime(2026, 10, 11, 14, 5, 9);
    final ctx = TemplateContext(title: 'Plan', date: now, now: now);

    test('{{title}} -> Plan', () {
      expect(applyTemplate('{{title}}', ctx), equals('Plan'));
    });

    test('{{date}} -> 2026-10-11', () {
      expect(applyTemplate('{{date}}', ctx), equals('2026-10-11'));
    });

    test('{{time}} -> 14:05', () {
      expect(applyTemplate('{{time}}', ctx), equals('14:05'));
    });

    test('{{date:dddd}} -> Sunday', () {
      expect(applyTemplate('{{date:dddd}}', ctx), equals('Sunday'));
    });

    test('{{time:hh:mm A}} -> 02:05 PM', () {
      expect(applyTemplate('{{time:hh:mm A}}', ctx), equals('02:05 PM'));
    });

    test('{{ date }} -> 2026-10-11 (whitespace around name)', () {
      expect(applyTemplate('{{ date }}', ctx), equals('2026-10-11'));
    });

    test('{{foo}} unchanged (unknown variable)', () {
      expect(applyTemplate('{{foo}}', ctx), equals('{{foo}}'));
    });

    test('{{date:}} -> 2026-10-11 (empty format falls back to default)', () {
      expect(applyTemplate('{{date:}}', ctx), equals('2026-10-11'));
    });

    test('{{date:Q}} -> Q (unknown format token copied as written)', () {
      expect(applyTemplate('{{date:Q}}', ctx), equals('Q'));
    });

    test('different date and now (e.g. daily note)', () {
      final dailyCtx = TemplateContext(
        title: '2026-10-09',
        date: DateTime(2026, 10, 9),
        now: now,
      );
      expect(applyTemplate('{{date}}', dailyCtx), equals('2026-10-09'));
      expect(applyTemplate('{{time}}', dailyCtx), equals('14:05'));
    });

    test('multiple variables in text replaced', () {
      expect(
        applyTemplate('a {{title}} b {{title}}', ctx),
        equals('a Plan b Plan'),
      );
    });

    test('title containing {{date}} is not re-expanded', () {
      final trickyCtx = TemplateContext(
        title: 'Tricky {{date}} Note',
        date: now,
        now: now,
      );
      expect(
        applyTemplate('Note: {{title}}', trickyCtx),
        equals('Note: Tricky {{date}} Note'),
      );
    });
  });
}
