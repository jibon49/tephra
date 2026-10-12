// © 2026 Tephra. All rights reserved.

import 'package:editor_spike/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Editor spike smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EditorSpikeApp());
    expect(find.text('A: re_editor'), findsOneWidget);
    expect(find.text('B: TextField'), findsOneWidget);
  });
}
