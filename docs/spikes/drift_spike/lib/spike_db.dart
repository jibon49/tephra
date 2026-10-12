// © 2026 Tephra. All rights reserved.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

class SpikeDb extends GeneratedDatabase {
  SpikeDb(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

SpikeDb openSpikeDb() {
  return SpikeDb(driftDatabase(name: 'fts_spike'));
}
