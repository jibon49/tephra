# Tephra Sync Format v1 — Frozen Specification

This document freezes the remote wire and storage format for **Tephra Sync v1** (Google Drive and future Tephra Cloud backends).
Format details documented here are frozen and must not be altered without incrementing `formatVersion` to 2 accompanied by a full migration plan.

---

## 1. Remote Key Layout (03.2)

Key builders and parsers are encapsulated in `RemoteLayout`.

| Key | Builder | Content | Written by |
|---|---|---|---|
| `vault.json` | `RemoteLayout.vaultHeader` | public header, plain JSON | the creating device; later replaced only on password change |
| `blobs/<64 hex>` | `blob(String sha256Hex)` | file content (envelope); hex = SHA-256 of the **stored bytes** | any device; immutable |
| `journals/<deviceId>/<10-digit firstSeq>.json.enc` | `journal(deviceId, firstSeq)` | one batch of entries | only that device; never replaced |
| `snapshots/<deviceId>/<10-digit seq>.json.enc` | `snapshot(deviceId, seq)` | compacted state | only that device |
| `backups/<yyyyMMddTHHmmssZ>/manifest.json.enc` | `backupManifest(DateTime utc)` | backup manifest | the backing-up device; never replaced |
| `devices/<deviceId>.json.enc` | `deviceInfo(deviceId)` | device name/platform | only that device (replaced at most hourly) |
| `devices/<deviceId>.revoked.json.enc` | `deviceRevocation(deviceId)` | revocation record | the revoking device; written once |
| `locks/gc-<deviceId>.json.enc` | `gcLease(deviceId)` | GC lease | only that device |
| `locks/gc-state.json.enc` | `gcState` | GC candidate list | only the current GC lease holder |

Device ids are lower-case UUID v4 strings (36 chars). `firstSeq`/`seq` are zero-padded to 10 digits (`seq.toString().padLeft(10, '0')`).
Parsers: `RemoteLayout.parse(String key)` returns a sealed `RemoteKey` (`VaultHeaderKey`, `BlobKey(hash)`, `JournalKey(deviceId, firstSeq)`, `SnapshotKey(deviceId, seq)`, `BackupManifestKey(DateTime)`, `DeviceInfoKey(deviceId)`, `DeviceRevocationKey(deviceId)`, `GcLeaseKey(deviceId)`, `GcStateKey`, `UnknownKey(key)`). Unknown keys are ignored by every reader (forward compatibility).

### Why per-device append-only journals
Google Drive has no reliable compare-and-swap. If two devices rewrote one shared manifest, one write would silently overwrite the other. In this layout every mutable object has exactly one writer (its device id is in the name), blobs are immutable and named by their hash, and journal file names are unique (device id + sequence number). Two devices can therefore never overwrite each other's data, whatever order Drive applies writes in.

---

## 2. Cryptography: KDF, Master Key, Key Wrap, Envelope, Recovery Key (03.4)

### Cryptographic Primitives
- Argon2id
- HKDF-HMAC-SHA256 (`Hkdf(hmac: Hmac.sha256(), outputLength: 32)`)
- AES-256-GCM (`AesGcm.with256bits()`)
- HMAC-SHA256
- SHA-256

### KDF Parameters (`KdfParams`)
- Floor parameters (never lower): `memoryKiB = 65536` (64 MiB), `iterations = 3`, `parallelism = 1`, hash length 32 bytes.
- Algorithm: `Argon2id(parallelism: p, memory: memoryKiB, iterations: t, hashLength: 32)` then `deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt)` -> password KEK (32 bytes).
- Calibration (`KdfCalibrator.calibrate({required bool isAndroid})`):
  - On Windows: return the floor without measuring.
  - On Android: start at floor; double memoryKiB while `< 350 ms` and `< 131072`; then increment iterations while `< 350 ms` and `< 4`.

### Master Key
32 random bytes generated once per remote vault. Never uploaded in clear, never logged.

### Key Wrapping
`WrappedKey { alg = 'aes-256-gcm', nonce (12 random bytes), ciphertext (32-byte master key encrypted, followed by the 16-byte tag = 48 bytes) }`.
AAD = UTF-8 of `tephra-wrap-v1|<vaultId>|password` or `tephra-wrap-v1|<vaultId>|recovery`.
Unwrap failure (tag mismatch) -> `WrongPasswordException` / `WrongRecoveryKeyException`.

### Recovery Key
16 random bytes `r`. Checksum `c` = first 4 bytes of SHA-256(`r`).
Display string = RFC 4648 base32 (alphabet `A-Z2-7`, no padding) of the 20 bytes `r || c` = exactly 32 characters, formatted as 8 groups of 4 separated by hyphens (`XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX`).
Recovery KEK = HKDF-SHA256(ikm = `r`, salt = `recoverySalt` (16 random bytes stored in `vault.json`), info = UTF-8 `tephra/v1/recovery-kek`, length 32).

