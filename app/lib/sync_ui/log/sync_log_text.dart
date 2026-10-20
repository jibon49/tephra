// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';

import '../../l10n/app_localizations.dart';

/// Formatter that transforms [SyncLogEntry] events into localized human-readable sentences.
abstract final class SyncLogText {
  /// All 16 standard log kinds specified in Phase 3.
  static const List<String> allKinds = [
    'uploaded',
    'downloaded',
    'merged',
    'conflictCopy',
    'deletedLocal',
    'deletedRemote',
    'renamedLocal',
    'renamedRemote',
    'caseConflictRenamed',
    'invalidNameRenamed',
    'keptEditedFileDeletedElsewhere',
    'restoredDeletedFileChangedElsewhere',
    'republished',
    'heldDeletes',
    'deviceIdRenewed',
    'error',
  ];

  /// Translates [entry] into a single descriptive sentence using [l10n].
  static String describe(SyncLogEntry entry, AppLocalizations l10n) {
    final path = entry.path ?? '';
    final otherPath = entry.otherPath ?? '';
    final device = entry.deviceName;

    switch (entry.kind) {
      case 'uploaded':
        return l10n.syncLogUploaded(path);

      case 'downloaded':
        if (device != null && device.isNotEmpty) {
          return l10n.syncLogDownloaded(path, device);
        }
        return l10n.syncLogDownloadedNoDevice(path);

      case 'merged':
        if (device != null && device.isNotEmpty) {
          return l10n.syncLogMerged(path, device);
        }
        return l10n.syncLogMergedNoDevice(path);

      case 'conflictCopy':
        return l10n.syncLogConflictCopy(path, otherPath);

      case 'deletedLocal':
        if (device != null && device.isNotEmpty) {
          return l10n.syncLogDeletedLocal(path, device);
        }
        return l10n.syncLogDeletedLocalNoDevice(path);

      case 'deletedRemote':
        return l10n.syncLogDeletedRemote(path);

      case 'renamedLocal':
        return l10n.syncLogRenamedLocal(path, otherPath);

      case 'renamedRemote':
        if (device != null && device.isNotEmpty) {
          return l10n.syncLogRenamedRemote(path, otherPath, device);
        }
        return l10n.syncLogRenamedRemoteNoDevice(path, otherPath);

      case 'caseConflictRenamed':
        return l10n.syncLogCaseConflictRenamed(path, otherPath);

      case 'invalidNameRenamed':
        return l10n.syncLogInvalidNameRenamed(path, otherPath);

      case 'keptEditedFileDeletedElsewhere':
        return l10n.syncLogKeptEditedFileDeletedElsewhere(path);

      case 'restoredDeletedFileChangedElsewhere':
        return l10n.syncLogRestoredDeletedFileChangedElsewhere(path);

      case 'republished':
        return l10n.syncLogRepublished(path);

      case 'heldDeletes':
        final count =
            int.tryParse(entry.detail ?? '') ??
            (entry.path != null && entry.path!.isNotEmpty ? 1 : 0);
        return l10n.syncLogHeldDeletes(count > 0 ? count : 1);

      case 'deviceIdRenewed':
        return l10n.syncLogDeviceIdRenewed;

      case 'error':
        return l10n.syncLogError(entry.detail ?? path);

      default:
        return entry.detail ?? '${entry.kind}: $path';
    }
  }

  /// Whether [entry] represents a file content or structure change.
  static bool isChange(SyncLogEntry entry) {
    switch (entry.kind) {
      case 'uploaded':
      case 'downloaded':
      case 'merged':
      case 'conflictCopy':
      case 'deletedLocal':
      case 'deletedRemote':
      case 'renamedLocal':
      case 'renamedRemote':
      case 'republished':
      case 'caseConflictRenamed':
      case 'invalidNameRenamed':
      case 'keptEditedFileDeletedElsewhere':
      case 'restoredDeletedFileChangedElsewhere':
        return true;
      default:
        return false;
    }
  }

  /// Whether [entry] represents an issue, warning, or error.
  static bool isProblem(SyncLogEntry entry) {
    if (entry.level == 'error' || entry.level == 'warning') {
      return true;
    }
    switch (entry.kind) {
      case 'error':
      case 'caseConflictRenamed':
      case 'invalidNameRenamed':
      case 'heldDeletes':
      case 'conflictCopy':
        return true;
      default:
        return false;
    }
  }
}
