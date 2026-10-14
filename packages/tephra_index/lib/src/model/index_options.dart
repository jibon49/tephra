// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import 'model_helpers.dart';

/// Options configuring indexer behavior.
final class IndexOptions {
  const IndexOptions({this.excludedFolders = const [], this.batchSize = 200});

  /// Vault-relative folder paths to exclude from indexing.
  final List<String> excludedFolders;

  /// Batch size for bulk index insertions.
  final int batchSize;

  /// Returns true if [path] is within any excluded folder.
  bool isExcluded(VaultPath path) {
    for (final folder in excludedFolders) {
      if (folder.isEmpty) continue;
      if (path.isWithin(VaultPath(folder))) {
        return true;
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexOptions &&
          batchSize == other.batchSize &&
          listEquals(excludedFolders, other.excludedFolders);

  @override
  int get hashCode => Object.hash(batchSize, Object.hashAll(excludedFolders));

  @override
  String toString() =>
      'IndexOptions(batchSize: $batchSize, excluded: $excludedFolders)';
}
