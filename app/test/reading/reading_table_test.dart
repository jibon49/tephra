// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/reading_table.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets(
    'TableView renders bold headers, alignments, and pads short rows',
    (tester) async {
      final table = MdTable(
        0,
        100,
        aligns: [TableAlign.left, TableAlign.center, TableAlign.right],
        children: [
          MdTableRow(
            0,
            30,
            header: true,
            children: [
              MdTableCell(0, 10, children: [MdText(0, 10, text: 'H1')]),
              MdTableCell(10, 20, children: [MdText(10, 20, text: 'H2')]),
              MdTableCell(20, 30, children: [MdText(20, 30, text: 'H3')]),
            ],
          ),
          MdTableRow(
            31,
            50,
            header: false,
            children: [
              MdTableCell(31, 40, children: [MdText(31, 40, text: 'A1')]),
              MdTableCell(41, 50, children: [MdText(41, 50, text: 'A2')]),
              // Short row: cell 3 omitted!
            ],
          ),
        ],
      );

      await tester.pumpWidget(testApp(Scaffold(body: TableView(node: table))));
      await tester.pumpAndSettle();

      // 1. Horizontal SingleChildScrollView found
      final scrollFinder = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(scrollFinder, findsOneWidget);

      // 2. Table widget found with 2 rows and 3 cells per row (short row padded)
      final tableWidget = tester.widget<Table>(find.byType(Table));
      expect(tableWidget.children.length, equals(2));
      expect(tableWidget.children[0].children.length, equals(3));
      expect(tableWidget.children[1].children.length, equals(3));

      // 3. Header cell is bold
      final headerRichText = tester.widget<Text>(find.text('H1'));
      final headerSpan = headerRichText.textSpan as TextSpan?;
      expect(headerSpan?.style?.fontWeight, equals(FontWeight.bold));

      // 4. Center aligned cell has TextAlign.center
      final centerRichText = tester.widget<Text>(find.text('A2'));
      expect(centerRichText.textAlign, equals(TextAlign.center));
    },
  );
}