### Object Purposes (`ObjectPurpose`)

| Purpose | Code | HKDF info | Used for |
|---|---|---|---|
| `blob` | 1 | `tephra/v1/blob` | file content chunks |
| `journal` | 2 | `tephra/v1/journal` | journal batches |
| `snapshot` | 3 | `tephra/v1/snapshot` | snapshots |
| `manifest` | 4 | `tephra/v1/manifest` | backup manifests |
| `device` | 5 | `tephra/v1/device` | device info + revocation files |
| `lock` | 6 | `tephra/v1/lock` | GC leases |
| `gcState` | 7 | `tephra/v1/gc-state` | GC state |

### Object Envelope (`TPH1`)

| Offset | Length | Field |
|---|---|---|
| 0 | 4 | magic ASCII `TPH1` = `0x54 0x50 0x48 0x31` |
| 4 | 1 | envelope version = `0x01` |
| 5 | 1 | purpose code (table above) |
| 6 | 16 | object salt (random) |
| 22 | 12 | AES-GCM nonce (random 96 bits) |
| 34 | n | ciphertext (same length as plaintext) |
| 34+n | 16 | GCM tag |

Object key = HKDF-SHA256(ikm = master key, salt = object salt, info = purpose info string, length 32). Fresh salt per object ensures nonce uniqueness.
AAD = 34 header bytes followed by UTF-8 of the remote vault ID.
Decryption checks magic -> version -> purpose -> GCM tag.

---

## 3. FastCDC Chunking (03.5)

Chunking rule (recorded in `vault.json` as `"chunking": {"alg": "fastcdc-gear32-v1", "min": 262144, "avg": 1048576, "max": 4194304, "singleBlobMax": 4194304}`):
- Files of **<= 4 MiB** (4,194,304 bytes) -> exactly one chunk (the whole file).
- Larger files -> FastCDC with min 256 KiB, average 1 MiB, max 4 MiB (normalised chunking level 2).

FastCDC "gear32" specification:
- Gear table: 256 unsigned 32-bit values; `gear[i]` = first 4 bytes (big-endian) of SHA-256 of `tephra-gear-v1-<i>` (`i` in decimal).
- Rolling hash `h` (32-bit): for each byte `b`: `h = ((h << 1) + gear[b]) & 0xFFFFFFFF`.
- Masks: `maskS = 0xFFFFFC00` (top 22 bits set, used before average point); `maskL = 0xFFFFC000` (top 18 bits set, used after average point).
- For each chunk starting at offset `s`: skip first `min` bytes; for positions up to `s + avg` cut when `(h & maskS) == 0`; after that up to `s + max` cut when `(h & maskL) == 0`; force cut at `s + max`. Reset `h = 0` at chunk start.

---

## 4. Remote Vault Header `vault.json` (03.6)

Plain JSON, UTF-8, formatted with 2 spaces:
```json
{
  "format": "tephra-remote",
  "formatVersion": 1,
  "vaultId": "6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11",
  "vaultName": "My Vault",
  "createdAt": "2026-10-11T09:30:00.000Z",
  "createdBy": { "deviceId": "...uuid...", "deviceName": "Office PC" },
  "updatedAt": "2026-10-11T09:30:00.000Z",
  "encryption": "aes-256-gcm",
  "kdf": {
    "alg": "argon2id",
    "version": 19,
    "memoryKiB": 65536,
    "iterations": 3,
    "parallelism": 1,
    "salt": "<base64 16 bytes>",
    "calibratedMs": 0
  },
  "wrappedKeys": {
    "password": { "alg": "aes-256-gcm", "nonce": "<base64 12>", "ciphertext": "<base64 48>" },
    "recovery": { "alg": "aes-256-gcm", "nonce": "<base64 12>", "ciphertext": "<base64 48>", "salt": "<base64 16>" }
  },
  "chunking": {
    "alg": "fastcdc-gear32-v1",
    "min": 262144,
    "avg": 1048576,
    "max": 4194304,
    "singleBlobMax": 4194304
  }
}
```
With encryption off: `"encryption": "none"` and no `kdf` or `wrappedKeys` fields.
`vault.json` is written last during remote vault creation.

---

## 5. HLC, Journal Entries, Batches, and Snapshots (03.7)

### Hybrid Logical Clock (`Hlc`)
- Ordered by `(millis, counter, deviceId)`.
- Format: `millis` (15 digits zero-padded) + `.` + `counter` (6 digits zero-padded) + `.` + `deviceId`.
- Local event `tick()`: `l2 = max(l, physicalNow)`; `c2 = (l2 == l) ? c + 1 : 0`.
- Remote receive `observe(Hlc m)`: `l2 = max(l, m.millis, physicalNow)`; `c2 = (l2 == l && l2 == m.millis) ? max(c, m.counter) + 1 : (l2 == l) ? c + 1 : (l2 == m.millis) ? m.counter + 1 : 0`.

