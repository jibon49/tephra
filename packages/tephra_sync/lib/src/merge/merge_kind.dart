// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../local/sync_path_rules.dart';

/// The kind of content for merging purposes.
enum MergeKind {
  /// Markdown notes (.md), supports frontmatter-aware three-way merge.
  markdown,

  /// Plain text files (.txt), supports three-way line-level merge.
  plainText,

  /// Synced Tephra configuration files (.tephra/*.json), key-wise JSON merge.
  jsonObject,

  /// Binary or non-mergeable files (canvas, pdf, images, etc.). Always conflicts on concurrent edit.
  binary,
}

/// Determines the [MergeKind] for a given [path].
MergeKind kindOf(VaultPath path) {
  if (path.extension == 'md') {
    return MergeKind.markdown;
  }
  if (path.extension == 'txt') {
    return MergeKind.plainText;
  }
  if (SyncPathRules.syncedTephraFiles.contains(path.value)) {
    return MergeKind.jsonObject;
  }
  return MergeKind.binary;
}
