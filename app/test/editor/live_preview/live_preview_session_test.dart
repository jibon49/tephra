// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/live_preview/live_preview_session.dart';
import 'package:tephra/editor/live_preview/reveal.dart' hide TextRange;

final class FakeEditorTarget implements LivePreviewEditorTarget {
  FakeEditorTarget(this.text);

  @override
  String text;

  @override
  TextSelection selection = const TextSelection.collapsed(offset: 0);

  @override
  TextRange composing = TextRange.empty;

  final editsController = StreamController<EditorEdit>.broadcast();
  final selectionChangesController = StreamController<void>.broadcast();

  @override
  Stream<EditorEdit> get edits => editsController.stream;

  @override
  Stream<void> get selectionChanges => selectionChangesController.stream;

  void moveCursor(int offset) {
    selection = TextSelection.collapsed(offset: offset);
    selectionChangesController.add(null);
  }

  void select(int start, int end) {
    selection = TextSelection(baseOffset: start, extentOffset: end);
    selectionChangesController.add(null);
  }

  void type(int at, String inserted) {
    text = text.replaceRange(at, at, inserted);
    editsController.add(
      EditorEdit(
        start: at,
        deletedLength: 0,
        insertedText: inserted,
        isUndoRedo: false,
      ),
    );
  }

  void setComposing(int start, int end) {
    composing = TextRange(start: start, end: end);
    selectionChangesController.add(null);
  }

  void clearComposing() {
    composing = TextRange.empty;
    selectionChangesController.add(null);
  }

  void dispose() {
    editsController.close();
    selectionChangesController.close();
  }
}

void main() {
  test(
    'caret moves within plain text do not trigger changes notification',
    () async {
      const text = 'Hello world here is plain text. **bold** at the end.';
      final target = FakeEditorTarget(text);
      final session = LivePreviewSession(target: target);

      var notifyCount = 0;
      session.decorator.addListener(() {
        notifyCount++;
      });

      // Move within plain text (0 -> 5 -> 10 -> 20)
      target.moveCursor(5);
      await pumpEventQueue();
      expect(notifyCount, equals(0));

      target.moveCursor(10);
      await pumpEventQueue();
      expect(notifyCount, equals(0));

      target.moveCursor(20);
      await pumpEventQueue();
      expect(notifyCount, equals(0));

      session.dispose();
      target.dispose();
    },
  );

  test('caret entering bold triggers changes notification once', () async {
    const text = 'Hello world here is plain text. **bold** at the end.';
    final target = FakeEditorTarget(text);
    final session = LivePreviewSession(target: target);

    var notifyCount = 0;
    session.decorator.addListener(() {
      notifyCount++;
    });

    // Offset of **bold** is 32..40
    target.moveCursor(35);
    await pumpEventQueue();
    expect(notifyCount, equals(1));

    // Moving inside bold should not fire again
    target.moveCursor(36);
    await pumpEventQueue();
    expect(notifyCount, equals(1));

    // Moving back to plain text fires once
    target.moveCursor(10);
    await pumpEventQueue();
    expect(notifyCount, equals(2));

    session.dispose();
    target.dispose();
  });

  test('typing inside bold applies edit with correct delta', () async {
    const text = 'Hello world. **bold** more text.';
    final target = FakeEditorTarget(text);
    final session = LivePreviewSession(target: target);

    var notifyCount = 0;
    session.decorator.addListener(() {
      notifyCount++;
    });

    // Bold starts at 13 ('**bold**' is 13..21)
    target.moveCursor(17);
    await pumpEventQueue();
    expect(notifyCount, equals(1));

    // Type 'er' inside bold at 17 -> 'bolerd'
    target.type(17, 'er');
    await pumpEventQueue();
    expect(notifyCount, equals(2));

    // Verify engine has updated text and decorations
    final decos = session.engine.decorationsFor(13, 23);
    expect(decos, isNotEmpty);

    session.dispose();
    target.dispose();
  });

  test('composing range freezes reveal state', () async {
    const text = 'Start **bold** middle ==highlight== end';
    final target = FakeEditorTarget(text);
    final session = LivePreviewSession(target: target);

    var notifyCount = 0;
    session.decorator.addListener(() {
      notifyCount++;
    });

    // Enter bold (6..14)
    target.moveCursor(9);
    await pumpEventQueue();
    expect(notifyCount, equals(1));

    // Start composing inside bold
    target.setComposing(8, 10);
    await pumpEventQueue();
    expect(notifyCount, equals(2));

    // Move cursor to highlight (22..35) while composing is still active
    target.moveCursor(26);
    await pumpEventQueue();

    // Verify reveal is frozen: bold is still revealed, highlight is NOT revealed
    final decos = session.engine.decorationsFor(0, text.length);
    final boldDeco = decos.firstWhere((d) => d.start >= 6 && d.end <= 14);
    final highlightDeco = decos.firstWhere((d) => d.start >= 22 && d.end <= 35);

    expect(isRevealed(boldDeco, session.active), isTrue);
    expect(isRevealed(highlightDeco, session.active), isFalse);

    // End composing
    target.clearComposing();
    await pumpEventQueue();

    // Now highlight should be revealed and bold hidden
    expect(isRevealed(boldDeco, session.active), isFalse);
    expect(isRevealed(highlightDeco, session.active), isTrue);

    session.dispose();
    target.dispose();
  });

  test('selection spanning two constructs reveals both', () async {
    const text = 'Start **bold** middle ==highlight== end';
    final target = FakeEditorTarget(text);
    final session = LivePreviewSession(target: target);

    // Select from inside bold (9) to inside highlight (26)
    target.select(9, 26);
    await pumpEventQueue();

    final decos = session.engine.decorationsFor(0, text.length);
    final boldDeco = decos.firstWhere((d) => d.start >= 6 && d.end <= 14);
    final highlightDeco = decos.firstWhere((d) => d.start >= 22 && d.end <= 35);

    expect(isRevealed(boldDeco, session.active), isTrue);
    expect(isRevealed(highlightDeco, session.active), isTrue);

    session.dispose();
    target.dispose();
  });
}
