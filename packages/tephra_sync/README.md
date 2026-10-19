# tephra_sync

Encrypted, conflict-free sync, version history, and backup engine for Tephra.

Provides pure-Dart synchronization behind the `SyncProvider` contract, enabling end-to-end encrypted vault sync across devices via Google Drive or Tephra Cloud with per-note version history and deduplicated backups.

## Architecture

- `lib/src/backup/`: Backup manifests, retention policies, verification, and restore operations.
- `lib/src/crypto/`: Argon2id key derivation, AES-256-GCM key wrapping, HKDF object envelopes, and recovery keys.
- `lib/src/db/`: Sync state database (Drift/SQLite) tracking synced heads, leases, and local revisions.
- `lib/src/engine/`: Sync coordinator, cycle state machine, lock acquisition, and error handling.
- `lib/src/errors/`: Typed sync and cryptographic exception hierarchy.
- `lib/src/executor/`: Atomic, crash-safe execution of planned local and remote file operations.
- `lib/src/fastcdc/`: FastCDC content-defined chunking and immutable content-addressed blob storage.
- `lib/src/history/`: Hybrid logical clocks (HLC), append-only journals, snapshots, and compaction.
- `lib/src/local/`: Local vault scanner, selective sync filtering, and case-sensitivity detection.
- `lib/src/merge/`: Three-way frontmatter-aware Markdown merge and `.tephra/*.json` key-wise merge.
- `lib/src/planner/`: Pure decision table planner handling puts, deletes, moves, and conflict resolution.
- `lib/src/provider/`: `SyncProvider` abstraction, in-memory implementation, and Google Drive client.
- `lib/src/remote/`: Remote storage layout definitions, key builders, and key parsers.
