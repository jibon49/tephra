// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Read-only interface for resolving link targets against in-memory paths and aliases.
abstract interface class LinkTargetLookup {
  /// Lookup by exact vault path, lower-case (caseKey).
  VaultPath? byCaseKey(String k);

  /// Lookup all files whose name.toLowerCase() == [k].
  List<VaultPath> byNameKey(String k);

  /// Lookup all notes having an alias whose toLowerCase() == [k].
  List<VaultPath> byAliasKey(String k);
}

/// In-memory lookup of every vault file and alias.
final class NameTable implements LinkTargetLookup {
  NameTable();

  /// Create a [NameTable] populated with [files] and [aliases].
  factory NameTable.from(
    Iterable<VaultPath> files,
    Map<VaultPath, List<String>> aliases,
  ) {
    final table = NameTable();
    for (final f in files) {
      table.addFile(f);
    }
    for (final entry in aliases.entries) {
      table.setAliases(entry.key, entry.value);
    }
    return table;
  }

  final Set<VaultPath> _files = <VaultPath>{};
  final Map<String, VaultPath> _byCase = <String, VaultPath>{};
  final Map<String, Set<VaultPath>> _caseGroups = <String, Set<VaultPath>>{};
  final Map<String, Set<VaultPath>> _byName = <String, Set<VaultPath>>{};
  final Map<String, Set<VaultPath>> _byAlias = <String, Set<VaultPath>>{};
  final Map<VaultPath, List<String>> _aliasesOf = <VaultPath, List<String>>{};

  /// All tracked vault files.
  Iterable<VaultPath> get files => _files;

  /// Add a file to the table.
  void addFile(VaultPath path) {
    if (!_files.add(path)) return;

    final caseKey = path.caseKey;
    final group = _caseGroups.putIfAbsent(caseKey, () => <VaultPath>{});
    group.add(path);
    _updateBestCase(caseKey);

    final nameKey = path.name.toLowerCase();
    _byName.putIfAbsent(nameKey, () => <VaultPath>{}).add(path);
  }

  /// Remove a file and its aliases from the table.
  void removeFile(VaultPath path) {
    if (!_files.remove(path)) return;

    setAliases(path, const []);

    final caseKey = path.caseKey;
    final group = _caseGroups[caseKey];
    if (group != null) {
      group.remove(path);
      if (group.isEmpty) {
        _caseGroups.remove(caseKey);
        _byCase.remove(caseKey);
      } else {
        _updateBestCase(caseKey);
      }
    }

    final nameKey = path.name.toLowerCase();
    final nameGroup = _byName[nameKey];
    if (nameGroup != null) {
      nameGroup.remove(path);
      if (nameGroup.isEmpty) {
        _byName.remove(nameKey);
      }
    }
  }

  void _updateBestCase(String caseKey) {
    final group = _caseGroups[caseKey];
    if (group == null || group.isEmpty) {
      _byCase.remove(caseKey);
      return;
    }
    var best = group.first;
    for (final candidate in group) {
      if (candidate.value.compareTo(best.value) < 0) {
        best = candidate;
      }
    }
    _byCase[caseKey] = best;
  }

  /// Set aliases for [note], replacing any existing aliases.
  void setAliases(VaultPath note, List<String> aliases) {
    final oldAliases = _aliasesOf.remove(note);
    if (oldAliases != null) {
      for (final a in oldAliases) {
        final key = a.toLowerCase();
        final group = _byAlias[key];
        if (group != null) {
          group.remove(note);
          if (group.isEmpty) {
            _byAlias.remove(key);
          }
        }
      }
    }

    if (aliases.isEmpty) return;

    final cleaned = List<String>.unmodifiable(aliases);
    _aliasesOf[note] = cleaned;
    for (final a in cleaned) {
      final key = a.toLowerCase();
      _byAlias.putIfAbsent(key, () => <VaultPath>{}).add(note);
    }
  }

  /// Returns the aliases registered for [note], or an empty list if none.
  List<String> aliasesOf(VaultPath note) =>
      _aliasesOf[note] ?? const <String>[];

  @override
  VaultPath? byCaseKey(String caseKey) => _byCase[caseKey];

  @override
  List<VaultPath> byNameKey(String nameKey) =>
      _byName[nameKey]?.toList() ?? const <VaultPath>[];

  @override
  List<VaultPath> byAliasKey(String aliasKey) =>
      _byAlias[aliasKey]?.toList() ?? const <VaultPath>[];

  /// Deep copy used to simulate renames or what-if resolution.
  NameTable copy() {
    final table = NameTable();
    table._files.addAll(_files);
    table._byCase.addAll(_byCase);
    for (final entry in _caseGroups.entries) {
      table._caseGroups[entry.key] = Set<VaultPath>.from(entry.value);
    }
    for (final entry in _byName.entries) {
      table._byName[entry.key] = Set<VaultPath>.from(entry.value);
    }
    for (final entry in _byAlias.entries) {
      table._byAlias[entry.key] = Set<VaultPath>.from(entry.value);
    }
    for (final entry in _aliasesOf.entries) {
      table._aliasesOf[entry.key] = List<String>.from(entry.value);
    }
    return table;
  }
}
