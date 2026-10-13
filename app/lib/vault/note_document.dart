// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../editor/edit_operation.dart';
import '../reading/parse_service.dart';

enum SaveState { saved, unsaved, saving, error }

enum SaveOutcome { written, unchanged, readOnly, failed }

abstract interface class NoteEditorBinding {
  String readText();
  void applyEdit(EditOperation op);
  void replaceAll(String text, {required bool keepCursor});
}

final class NoteDocument extends ChangeNotifier {
  NoteDocument({
    required this.path,
    required this.fs,
    required this.clock,
    this.parseService = const ParseService(),
  }) : _base = const TextDocument(text: '');

  final VaultFileSystem fs;
  final Clock clock;
  final ParseService parseService;

  VaultPath path;

  static final _logger = Logger('document');

  TextDocument _base;
  TextDocument get base => _base;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  bool _isMissing = false;
  bool get isMissing => _isMissing;

  bool get isReadOnly => _base.malformed;

  String _savedText = '';
  String get savedText => _savedText;

  String _internalText = '';
  NoteEditorBinding? _editor;
  NoteEditorBinding? get editor => _editor;

  int _revision = 0;
  int get revision => _revision;

  SaveState _saveState = SaveState.saved;
  SaveState get saveState => _saveState;

  Object? _lastError;
  Object? get lastError => _lastError;

  String? _cachedText;
  int _cachedTextRevision = -1;

  bool? _cachedDirty;
  int _cachedDirtyRevision = -1;

  int _parsedRevision = -1;
  Future<ParsedNote>? _parsedFuture;

  /// Returns the parsed AST of the document, memoised per [revision].
  Future<ParsedNote> parsed() {
    if (_parsedFuture != null && _parsedRevision == _revision) {
      return _parsedFuture!;
    }
    _parsedRevision = _revision;
    final currentText = text;
    _parsedFuture = parseService.parse(currentText);
    return _parsedFuture!;
  }

  String get text {
    if (_editor != null) {
      if (_cachedTextRevision != _revision || _cachedText == null) {
        _cachedText = _editor!.readText();
        _cachedTextRevision = _revision;
      }
      return _cachedText!;
    }
    return _internalText;
  }

  bool get isDirty {
    if (_cachedDirtyRevision != _revision || _cachedDirty == null) {
      _cachedDirty = text != _savedText;
      _cachedDirtyRevision = _revision;
    }
    return _cachedDirty!;
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> load() async {
    try {
      final doc = await fs.readText(path);
      if (_isDisposed) return;
      _base = doc;
      _savedText = doc.text;
      _internalText = doc.text;
      _cachedText = null;
      _cachedDirty = null;
      _isLoaded = true;
      _isMissing = false;
      _saveState = SaveState.saved;
      _lastError = null;
      notifyListeners();
    } on FileNotFoundException {
      if (_isDisposed) return;
      _base = const TextDocument(text: '');
      _savedText = '';
      _internalText = '';
      _cachedText = null;
      _cachedDirty = null;
      _isLoaded = true;
      _isMissing = true;
      _saveState = SaveState.saved;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;
      _lastError = e;
      _saveState = SaveState.error;
      notifyListeners();
      rethrow;
    }
  }

  void setText(String newText) {
    if (_internalText == newText && _isLoaded) return;
    _internalText = newText;
    _cachedText = null;
    _cachedDirty = null;
    _revision++;
    _saveState = (newText == _savedText) ? SaveState.saved : SaveState.unsaved;
    notifyListeners();
  }

  void notifyEditorChanged() {
    _cachedText = null;
    _cachedDirty = null;
    _revision++;
    _saveState = SaveState.unsaved;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  bool edit(EditOperation op) {
    if (isReadOnly || !_isLoaded) return false;
    final current = text;
    if (!op.isValidFor(current)) return false;

    if (_editor != null) {
      _editor!.applyEdit(op);
      _cachedText = null;
      _cachedDirty = null;
      _revision++;
      _saveState = SaveState.unsaved;
      notifyListeners();
    } else {
      final updated = op.applyTo(current);
      _internalText = updated;
      _cachedText = null;
      _cachedDirty = null;
      _revision++;
      _saveState = (updated == _savedText)
          ? SaveState.saved
          : SaveState.unsaved;
      notifyListeners();
    }
    return true;
  }

  Future<SaveOutcome> save() async {
    if (isReadOnly) return SaveOutcome.readOnly;

    final current = text;
    if (current == _savedText) {
      _saveState = SaveState.saved;
      notifyListeners();
      return SaveOutcome.unchanged;
    }

    _saveState = SaveState.saving;
    notifyListeners();

    try {
      await fs.writeText(
        path,
        TextDocument(
          text: current,
          hasBom: _base.hasBom,
          lineEnding: _base.lineEnding,
        ),
      );
      _savedText = current;
      _base = _base.copyWith(text: current);
      _saveState = (text == current) ? SaveState.saved : SaveState.unsaved;
      _lastError = null;
      _cachedDirty = null;
      if (!_isDisposed) {
        notifyListeners();
      }
      return SaveOutcome.written;
    } catch (e) {
      _logger.warning('Failed to save document $path: $e');
      _lastError = e;
      _saveState = SaveState.error;
      if (!_isDisposed) {
        notifyListeners();
      }
      return SaveOutcome.failed;
    }
  }

  void attachEditor(NoteEditorBinding binding) {
    _editor = binding;
    _cachedText = null;
    _cachedDirty = null;
    scheduleMicrotask(() {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  void detachEditor(NoteEditorBinding binding) {
    if (_editor == binding) {
      _internalText = binding.readText();
      _editor = null;
      _cachedText = null;
      _cachedDirty = null;
      scheduleMicrotask(() {
        if (!_isDisposed) {
          notifyListeners();
        }
      });
    }
  }
}
