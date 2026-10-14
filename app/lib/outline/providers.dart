// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/providers.dart';
import '../reading/reading_controller.dart';
import 'outline_tree.dart';

/// Outline tree hierarchy for the active note.
final outlineTreeProvider = Provider<List<OutlineNode>>((ref) {
  final parsed = ref.watch(activeParsedNoteProvider);
  if (parsed == null || parsed.headings.isEmpty) {
    return const [];
  }
  return buildOutline(parsed.headings);
});

/// Notifier holding the currently active [ReadingViewController].
class ActiveReadingControllerNotifier extends Notifier<ReadingViewController?> {
  @override
  ReadingViewController? build() => null;

  void set(ReadingViewController? controller) {
    scheduleMicrotask(() {
      state = controller;
    });
  }

  void clearIfCurrent(ReadingViewController controller) {
    scheduleMicrotask(() {
      if (state == controller) {
        state = null;
      }
    });
  }
}

/// Currently mounted [ReadingViewController], or null if no reading view is active.
final activeReadingControllerProvider =
    NotifierProvider<ActiveReadingControllerNotifier, ReadingViewController?>(
      ActiveReadingControllerNotifier.new,
    );
