// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:tephra_core/tephra_core.dart';

import 'editor_controller.dart';

/// Registry mapping active [EditorController]s to their vault paths.
final class EditorRegistry extends ChangeNotifier {
  final List<EditorController> _controllers = [];

  void register(EditorController c) {
    if (!_controllers.contains(c)) {
      _controllers.add(c);
      notifyListeners();
    }
  }

  void unregister(EditorController c) {
    if (_controllers.remove(c)) {
      notifyListeners();
    }
  }

  EditorController? controllerFor(VaultPath? path) {
    if (path == null) return null;
    for (final c in _controllers) {
      if (c.path == path) return c;
    }
    return null;
  }

  Iterable<EditorController> get all => List.unmodifiable(_controllers);
}
