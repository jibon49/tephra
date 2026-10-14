// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../editor/edit_operation.dart';
import '../reading/parse_service.dart';
import 'conflict_resolution.dart' as cr;
import 'three_way_merge.dart';

export 'conflict_resolution.dart' show ConflictChoice;

enum SaveState { saved, unsaved, saving, error }

enum SaveOutcome { written, unchanged, readOnly, failed, conflict }

/// Represents an unresolved conflict between local changes and disk content.
final class MergeConflict {
  const MergeConflict({
    required this.mine,
    required this.theirs,
    required this.theirsHash,
  });

  final String mine;
  final TextDocument theirs;
  final String theirsHash;
}

abstract interface class NoteEditorBinding {
  String readText();
  void applyEdit(EditOperation op);
  void replaceAll(
    String text, {
    required bool keepCursor,
    bool clearHistory = false,
  });
}

final class NoteDocument extends ChangeNotifier {
  NoteDocument({
    required this.path,
    required this.fs,
    required this.clock,
    this.parseService = const ParseService(),
    this.autosaveDelay = const Duration(milliseconds: 1000),
    this.onDiskChanged,
    this.onDocChanged,
  }) : _base = const TextDocument(text: '');

  final VaultFileSystem fs;
  final Clock clock;
  final ParseService parseService;
  final Duration autosaveDelay;
  final VoidCallback? onDiskChanged;
  final VoidCallback? onDocChanged;

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

  String _diskHash = '';
  String get diskHash => _diskHash;

  VaultEntry? _diskStat;
  VaultEntry? get diskStat => _diskStat;

  bool _isDeletedOnDisk = false;
  bool get isDeletedOnDisk => _isDeletedOnDisk;

  MergeConflict? _pendingConflict;
  MergeConflict? get pendingConflict => _pendingConflict;

