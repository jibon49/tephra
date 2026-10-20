// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Major phases of a synchronization cycle.
enum SyncProgressPhase {
  refreshing,
  scanning,
  planning,
  applying,
  uploading,
  committing,
  done,
}

/// Progress notification emitted during synchronization.
final class SyncProgress {
  const SyncProgress({
    required this.phase,
    this.filesDone = 0,
    this.filesTotal = 0,
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.currentPath,
  });

  final SyncProgressPhase phase;
  final int filesDone;
  final int filesTotal;
  final int bytesDone;
  final int bytesTotal;
  final VaultPath? currentPath;

  @override
  String toString() =>
      'SyncProgress($phase, files: $filesDone/$filesTotal, bytes: $bytesDone/$bytesTotal${currentPath != null ? ', ${currentPath!.value}' : ''})';
}
