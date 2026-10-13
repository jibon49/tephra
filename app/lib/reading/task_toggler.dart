// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';

import '../editor/edit_operation.dart';
import '../vault/note_document.dart';

/// Applies task checkbox toggle edits directly to a [NoteDocument].
final class TaskToggler {
  const TaskToggler();

  /// Toggles [task] to [newStatus] in [doc].
  ///
  /// Returns `false` without making changes if the document is read-only,
  /// or if the document text at [task.statusOffset] has changed under the view.
  Future<bool> toggleTask(
    NoteDocument doc,
    TaskItem task,
    String newStatus,
  ) async {
    if (doc.isReadOnly) return false;

    final current = doc.text;
    final statusLen = task.status.char.length;
    final offset = task.statusOffset;

    if (offset + statusLen > current.length) {
      return false;
    }

    final existing = current.substring(offset, offset + statusLen);
    if (existing != task.status.char) {
      return false;
    }

    final success = doc.edit(
      EditOperation(offset, offset + statusLen, newStatus),
    );
    if (!success) return false;

    await doc.save();
    return true;
  }
}
