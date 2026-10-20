// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../local/local_file_state.dart';
import '../model/base_state.dart';
import '../remote/remote_history.dart';

/// Local synchronization status for a path.
enum LocalStatus {
  /// L0: no local file, no base record.
  l0,

  /// L=: local file matches base record.
  lEq,

  /// LM: local file modified relative to base record.
  lMod,

  /// LC: local file created, no base record.
  lCreate,

  /// LD: local file deleted, base record present.
  lDelete,
}

/// Remote synchronization status for a path.
enum RemoteStatus {
  /// R0: remote head absent, or deleted and no base record.
  r0,

  /// Rgone: remote head absent and base record present.
  rGone,

  /// RC: remote file created, no base record.
  rCreate,

  /// R=: remote head matches base record or is unchanged ancestor.
  rEq,

  /// RM: remote head modified relative to base record.
  rMod,

  /// RD: remote file deleted, base record present, causally after base.
  rDel,

  /// RF+: concurrent remote creation/modification (fork) relative to base.
  rForkPlus,

  /// RF-: concurrent remote deletion (fork) relative to base.
  rForkMinus,
}

/// Helper functions for classifying local and remote states of vault paths.
abstract final class StatusClassifier {
  /// Computes the [LocalStatus] for [path].
  static LocalStatus classifyLocal(
    VaultPath path,
    Map<VaultPath, LocalFileState> local,
    Map<VaultPath, BaseState> base,
  ) {
    final l = local[path];
    final b = base[path];

    if (l == null && b == null) return LocalStatus.l0;
    if (l != null && b == null) return LocalStatus.lCreate;
    if (l == null && b != null) return LocalStatus.lDelete;

    return l!.hash == b!.hash ? LocalStatus.lEq : LocalStatus.lMod;
  }

  /// Computes the [RemoteStatus] for [path].
  static RemoteStatus classifyRemote(
    VaultPath path,
    BaseState? b,
    RemoteHistory remote,
  ) {
    final h = remote.head(path.value);
    final isPresent = h != null && RemoteHistory.isPresentAt(h, path.value);

    if (b == null) {
      return isPresent ? RemoteStatus.rCreate : RemoteStatus.r0;
    }

    if (h == null) return RemoteStatus.rGone;

    final isAnc =
        h.entryId == b.version ||
        remote.isAncestorOrEqual(b.version, h.entryId, path.value);

    if (isAnc) {
      if (isPresent) {
        return (h.entryId == b.version || h.hash == b.hash)
            ? RemoteStatus.rEq
            : RemoteStatus.rMod;
      } else {
        return RemoteStatus.rDel;
      }
    } else {
      return isPresent ? RemoteStatus.rForkPlus : RemoteStatus.rForkMinus;
    }
  }
}
