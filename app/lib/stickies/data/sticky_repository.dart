// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math' as math;

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_search/tephra_search.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../settings/vault_settings.dart';
import '../model/sticky.dart';
import '../model/sticky_color.dart';
import '../model/sticky_frontmatter.dart';
import '../model/sticky_meta.dart';
import '../model/sticky_naming.dart';
import 'open_note_bridge.dart';

/// Configuration view passed to [StickyRepository] for sticky folder and default color.
final class StickySettingsView {
  const StickySettingsView({
    this.stickyFolder = 'Stickies',
    this.defaultColor = StickyColor.fallback,
  });

  factory StickySettingsView.fromVaultSettings(VaultSettings s) {
    return StickySettingsView(
      stickyFolder: s.stickyFolder,
      defaultColor: StickyColor.parse(s.stickyDefaultColor),
    );
  }

  final String stickyFolder;
  final StickyColor defaultColor;
}

/// Base class for events emitted when stickies are created, updated, removed, or moved.
sealed class StickyChange {
  const StickyChange(this.path);
  final VaultPath path;
}

/// Emitted when a new sticky note is detected.
final class StickyAdded extends StickyChange {
  const StickyAdded(super.path, this.sticky);
  final Sticky sticky;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickyAdded && path == other.path && sticky == other.sticky;

  @override
  int get hashCode => Object.hash(path, sticky);

  @override
  String toString() => 'StickyAdded($path)';
}

/// Emitted when an existing sticky note's text or metadata is modified.
final class StickyUpdated extends StickyChange {
  const StickyUpdated(super.path, this.sticky);
  final Sticky sticky;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickyUpdated && path == other.path && sticky == other.sticky;

  @override
  int get hashCode => Object.hash(path, sticky);

  @override
  String toString() => 'StickyUpdated($path)';
}

/// Emitted when a sticky note is deleted, unpinned, or moved to Archive.
final class StickyRemoved extends StickyChange {
  const StickyRemoved(super.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StickyRemoved && path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'StickyRemoved($path)';
}

/// Emitted when a sticky note is renamed or moved across non-archive folders.
final class StickyMoved extends StickyChange {
  const StickyMoved(super.path, this.from, this.sticky);
  final VaultPath from;
  final Sticky sticky;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickyMoved &&
          path == other.path &&
          from == other.from &&
          sticky == other.sticky;

  @override
  int get hashCode => Object.hash(path, from, sticky);

  @override
  String toString() => 'StickyMoved($from -> $path)';
}

/// Central service managing in-memory sticky notes for the open vault.
class StickyRepository {
  StickyRepository({
    required this.fs,
    required this.search,
    required this.settings,
    required this.openNotes,
    required this.clock,
  });

  final VaultFileSystem fs;
  final SearchEngine? search;
  final StickySettingsView settings;
  final OpenNoteBridge openNotes;
  final Clock clock;

  final Map<VaultPath, Sticky> _stickies = {};
  final StreamController<StickyChange> _changesController =
      StreamController<StickyChange>.broadcast();

  StreamSubscription<VaultChange>? _watchSub;
  StreamSubscription<VaultPath>? _editedSub;
  bool _isDisposed = false;

  /// Starts the repository by running candidate discovery and subscribing to file events.
  Future<void> start() async {
    await _watchSub?.cancel();
    _watchSub = fs.watch().listen((change) async {
      if (_isDisposed) return;
      if (change is FileCreated || change is FileModified) {
        if (change.path.extension.toLowerCase() == 'md') {
          await _handleFileChanged(change.path);
        }
      } else if (change is FileDeleted) {
        if (change.path.extension.toLowerCase() == 'md') {
          _handleFileDeleted(change.path);
        }
      } else if (change is FileMoved) {
        await _handleFileMoved(change.from, change.path);
      }
    });

    await _editedSub?.cancel();
    _editedSub = openNotes.edited.listen((path) async {
      if (_isDisposed) return;
      final text = openNotes.openText(path);
      if (text != null) {
        await _updateFromText(path, text);
      }
    });

    // 1. Initial candidate search
    final candidatePaths = <VaultPath>{};
    if (search != null) {
      try {
        final query = SearchParser.parse('[tephra-sticky:true]');
        await for (final res in search!.run(query)) {
          candidatePaths.add(res.path);
        }
      } catch (_) {}
    } else {
      try {
        final entries = await fs.list(recursive: true);
        for (final entry in entries) {
          if (entry.path.extension.toLowerCase() == 'md') {
            candidatePaths.add(entry.path);
          }
        }
      } catch (_) {}
    }

    // 2. Read candidates in batches of 32
    final pathList = candidatePaths.toList();
    for (var i = 0; i < pathList.length; i += 32) {
      if (_isDisposed) return;
      final chunk = pathList.sublist(i, math.min(i + 32, pathList.length));
      await Future.wait(chunk.map((p) => _loadSticky(p)));
    }
  }

