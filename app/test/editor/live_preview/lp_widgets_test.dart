// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/live_preview/widgets/lp_callout_header.dart';
import 'package:tephra/editor/live_preview/widgets/lp_checkbox.dart';
import 'package:tephra/editor/live_preview/widgets/lp_embed.dart';
import 'package:tephra/editor/live_preview/widgets/lp_query_block.dart';
import 'package:tephra/editor/live_preview/widgets/lp_table.dart';
import 'package:tephra/editor/live_preview/widgets/lp_widget_host.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/links/providers.dart';
import 'package:tephra/reading/embeds/embed_view.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';

void main() {
  group('Live Preview Widgets', () {
    testWidgets(
      'checkbox toggling produces TextEdit(i, i+1, "x") and then " "',
      (tester) async {
        final edits = <TextEdit>[];
        final host = LpWidgetHost(
          selectOffset: (_) {},
          applyEdits: (e) => edits.addAll(e),
        );

        // 1. Unchecked '[ ]' toggles to 'x'
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LpCheckboxWidget(
                start: 10,
                end: 13,
                status: ' ',
                host: host,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(LpCheckboxWidget));
        await tester.pump();

        expect(edits.length, equals(1));
        expect(edits.first.start, equals(11));
        expect(edits.first.end, equals(12));
        expect(edits.first.replacement, equals('x'));

        edits.clear();

        // 2. Checked '[x]' toggles to ' '
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LpCheckboxWidget(
                start: 10,
                end: 13,
                status: 'x',
                host: host,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(LpCheckboxWidget));
        await tester.pump();

        expect(edits.length, equals(1));
        expect(edits.first.start, equals(11));
        expect(edits.first.end, equals(12));
        expect(edits.first.replacement, equals(' '));
      },
    );

    testWidgets('a custom status / toggles to " "', (tester) async {
      final edits = <TextEdit>[];
      final host = LpWidgetHost(
        selectOffset: (_) {},
        applyEdits: (e) => edits.addAll(e),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LpCheckboxWidget(start: 10, end: 13, status: '/', host: host),
          ),
        ),
      );

      expect(find.text('/'), findsOneWidget);

      await tester.tap(find.byType(LpCheckboxWidget));
      await tester.pump();

      expect(edits.length, equals(1));
      expect(edits.first.start, equals(11));
      expect(edits.first.end, equals(12));
      expect(edits.first.replacement, equals(' '));
    });

    testWidgets(
      'callout chevron toggles the view-only set and produces no edit',
      (tester) async {
        final edits = <TextEdit>[];
        int? toggledOffset;
        final host = LpWidgetHost(
          selectOffset: (_) {},
          applyEdits: (e) => edits.addAll(e),
          onToggleCallout: (offset) => toggledOffset = offset,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LpCalloutHeaderWidget(
                start: 0,
                end: 15,
                type: 'note',
                title: 'My Callout',
                fold: 'collapsed',
                host: host,
              ),
            ),
          ),
        );

        expect(find.text('My Callout'), findsOneWidget);
        final chevronFinder = find.byIcon(Icons.chevron_right);
        expect(chevronFinder, findsOneWidget);

        await tester.tap(chevronFinder);
        await tester.pump();

        expect(toggledOffset, equals(0));
        expect(edits.isEmpty, isTrue); // View-only: produces NO edit!
      },
    );

    testWidgets('table cell tap selects the cell start offset', (tester) async {
      int? selectedOffset;
      final host = LpWidgetHost(
        selectOffset: (offset) => selectedOffset = offset,
        applyEdits: (_) {},
      );

      const slice =
          '| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |';
      final data = {
        'cellRanges': [
          [
            [2, 10],
            [13, 21],
          ],
          [
            [39, 45],
            [48, 54],
          ],
        ],
        'aligns': ['none', 'none'],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LpTableWidget(
              start: 0,
              end: slice.length,
              data: data,
              slice: slice,
              host: host,
            ),
          ),
        ),
      );

      expect(find.text('Header 1'), findsOneWidget);
      expect(find.text('Cell 2'), findsOneWidget);

      await tester.tap(find.text('Cell 2'));
      await tester.pump();

      expect(selectedOffset, equals(48));
    });

    testWidgets('embed widget renders EmbedView for ![[Other]]', (
      tester,
    ) async {
      int? selectedOffset;
      final host = LpWidgetHost(
        selectOffset: (offset) => selectedOffset = offset,
        applyEdits: (_) {},
        path: VaultPath('current.md'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkResolutionProvider((VaultPath('current.md'), 'Other'))
                .overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LpEmbedWidget(
                start: 5,
                end: 17,
                data: const {'target': 'Other'},
                host: host,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmbedView), findsOneWidget);

      await tester.tap(find.byType(LpEmbedWidget));
      await tester.pump();

      expect(selectedOffset, equals(5));
    });

    testWidgets(
      'query block shows an Edit button that selects the block start',
      (tester) async {
        int? selectedOffset;
        final host = LpWidgetHost(
          selectOffset: (offset) => selectedOffset = offset,
          applyEdits: (_) {},
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: LpQueryBlockWidget(
                  start: 42,
                  end: 60,
                  query: 'path:notes',
                  host: host,
                ),
              ),
            ),
          ),
        );

        final editBtnFinder = find.byIcon(Icons.edit);
        expect(editBtnFinder, findsOneWidget);

        await tester.tap(editBtnFinder);
        await tester.pump();

        expect(selectedOffset, equals(42));
      },
    );
  });
}
