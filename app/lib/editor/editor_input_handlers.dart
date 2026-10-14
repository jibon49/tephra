// © 2026 Tephra. All rights reserved.

import 'editor_controller.dart';
import 'editor_engine.dart';
import 'helpers/auto_pair.dart';
import 'helpers/indentation.dart';
import 'helpers/list_continuation.dart';

/// Builds the engine input handlers for auto-pairing, list continuation, and indentation.
EngineInputHandlers buildHandlers(
  EditorController c,
  AutoPairTracker tracker, {
  Future<bool> Function()? onPaste,
}) {
  return EngineInputHandlers(
    onTypedText: (typed) {
      final v = c.lines;
      final sel = c.engine.selection;
      final disabled =
          c.options.readOnly ||
          c.document.isReadOnly ||
          c.highlighter.lineKind(sel.start.line) == 'code';

      final plan = autoPairOnType(v, sel, typed, tracker, disabled: disabled);
      if (plan != null) {
        c.runPlan(plan);
        return true;
      }
      return false;
    },
    onEnter: () {
      final v = c.lines;
      final sel = c.engine.selection;
      final plan = listContinuationOnEnter(v, sel);
      if (plan != null) {
        c.runPlan(plan);
        return true;
      }
      return false;
    },
    onBackspace: () {
      final v = c.lines;
      final sel = c.engine.selection;
      final disabled =
          c.options.readOnly ||
          c.document.isReadOnly ||
          c.highlighter.lineKind(sel.start.line) == 'code';

      final plan = autoPairOnBackspace(v, sel, tracker, disabled: disabled);
      if (plan != null) {
        c.runPlan(plan);
        return true;
      }
      return false;
    },
    onTab: (shift) {
      final v = c.lines;
      final sel = c.engine.selection;
      final plan = indentOnTab(v, sel, c.options, shift: shift);
      if (plan != null) {
        c.runPlan(plan);
      }
      return true; // Always handled when inside editor to prevent focus traversal
    },
    onPaste: () async {
      if (onPaste != null) {
        return await onPaste();
      }
      return false;
    },
  );
}
