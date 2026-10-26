// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../core/headless_config.dart';
import '../data/sticky_edit_applier.dart';
import '../data/sticky_file_writer.dart';
import 'overlay_protocol.dart';
import 'widget_data.dart';

/// Status of attempting to save sticky edits from the floating overlay.
enum OverlaySaveStatus {
  /// Edit was successfully delivered to and acknowledged by the running main app.
  savedViaMain,

  /// Main app did not acknowledge in time; successfully saved directly to disk via [StickyFileWriter].
  savedFallback,

  /// Main app did not acknowledge in time and on-disk file differed; saved conflict copy.
  savedConflictFallback,

  /// Main app did not acknowledge in time, and headless writes are unavailable (e.g. SAF mode).
  requiresTephraToSave,

  /// General save failure (e.g. file missing).
  failed,
}

/// Manages sending edits from the overlay to the main engine, falling back to direct disk writes
/// via [StickyFileWriter] when the main engine is destroyed or unresponsive.
class OverlayWriterFallback {
  OverlayWriterFallback({
    required this.sendToMain,
    this.fsFactory,
    this.headlessConfigReader,
    this.conflictNamer,
    this.ackTimeout = const Duration(milliseconds: 1500),
  });

  final Future<void> Function(OverlayMessage message) sendToMain;
  final VaultFileSystem Function(String root)? fsFactory;
  final Future<HeadlessConfig?> Function()? headlessConfigReader;
  final ConflictCopyNamer? conflictNamer;
  final Duration ackTimeout;

  Timer? _ackTimer;
  Completer<OverlaySaveStatus>? _pendingSaveCompleter;
  String? _pendingHash;

  /// Handles incoming ack message from the main engine.
  void onAckReceived(String path, String hash) {
    if (_pendingHash == hash || _pendingSaveCompleter != null) {
      _ackTimer?.cancel();
      _ackTimer = null;
      if (_pendingSaveCompleter != null &&
          !_pendingSaveCompleter!.isCompleted) {
        _pendingSaveCompleter!.complete(OverlaySaveStatus.savedViaMain);
      }
      _pendingSaveCompleter = null;
      _pendingHash = null;
    }
  }

  /// Sends [text] to the main app engine, waiting up to [ackTimeout] for confirmation.
  /// If no confirmation is received, performs a fallback write according to Step 04.14 rules.
  Future<OverlaySaveStatus> sendEdit({
    required VaultPath path,
    required String text,
    required String baseHash,
  }) async {
    _ackTimer?.cancel();
    _pendingSaveCompleter?.complete(OverlaySaveStatus.savedViaMain);

    final completer = Completer<OverlaySaveStatus>();
    _pendingSaveCompleter = completer;

    final expectedHash = stickyProtocolHash(text);
    _pendingHash = expectedHash;

    try {
      await sendToMain(
        OverlayContentChangedMessage(
          path: path.value,
          text: text,
          baseHash: baseHash,
        ),
      );
    } catch (_) {
      // Main engine channel failed; immediately proceed to fallback
    }

    _ackTimer = Timer(ackTimeout, () async {
      if (completer.isCompleted) return;

      final fallbackStatus = await _executeFallback(
        path: path,
        text: text,
        baseHash: baseHash,
      );
      if (!completer.isCompleted) {
        completer.complete(fallbackStatus);
      }
    });

    return completer.future;
  }

  Future<HeadlessConfig?> _loadConfig() async {
    if (headlessConfigReader != null) {
      return headlessConfigReader!();
    }
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final configFile = File(p.join(appSupportDir.path, 'headless.json'));
      return await HeadlessConfig.load(configFile);
    } catch (_) {
      return null;
    }
  }

  Future<OverlaySaveStatus> _executeFallback({
    required VaultPath path,
    required String text,
    required String baseHash,
  }) async {
    final HeadlessConfig? config;
    try {
      config = await _loadConfig();
    } catch (_) {
      return OverlaySaveStatus.requiresTephraToSave;
    }

    if (config == null || config.fsKind != 'io') {
      return OverlaySaveStatus.requiresTephraToSave;
    }

    final VaultFileSystem fs =
        fsFactory?.call(config.vaultRoot) ??
        IoVaultFileSystem(config.vaultRoot);

    try {
      final List<int> bytes;
      try {
        bytes = await fs.readBytes(path);
      } catch (_) {
        return OverlaySaveStatus.failed;
      }

      final doc = TextDocument.decode(bytes);
      final currentProtocolHash = stickyProtocolHash(doc.text);

      if (currentProtocolHash != baseHash) {
        // Hash mismatch: write conflict copy of own text
        final namer =
            conflictNamer ??
            (p) => VaultPath(
              '${p.parent != null ? '${p.parent!.value}/' : ''}${p.stem} (Conflict).${p.extension}',
            );
        final conflictPath = namer(path);
        await fs.writeText(conflictPath, TextDocument(text: text));
        return OverlaySaveStatus.savedConflictFallback;
      }

      final fileBytesHash = contentHash(bytes);
      final writer = StickyFileWriter(fs);
      final writtenHash = await writer.writeIfUnchanged(
        path,
        fileBytesHash,
        text,
      );

      if (writtenHash == null) {
        // Concurrent write between read and write: write conflict copy
        final namer =
            conflictNamer ??
            (p) => VaultPath(
              '${p.parent != null ? '${p.parent!.value}/' : ''}${p.stem} (Conflict).${p.extension}',
            );
        final conflictPath = namer(path);
        await fs.writeText(conflictPath, TextDocument(text: text));
        return OverlaySaveStatus.savedConflictFallback;
      }

      return OverlaySaveStatus.savedFallback;
    } finally {
      if (fsFactory == null) {
        await fs.dispose();
      }
    }
  }

  void dispose() {
    _ackTimer?.cancel();
    _ackTimer = null;
    if (_pendingSaveCompleter != null && !_pendingSaveCompleter!.isCompleted) {
      _pendingSaveCompleter!.complete(OverlaySaveStatus.failed);
    }
    _pendingSaveCompleter = null;
  }
}
