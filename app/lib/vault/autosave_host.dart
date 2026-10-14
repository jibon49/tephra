// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workspace/providers.dart';
import 'providers.dart';

/// Wraps [child] and listens to Flutter application lifecycle events
/// to flush dirty documents and workspace persistence immediately upon
/// becoming inactive, hidden, paused, or detached.
class AutosaveHost extends ConsumerStatefulWidget {
  const AutosaveHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutosaveHost> createState() => _AutosaveHostState();
}

class _AutosaveHostState extends ConsumerState<AutosaveHost> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onInactive: _flush,
      onHide: _flush,
      onPause: _flush,
      onDetach: _flush,
    );
  }

  void _flush() {
    final session = ref.read(vaultSessionProvider);
    if (session == null) return;

    final store = ref.read(noteDocumentStoreProvider);
    unawaited(store.flushAll());
    unawaited(ref.read(workspaceProvider.notifier).flushSave());
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
