// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../settings/providers.dart';
import '../vault/providers.dart';
import '../workspace/providers.dart';
import 'attachment_service.dart';
import 'editor_controller.dart';
import 'editor_options.dart';
import 'editor_registry.dart';

export '../reading/link_actions.dart'
    show PendingJump, PendingJumpNotifier, pendingJumpProvider;

/// Attachment service provider.
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref);
});

/// Single editor registry instance for the vault session.
final editorRegistryProvider = Provider<EditorRegistry>((ref) {
  return EditorRegistry();
});

/// Editor options derived from vault settings.
final editorOptionsProvider = Provider<EditorOptions>((ref) {
  final s = ref.watch(vaultSettingsProvider);
  return EditorOptions(
    useTab: s.useTab,
    tabSize: s.tabSize,
    fontSize: s.fontSize,
    readableLineLength: s.readableLineLength,
  );
});

/// Currently active note editor controller, or null if no note is focused or not open in source mode.
final activeEditorProvider = Provider<EditorController?>((ref) {
  final activePath = ref.watch(activeNotePathProvider);
  final registry = ref.watch(editorRegistryProvider);

  var isDisposed = false;
  void onRegistryChanged() {
    scheduleMicrotask(() {
      if (!isDisposed) {
        ref.invalidateSelf();
      }
    });
  }

  registry.addListener(onRegistryChanged);
  ref.onDispose(() {
    isDisposed = true;
    registry.removeListener(onRegistryChanged);
  });

  return registry.controllerFor(activePath);
});

/// AST parse for the active note, debounced 300 ms after document edits.
final activeParsedNoteProvider =
    NotifierProvider<ActiveParsedNoteNotifier, ParsedNote?>(
      ActiveParsedNoteNotifier.new,
    );

class ActiveParsedNoteNotifier extends Notifier<ParsedNote?> {
  Timer? _timer;

  @override
  ParsedNote? build() {
    final activePath = ref.watch(activeNotePathProvider);
    if (activePath == null) return null;

    final doc = ref.watch(noteDocumentProvider(activePath));

    void scheduleReparse() {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 300), () async {
        if (!doc.isLoaded) await doc.load();
        final targetRev = doc.revision;
        final parsed = await doc.parsed();
        if (doc.revision == targetRev) {
          state = parsed;
        }
      });
    }

    doc.addListener(scheduleReparse);
    ref.onDispose(() {
      doc.removeListener(scheduleReparse);
      _timer?.cancel();
    });

    scheduleReparse();
    return null;
  }
}

/// One-shot flag indicating the editor should request focus immediately upon opening.
final focusEditorOnOpenProvider =
    NotifierProvider<FocusEditorOnOpenNotifier, bool>(
      FocusEditorOnOpenNotifier.new,
    );

class FocusEditorOnOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}