  /// Active sticky notes (not under `stickyFolder/Archive/`), sorted by modified descending.
  List<Sticky> get all {
    final list = _stickies.values.where((s) => !_isArchived(s.path)).toList();
    list.sort((a, b) => b.modified.compareTo(a.modified));
    return list;
  }

  /// Archived sticky notes (under `stickyFolder/Archive/`), sorted by modified descending.
  List<Sticky> get archived {
    final list = _stickies.values.where((s) => _isArchived(s.path)).toList();
    list.sort((a, b) => b.modified.compareTo(a.modified));
    return list;
  }

  /// Looks up a sticky note by [path].
  Sticky? byPath(VaultPath path) => _stickies[path];

  /// Broadcast stream of sticky changes.
  Stream<StickyChange> get changes => _changesController.stream;

  /// Creates a new sticky note with [body] and [color] in [settings.stickyFolder].
  Future<Sticky> create({String body = '', StickyColor? color}) async {
    final folder = VaultPath(settings.stickyFolder);

    Set<String> existingNames = const <String>{};
    try {
      final existingEntries = await fs.list(folder: folder, recursive: false);
      existingNames = existingEntries
          .map((e) => e.path.value.toLowerCase())
          .toSet();
    } catch (_) {}

    final path = newStickyPath(
      folder,
      clock.now(),
      (p) => existingNames.contains(p.value.toLowerCase()),
    );

    final text = applyStickyPatch(
      body,
      StickyPatch(sticky: true, color: color ?? settings.defaultColor),
    );

    await fs.writeText(path, TextDocument(text: text));
    await refresh(path);
    return _stickies[path]!;
  }

  /// Modifies frontmatter metadata of a note via [patch].
  Future<void> patch(VaultPath path, StickyPatch patch) async {
    final current = openNotes.openText(path) ?? (await fs.readText(path)).text;
    final newText = applyStickyPatch(current, patch);
    if (newText == current) return;
    await setText(path, newText);
  }

  /// Updates note text through the open document layer if open, else directly to disk.
  Future<void> setText(VaultPath path, String newText) async {
    if (openNotes.openText(path) != null) {
      await openNotes.applyText(path, newText);
    } else {
      TextDocument doc;
      try {
        final oldDoc = await fs.readText(path);
        doc = oldDoc.copyWith(text: newText);
      } catch (_) {
        doc = TextDocument(text: newText);
      }
      await fs.writeText(path, doc);
    }
    await refresh(path);
  }

  /// Re-reads a note from memory or disk and updates its sticky state.
  Future<void> refresh(VaultPath path) async {
    final openText = openNotes.openText(path);
    if (openText != null) {
      await _updateFromText(path, openText);
    } else {
      await _handleFileChanged(path);
    }
  }

  Future<void> _loadSticky(VaultPath path) async {
    try {
      final bytes = await fs.readBytes(path);
      final doc = TextDocument.decode(bytes);
      final parsed = MarkdownParser.parse(doc.text);
      final meta = StickyMeta.fromFrontmatter(parsed.frontmatter);
      if (!meta.isSticky) return;

      final stat = await fs.stat(path);
      final sticky = Sticky(
        path: path,
        meta: meta,
        text: doc.text,
        hash: contentHash(bytes),
        modified: stat?.modified ?? clock.now(),
      );
      _stickies[path] = sticky;
    } catch (_) {}
  }

