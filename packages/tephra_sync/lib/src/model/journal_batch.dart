// © 2026 Tephra. All rights reserved.

import '../errors/sync_exceptions.dart';
import 'journal_entry.dart';

/// Represents a contiguous batch of journal entries written by one device.
final class JournalBatch {
  /// Creates a [JournalBatch].
  JournalBatch({
    this.version = currentVersion,
    required this.deviceId,
    required this.firstSeq,
    required this.lastSeq,
    required this.createdAt,
    required this.entries,
  }) {
    if (entries.isEmpty) {
      throw ArgumentError.value(
        entries,
        'entries',
        'Batch entries cannot be empty',
      );
    }
    if (entries.length > maxEntriesPerBatch) {
      throw ArgumentError.value(
        entries.length,
        'entries.length',
        'Batch entries cannot exceed $maxEntriesPerBatch',
      );
    }
    if (entries.first.seq != firstSeq || entries.last.seq != lastSeq) {
      throw ArgumentError(
        'firstSeq ($firstSeq) and lastSeq ($lastSeq) must match entries range '
        '(${entries.first.seq}..${entries.last.seq})',
      );
    }
    for (var i = 0; i < entries.length; i++) {
      final expectedSeq = firstSeq + i;
      if (entries[i].seq != expectedSeq) {
        throw ArgumentError(
          'Non-contiguous sequence at index $i: expected $expectedSeq but found ${entries[i].seq}',
        );
      }
    }
  }

  /// Parses a [JournalBatch] from JSON map.
  factory JournalBatch.fromJson(Map<String, Object?> json) {
    final v = (json['v'] as num?)?.toInt();
    if (v == null || v != currentVersion) {
      throw RemoteFormatException(
        'Unsupported journal batch format version: $v',
      );
    }

    final deviceId = json['deviceId'] as String?;
    final firstSeq = (json['firstSeq'] as num?)?.toInt();
    final lastSeq = (json['lastSeq'] as num?)?.toInt();
    final createdAtStr = json['createdAt'] as String?;
    final rawEntries = json['entries'] as List<Object?>?;

    if (deviceId == null ||
        firstSeq == null ||
        lastSeq == null ||
        createdAtStr == null ||
        rawEntries == null) {
      throw const RemoteFormatException(
        'Missing required field in journal batch',
      );
    }

    final entries = <JournalEntry>[];
    for (final raw in rawEntries) {
      if (raw is! Map) {
        throw const RemoteFormatException(
          'Journal entry must be a JSON object',
        );
      }
      entries.add(
        JournalEntry.fromJson(
          raw.cast<String, Object?>(),
          defaultDeviceId: deviceId,
        ),
      );
    }

    return JournalBatch(
      version: v,
      deviceId: deviceId,
      firstSeq: firstSeq,
      lastSeq: lastSeq,
      createdAt: DateTime.parse(createdAtStr).toUtc(),
      entries: entries,
    );
  }

  /// Current format version (1).
  static const int currentVersion = 1;

  /// Maximum allowed mutations per batch (1,000).
  static const int maxEntriesPerBatch = 1000;

  /// Batch format version.
  final int version;

  /// UUID of the device that authored this batch.
  final String deviceId;

  /// Starting sequence number of the batch.
  final int firstSeq;

  /// Ending sequence number of the batch.
  final int lastSeq;

  /// UTC timestamp when the batch was sealed.
  final DateTime createdAt;

  /// Contiguous journal mutations.
  final List<JournalEntry> entries;

  /// Serializes this batch to a JSON map.
  Map<String, Object?> toJson() => {
    'v': version,
    'deviceId': deviceId,
    'firstSeq': firstSeq,
    'lastSeq': lastSeq,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalBatch &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          deviceId == other.deviceId &&
          firstSeq == other.firstSeq &&
          lastSeq == other.lastSeq &&
          createdAt == other.createdAt &&
          _entriesEqual(entries, other.entries);

  @override
  int get hashCode => Object.hash(
    version,
    deviceId,
    firstSeq,
    lastSeq,
    createdAt,
    Object.hashAll(entries),
  );

  @override
  String toString() =>
      'JournalBatch(device: $deviceId, range: $firstSeq..$lastSeq, count: ${entries.length})';

  static bool _entriesEqual(List<JournalEntry> a, List<JournalEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