  Timer? _autosaveTimer;
  bool _recheck = false;

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
      onDocChanged?.call();
    }
  }

  void _restartAutosave() {
    _autosaveTimer?.cancel();
    if (isReadOnly || _pendingConflict != null || _isDeletedOnDisk) {
      return;
    }
    _autosaveTimer = Timer(autosaveDelay, () {
      if (!_isDisposed) {
        save();
      }
    });
  }

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
    _autosaveTimer?.cancel();
    _isDisposed = true;
    super.dispose();
  }

  Future<void> load() async {
    try {
      final bytes = await fs.readBytes(path);
      if (_isDisposed) return;
      final doc = TextDocument.decode(bytes);
      _diskHash = contentHash(bytes);
      _diskStat = await fs.stat(path);
      _base = doc;
      _savedText = doc.text;
      _internalText = doc.text;
      _cachedText = null;
      _cachedDirty = null;
      _isLoaded = true;
      _isMissing = false;
      _isDeletedOnDisk = false;
      _pendingConflict = null;
      _saveState = SaveState.saved;
      _lastError = null;
      _notify();
    } on FileNotFoundException {
      if (_isDisposed) return;
      _base = const TextDocument(text: '');
      _diskHash = '';
      _diskStat = null;
      _savedText = '';
      _internalText = '';
      _cachedText = null;
      _cachedDirty = null;
      _isLoaded = true;
      _isMissing = true;
      _saveState = SaveState.saved;
      _notify();
    } catch (e) {
      if (_isDisposed) return;
      _lastError = e;
      _saveState = SaveState.error;
      _notify();
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
    if (_saveState == SaveState.unsaved) {
      _restartAutosave();
    } else {
      _autosaveTimer?.cancel();
    }
    _notify();
  }

  void notifyEditorChanged() {
    _cachedText = null;
    _cachedDirty = null;
    _revision++;
    _saveState = (text == _savedText) ? SaveState.saved : SaveState.unsaved;
    if (_saveState == SaveState.unsaved) {
      _restartAutosave();
    } else {
      _autosaveTimer?.cancel();
    }
    if (!_isDisposed) {
      _notify();
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
      _saveState = (text == _savedText) ? SaveState.saved : SaveState.unsaved;
      if (_saveState == SaveState.unsaved) {
        _restartAutosave();
      } else {
        _autosaveTimer?.cancel();
      }
      _notify();
    } else {
      final updated = op.applyTo(current);
      _internalText = updated;
      _cachedText = null;
      _cachedDirty = null;
      _revision++;
      _saveState = (updated == _savedText)
          ? SaveState.saved
          : SaveState.unsaved;
      if (_saveState == SaveState.unsaved) {
        _restartAutosave();
      } else {
        _autosaveTimer?.cancel();
      }
      _notify();
    }
    return true;
  }

  Future<SaveOutcome> save({bool force = false}) async {
    _autosaveTimer?.cancel();
    if (isReadOnly) return SaveOutcome.readOnly;
    if (_pendingConflict != null) return SaveOutcome.conflict;

    // External-change guard
    final st = await fs.stat(path);
    if (st != null &&
        _diskStat != null &&
        (st.size != _diskStat!.size || st.modified != _diskStat!.modified)) {
      await onExternalChange();
      if (_pendingConflict != null) return SaveOutcome.conflict;
      if (!isDirty) return SaveOutcome.unchanged;
    }

    final current = text;
    if (!force && current == _savedText) {
      _saveState = SaveState.saved;
      _notify();
      return SaveOutcome.unchanged;
    }

    _saveState = SaveState.saving;
    _notify();

    try {
      final bytes = TextDocument(
        text: current,
        hasBom: _base.hasBom,
        lineEnding: _base.lineEnding,
      ).encode();
      await fs.writeBytes(path, bytes);
      _diskHash = contentHash(bytes);
      _diskStat = await fs.stat(path);
      _savedText = current;
      _base = _base.copyWith(text: current);
      _isDeletedOnDisk = false;
      _saveState = (text == current) ? SaveState.saved : SaveState.unsaved;
      if (_saveState == SaveState.unsaved) {
        _restartAutosave();
      }
      _lastError = null;
      _cachedDirty = null;
      if (!_isDisposed) {
        _notify();
      }
      if (_recheck) {
        _recheck = false;
        await onExternalChange();
      }
      return SaveOutcome.written;
    } catch (e) {
      _logger.warning('Failed to save document $path: $e');
      _lastError = e;
      _saveState = SaveState.error;
      if (!_isDisposed) {
        _notify();
      }
      return SaveOutcome.failed;
    }
  }

  Future<void> onExternalChange() async {
    if (_saveState == SaveState.saving) {
      _recheck = true;
      return;
    }

    final List<int> bytes;
    try {
      bytes = await fs.readBytes(path);
    } on FileNotFoundException {
      await onExternalDelete();
      return;
    }

    final hash = contentHash(bytes);
    if (hash == _diskHash) {
      _diskStat = await fs.stat(path);
      return;
    }

    final theirs = TextDocument.decode(bytes);
    if (theirs.malformed) {
      _base = theirs;
      _diskHash = hash;
      _diskStat = await fs.stat(path);
      _notify();
      return;
    }

    if (theirs.text == _savedText) {
      _base = theirs;
      _diskHash = hash;
      _diskStat = await fs.stat(path);
      _notify();
      return;
    }

    if (!isDirty) {
      _base = theirs;
      _savedText = theirs.text;
      _diskHash = hash;
      _diskStat = await fs.stat(path);
      if (_editor != null) {
        _editor!.replaceAll(theirs.text, keepCursor: true, clearHistory: true);
      } else {
        _internalText = theirs.text;
      }
      _cachedText = null;
      _cachedDirty = null;
      _revision++;
      _saveState = SaveState.saved;
      _isDeletedOnDisk = false;
      _notify();
      onDiskChanged?.call();
      return;
    }

    // Dirty: three-way merge
    final result = threeWayMerge(
      base: _savedText,
      mine: text,
      theirs: theirs.text,
    );
    if (result.clean) {
      _savedText = theirs.text;
      _base = theirs;
      _diskHash = hash;
      _diskStat = await fs.stat(path);
      if (_editor != null) {
        _editor!.replaceAll(result.text, keepCursor: true, clearHistory: false);
      } else {
        _internalText = result.text;
      }
      _cachedText = null;
      _cachedDirty = null;
      _revision++;
      _saveState = (text == _savedText) ? SaveState.saved : SaveState.unsaved;
      _notify();
      _logger.info('merged external change for $path');
      _restartAutosave();
    } else {
      _pendingConflict = MergeConflict(
        mine: text,
        theirs: theirs,
        theirsHash: hash,
      );
      _autosaveTimer?.cancel();
      _notify();
    }
  }

  Future<void> onExternalDelete() async {
    _isDeletedOnDisk = true;
    _autosaveTimer?.cancel();
    _notify();
  }

  Future<void> resolveConflict(cr.ConflictChoice choice) =>
      cr.resolveConflict(this, choice, fs: fs, clock: clock);

  void applyConflictResolution({
    required String newSavedText,
    required TextDocument newBase,
    required String newDiskHash,
    required String newText,
    required bool clearHistory,
  }) {
    _savedText = newSavedText;
    _base = newBase;
    _diskHash = newDiskHash;
    _pendingConflict = null;

    if (_editor != null) {
      _editor!.replaceAll(
        newText,
        keepCursor: true,
        clearHistory: clearHistory,
      );
    } else {
      _internalText = newText;
    }
    _cachedText = null;
    _cachedDirty = null;
    _revision++;
    _saveState = (text == _savedText) ? SaveState.saved : SaveState.unsaved;
    if (_saveState == SaveState.unsaved) {
      _restartAutosave();
    }
    _notify();
  }

  void attachEditor(NoteEditorBinding binding) {
    _editor = binding;
    _cachedText = null;
    _cachedDirty = null;
    scheduleMicrotask(() {
      if (!_isDisposed) {
        _notify();
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
          _notify();
        }
      });
    }
  }
}
