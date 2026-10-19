// © 2026 Tephra. All rights reserved.

/// Device-local rules for skipping specific folders, extensions, or large files.
final class SelectiveSyncRules {
  /// Creates a [SelectiveSyncRules] configuration.
  const SelectiveSyncRules({
    this.excludedFolders = const [],
    this.excludedExtensions = const {},
    this.maxFileSizeBytes = defaultMaxFileSizeBytes,
    this.mobileMode = false,
  });

  /// Decodes [SelectiveSyncRules] from a JSON map.
  factory SelectiveSyncRules.fromJson(Map<String, Object?> json) {
    return SelectiveSyncRules(
      excludedFolders:
          (json['excludedFolders'] as List<Object?>?)?.cast<String>() ??
          const [],
      excludedExtensions:
          (json['excludedExtensions'] as List<Object?>?)
              ?.map(
                (e) =>
                    (e as String).toLowerCase().replaceAll(RegExp(r'^\.'), ''),
              )
              .toSet() ??
          const {},
      maxFileSizeBytes:
          (json['maxFileSizeBytes'] as num?)?.toInt() ??
          defaultMaxFileSizeBytes,
      mobileMode: json['mobileMode'] as bool? ?? false,
    );
  }

  /// Default file size limit (100 MiB = 104,857,600 bytes).
  static const int defaultMaxFileSizeBytes = 104857600;

  /// Video file extensions excluded automatically when [mobileMode] is true.
  static const Set<String> mobileExtensions = {
    'mp4',
    'mov',
    'mkv',
    'avi',
    'webm',
    'm4v',
    '3gp',
    'wmv',
    'flv',
  };

  /// Vault-relative paths of folders to exclude from sync.
  final List<String> excludedFolders;

  /// Lower-case file extensions without leading dot to exclude from sync.
  final Set<String> excludedExtensions;

  /// Maximum file size in bytes to synchronize (files exceeding this are skipped).
  final int maxFileSizeBytes;

  /// When true, adds [mobileExtensions] to excluded extensions to save bandwidth.
  final bool mobileMode;

  /// Union of configured [excludedExtensions] and [mobileExtensions] if [mobileMode] is active.
  Set<String> get effectiveExcludedExtensions {
    if (!mobileMode) return excludedExtensions;
    return {...excludedExtensions, ...mobileExtensions};
  }

  /// Determines whether a file at [vaultPath] with [sizeBytes] is excluded by these rules.
  bool isExcluded(String vaultPath, int sizeBytes) {
    if (sizeBytes > maxFileSizeBytes) {
      return true;
    }

    // Check folder exclusions
    for (final folder in excludedFolders) {
      final normFolder = folder.replaceAll(RegExp(r'/+$'), '');
      if (normFolder.isEmpty) continue;
      if (vaultPath == normFolder || vaultPath.startsWith('$normFolder/')) {
        return true;
      }
    }

    // Check extension exclusions
    final lastDot = vaultPath.lastIndexOf('.');
    if (lastDot != -1 && lastDot < vaultPath.length - 1) {
      final ext = vaultPath.substring(lastDot + 1).toLowerCase();
      if (effectiveExcludedExtensions.contains(ext)) {
        return true;
      }
    }

    return false;
  }

  /// Encodes these rules to a JSON map.
  Map<String, Object?> toJson() => {
    'excludedFolders': excludedFolders,
    'excludedExtensions': excludedExtensions.toList()..sort(),
    'maxFileSizeBytes': maxFileSizeBytes,
    'mobileMode': mobileMode,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectiveSyncRules &&
          runtimeType == other.runtimeType &&
          maxFileSizeBytes == other.maxFileSizeBytes &&
          mobileMode == other.mobileMode &&
          _listEquals(excludedFolders, other.excludedFolders) &&
          _setEquals(excludedExtensions, other.excludedExtensions);

  @override
  int get hashCode => Object.hash(
    maxFileSizeBytes,
    mobileMode,
    Object.hashAll(excludedFolders),
    Object.hashAll(excludedExtensions),
  );

  @override
  String toString() =>
      'SelectiveSyncRules(folders: ${excludedFolders.length}, exts: ${excludedExtensions.length}, maxBytes: $maxFileSizeBytes, mobile: $mobileMode)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