  Future<void> _handleFileChanged(VaultPath path) async {
    final List<int> bytes;
    final VaultEntry? stat;
    try {
      bytes = await fs.readBytes(path);
      stat = await fs.stat(path);
    } catch (_) {
      _handleFileDeleted(path);
      return;
    }

    final doc = TextDocument.decode(bytes);
    final parsed = MarkdownParser.parse(doc.text);
    final meta = StickyMeta.fromFrontmatter(parsed.frontmatter);

    if (!meta.isSticky) {
      if (_stickies.containsKey(path)) {
        _stickies.remove(path);
        _changesController.add(StickyRemoved(path));
      }
      return;
    }

    final sticky = Sticky(
      path: path,
      meta: meta,
      text: doc.text,
      hash: contentHash(bytes),
      modified: stat?.modified ?? clock.now(),
    );

    final previous = _stickies[path];
    _stickies[path] = sticky;

    if (previous == null) {
      _changesController.add(StickyAdded(path, sticky));
    } else if (previous.hash != sticky.hash || previous.meta != sticky.meta) {
      _changesController.add(StickyUpdated(path, sticky));
    }
  }

  void _handleFileDeleted(VaultPath path) {
    if (_stickies.remove(path) != null) {
      _changesController.add(StickyRemoved(path));
    }
  }

  Future<void> _handleFileMoved(VaultPath from, VaultPath to) async {
    final wasInStickies = _stickies.remove(from);

    final List<int> bytes;
    final VaultEntry? stat;
    try {
      bytes = await fs.readBytes(to);
      stat = await fs.stat(to);
    } catch (_) {
      if (wasInStickies != null) {
        _changesController.add(StickyRemoved(from));
      }
      return;
    }

    final doc = TextDocument.decode(bytes);
    final parsed = MarkdownParser.parse(doc.text);
    final meta = StickyMeta.fromFrontmatter(parsed.frontmatter);

    if (!meta.isSticky) {
      if (wasInStickies != null) {
        _changesController.add(StickyRemoved(from));
      }
      return;
    }

    final newSticky = Sticky(
      path: to,
      meta: meta,
      text: doc.text,
      hash: contentHash(bytes),
      modified: stat?.modified ?? clock.now(),
    );

    _stickies[to] = newSticky;

    final wasArchived = _isArchived(from);
    final isNowArchived = _isArchived(to);

    if (!wasArchived && isNowArchived) {
      _changesController.add(StickyRemoved(from));
    } else if (wasInStickies != null) {
      _changesController.add(StickyMoved(to, from, newSticky));
    } else {
      _changesController.add(StickyAdded(to, newSticky));
    }
  }

  Future<void> _updateFromText(VaultPath path, String text) async {
    final parsed = MarkdownParser.parse(text);
    final meta = StickyMeta.fromFrontmatter(parsed.frontmatter);

    if (!meta.isSticky) {
      if (_stickies.containsKey(path)) {
        _stickies.remove(path);
        _changesController.add(StickyRemoved(path));
      }
      return;
    }

    final previous = _stickies[path];
    final stat = await fs.stat(path);
    final sticky = Sticky(
      path: path,
      meta: meta,
      text: text,
      hash: contentHash(TextDocument(text: text).encode()),
      modified: stat?.modified ?? clock.now(),
    );

    _stickies[path] = sticky;
    if (previous == null) {
      _changesController.add(StickyAdded(path, sticky));
    } else if (previous.text != sticky.text || previous.meta != sticky.meta) {
      _changesController.add(StickyUpdated(path, sticky));
    }
  }

  bool _isArchived(VaultPath path) {
    final archiveFolder = VaultPath(settings.stickyFolder).join('Archive');
    return path.value == archiveFolder.value || path.isWithin(archiveFolder);
  }

  /// Cancels subscriptions and closes streams.
  Future<void> dispose() async {
    _isDisposed = true;
    await _watchSub?.cancel();
    await _editedSub?.cancel();
    await _changesController.close();
  }
}