### Journal Entry (`JournalEntry`)
Entry ID = `<deviceId>:<seq>`.
```json
{
  "seq": 41,
  "hlc": "001760175000000.000003.<deviceId>",
  "time": "2026-10-11T09:30:00.000Z",
  "op": "put",
  "path": "Folder/Note.md",
  "fromPath": null,
  "hash": "<sha256 hex of plaintext>",
  "size": 1234,
  "mtime": 1760175000000,
  "blobKeys": ["blobs/<hex>"],
  "parent": "<entryId or null>",
  "targetParent": null,
  "mergedParent": null
}
```
- `op: "put"`: `parent` = head seen by writer.
- `op: "delete"`: `hash`/`blobKeys` = deleted version content; `parent` = head at path.
- `op: "move"`: `parent` = head at `fromPath`; `targetParent` = head at `path` (if existed).
- `mergedParent`: second parent entry ID merged during 3-way merge conflict resolution.

### Journal Batch
Stored as `journals/<deviceId>/<10-digit firstSeq>.json.enc` (purpose `journal`):
`{"v":1,"deviceId":"...","firstSeq":41,"lastSeq":57,"createdAt":"...","entries":[...]}`.
Contiguous sequence numbers `firstSeq..lastSeq`, maximum 1,000 entries per batch.

### Snapshot (Compaction)
Stored as `snapshots/<deviceId>/<10-digit seq>.json.enc` (purpose `snapshot`, content = gzip of UTF-8 JSON):
`{"v":1,"deviceId":"...","seq":1500,"createdAt":"...","hlc":"...","covers":{"<deviceId>":<lastSeq read>,...},"entries":[...]}`.
Entries contain all leaves for every path, plus lowest common ancestors for forked paths.

---

## 6. Backup Manifests (03.22)

Stored as `backups/<yyyyMMddTHHmmssZ>/manifest.json.enc` (purpose `manifest`, content = gzip of UTF-8 JSON):
```json
{
  "v": 1,
  "vaultId": "...",
  "createdAt": "2026-10-20T12:00:00.000Z",
  "deviceId": "...",
  "deviceName": "PC",
  "kind": "scheduled",
  "fileCount": 100,
  "totalBytes": 1024000,
  "files": [
    {
      "path": "folder/note.md",
      "hash": "<sha256 hex of plaintext>",
      "size": 1024,
      "mtime": 1760175000000,
      "blobKeys": ["blobs/<hex>"]
    }
  ]
}
```
`files` array is deterministically sorted by `path` string. Written last during backup.

---

## 7. Distributed GC Lease and GC State (03.23)

### Lease (`locks/gc-<deviceId>.json.enc`)
Purpose `lock`:
`{"v":1,"deviceId":"...","hlc":"...","createdAt":"..."}`.
Winner is the smallest `(hlc, deviceId)` among leases modified within 30 minutes of this device's lease.

### GC State (`locks/gc-state.json.enc`)
Purpose `gcState`:
`{"v":1,"updatedAt":"...","candidates":{"blobs/<hex>":"<firstSeenUnreferencedAt ISO>"}}`.
Two-phase sweep requires unreferenced blobs to be older than 7 days server creation time, recorded as candidates, and remaining unreferenced for at least 24 hours before deletion.

---

## 8. Google Drive Folder Mapping (03.15)

- Root structure: `My Drive/Tephra/` (`appProperties: {tephraKind: 'root'}`) -> `<vault name>/` (`appProperties: {tephraKind: 'vault', tephraVaultId: '<id>'}`).
- Vault sub-folders: `blobs`, `journals`, `snapshots`, `backups`, `devices`, `locks`.
- Device-specific sub-folders: `journals/<deviceId>`, `snapshots/<deviceId>`.
- Backup-specific sub-folders: `backups/<stamp>`.
- File object names: last segment of remote key (e.g. `0000000041.json.enc`).
- Property tags: `appProperties: {tephraKey: '<full key>'}` when key <= 100 characters.
- Deletions: always move to Drive trash (`files.update(trashed = true)`), never permanent hard delete.

---

## 9. Compatibility Rules

1. **Unknown JSON fields**: Readers MUST ignore unknown JSON fields in any message or metadata document (forward compatibility).
2. **Unknown remote keys**: Readers MUST ignore unknown key paths returned by `provider.list()` (parsers return `UnknownKey(key)`).
3. **Wire format changes**: Any breaking change to bytes on the wire, encryption envelopes, key layout, or semantics requires incrementing `formatVersion` to 2 and providing a documented migration path.
