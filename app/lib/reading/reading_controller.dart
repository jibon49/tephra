// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';

/// Interface implemented by ReadingView state for controller interactions.
abstract interface class ReadingViewStateAccessor {
  void scrollToOffset(int offset);
  void scrollToHeading(String heading);
  void scrollToBlockRef(String id);
  int? get topOffset;
  ParsedNote? get parsed;
}

/// Controller for interacting with a [ReadingView].
class ReadingViewController {
  ReadingViewStateAccessor? _state;

  void attach(ReadingViewStateAccessor state) {
    _state = state;
  }

  void detach(ReadingViewStateAccessor state) {
    if (_state == state) {
      _state = null;
    }
  }

  /// Scrolls to the top-level block containing or closest preceding [offset].
  void scrollToOffset(int offset) {
    _state?.scrollToOffset(offset);
  }

  /// Scrolls to the first heading matching [heading] after normalization.
  void scrollToHeading(String heading) {
    _state?.scrollToHeading(heading);
  }

  /// Scrolls to the block referenced by [id] (case-insensitive).
  void scrollToBlockRef(String id) {
    _state?.scrollToBlockRef(id);
  }

  /// Returns the source offset of the top-most visible block, if any.
  int? get topOffset => _state?.topOffset;

  /// Returns the current parsed document, if available.
  ParsedNote? get parsed => _state?.parsed;
}
