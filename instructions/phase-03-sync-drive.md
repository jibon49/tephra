# Phase 03 — Sync & backup via Google Drive (Beta)

> **Duration:** 5 weeks (one full-time developer, ~15% buffer included).
> **Goal:** the same vault on an Android phone and a Windows PC, kept in sync through the user's **own Google Drive**
> (scope `drive.file`, visible folder `Tephra/<vault name>/`), end-to-end encrypted, with per-note version history,
> scheduled deduplicated backups and a restore UI. The sync core is pure Dart behind the `SyncProvider` interface
> (conventions §7.6) so that Phase 10 (Tephra Cloud) adds a provider and a server, **not** a new engine or a new remote format.
>
> **The rule of this phase: no code path may lose user data.** When any step leaves you unsure, keep both copies.

Read this whole file once before starting step 03.1. Then do the steps strictly in order. Every step ends with the standard
GEMINI.md §3 loop (format, analyze, tests of touched packages, tick `PROGRESS.md`, commit `phase 03.N: <summary>`).

Words used in this file:

| Word | Meaning |
|---|---|
| **local** | the files in the vault folder on this device |
| **remote** | the objects stored through a `SyncProvider` (Google Drive in this phase) |
| **base** | what this device last synced for a path (hash, version id, and for text files the text itself) |
| **entry** | one record in a device journal (`put`, `delete` or `move` of one path) |
| **head** | the entry that currently defines a path's remote state |
| **leaf** | an entry that no other entry names as its parent (normally exactly one per path) |
| **fork** | a path that has more than one leaf (two devices wrote without seeing each other) |
| **blob** | an immutable, content-addressed remote object holding (encrypted) file bytes |
| **key** | an opaque remote object name such as `blobs/9f86d0…` (never a crypto key; crypto keys are always called "master key", "KEK", "object key") |

---

## Before you start

### Prerequisite gate (all must be true; check each, write the result in `PROGRESS.md`)

1. `PROGRESS.md` shows the Phase 2 exit gate fully checked, and `git tag` lists `v0.02.0`.
2. You are on `main`, the working tree is clean (`git status` prints "nothing to commit"). Create the branch: `git checkout -b phase-03`.
3. `flutter analyze --fatal-infos` reports 0 issues and `dart test` passes in every package; `flutter test` passes in `app/`.
4. `dart run tool/check_licenses.dart` passes.
5. The human has completed **every** item of "Human prerequisites" below and the file `secrets/google_oauth.json` exists
   (you check this at step 03.13, not now — steps 03.1–03.12 need no Google account).

### What already exists (from Phases 0–2) and what you rely on

You did not write the earlier phase files in this session, so **look at the real code** before using something. For each item
below, find it with `Select-String -Path packages,app -Pattern '<name>' -Recurse` (PowerShell) or the Grep tool, and read its file.

| Thing | Where | Used by this phase for |
|---|---|---|
| `VaultPath`, `TephraException`, `SyncException`, `CryptoException`, `Clock`, `SystemClock`, `contentHash` | `packages/tephra_core` (conventions §7.1) | everything |
| `VaultFileSystem`, `IoVaultFileSystem`, `MemoryVaultFileSystem`, `TextDocument`, `TrashMode`, `VaultChange` | `packages/tephra_vault` (conventions §7.2) | local scan, atomic writes, trash |
| Empty `packages/tephra_sync` package (pubspec + README + `lib/tephra_sync.dart`) | created in Phase 0 | filled in this phase |
| drift + sqlite set-up for pure-Dart tests and for the app | `packages/tephra_index` (Phase 2) | copy the **same** approach for the sync state DB (same drift version, same way of loading SQLite in `dart test`, same code-generation choice, same web stub) |
| App-level settings with **device id** and **device name** (`<appSupportDir>/settings.json`, conventions §6.6) | `app/lib/core/` | default device identity |
| Platform interfaces `TrayService`, `WindowService`, `NotificationService` (conventions §5.9) | `app/lib/core/platform/` | tray status, keep-running-when-closed |
| Desktop status bar and phone app bar | `app/lib/workspace/` | sync status indicator |
| Editor autosave hook (debounced ~1 s save) | `app/lib/editor/` | save trigger + 10-minute local history snapshots |
| Command registry (conventions §7.8) | `app/lib/commands/` | sync commands |
| Settings screens | `app/lib/settings/` | "Sync & backup" section |
| A `CancelToken` class (conventions §7.5 mentions it) | search `packages/tephra_core/lib` for `class CancelToken` | cancelling a sync. If it does not exist, create `SyncCancelToken` in `tephra_sync` (step 03.11) |
| A UUID v4 helper (vault ids, conventions §6.6) | search for `uuid` in `packages/` and `app/` | device ids, vault ids |

If any item is missing, stop and tell the human which Phase 1/2 item is missing (GEMINI.md §5). Do not build it silently.

---

## Human prerequisites

Steps 03.1–03.12 need nothing from the human. **Before step 03.13**, stop and ask the human to do the following, then wait.
Copy this whole section into your message to the human. Do not try to do these steps yourself (they need the human's Google account).

### H1. Google Cloud project and Drive API

1. Open https://console.cloud.google.com/ and sign in with the Google account that will own the app (not necessarily the account used for testing).
2. Top bar → project picker → **New project**. Name: `Tephra`. Organisation: leave as is. Click **Create**, then select the new project.
3. Left menu → **APIs & Services → Library**. Search **Google Drive API** → open it → **Enable**.

### H2. OAuth consent screen (Google Auth Platform)

1. Left menu → **APIs & Services → OAuth consent screen** (newer consoles call it **Google Auth Platform → Branding / Audience / Data access**).
2. App name `Tephra`, user support email = your email, developer contact email = your email. Save.
3. **Audience**: User type **External**. Publishing status stays **Testing**.
4. **Audience → Test users → Add users**: add every Google account that will use the beta (your own account, your phone's account if different,
   and the dedicated CI test account from H6). Up to 100 test users are allowed while in Testing.
5. **Data access → Add or remove scopes**: add `https://www.googleapis.com/auth/drive.file` (shown as ".../auth/drive.file — See, edit, create,
   and delete only the specific Google Drive files you use with this app"). It is a **non-sensitive** scope. Save.
6. **Important limitation to know:** while the publishing status is **Testing**, Google issues refresh tokens that **expire after 7 days**.
   Tephra will then show "Reconnect Google Drive" once a week. For the 2-week daily-use beta (exit gate) you may either accept a weekly
   reconnect, or click **Publish app** (Audience → Publishing status → "In production"). Because `drive.file` is non-sensitive, publishing
   needs no paid security assessment; Google may ask for brand verification and will show an "unverified app" notice until then.
   Tell Gemini which option you chose; it is recorded in `PROGRESS.md`.

### H3. Android OAuth client (identifies the Android app by package name + signing certificate)

1. In a PowerShell window on the PC, print the SHA-1 of the Android **debug** keystore (the one `flutter run` signs debug builds with):
   ```
   & "C:\Program Files\Java\jdk-17\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
   ```
   Copy the line `SHA1: AA:BB:...` (20 colon-separated bytes). If the file does not exist, run `flutter run -d <your phone>` once in `app/` and try again.
2. Console → **APIs & Services → Credentials → Create credentials → OAuth client ID**.
3. Application type **Android**. Name `Tephra Android (debug)`. Package name **`com.tephra.app`**. SHA-1 certificate fingerprint: paste the SHA-1. **Create**.
4. Nothing from this client goes into the code: Google matches it by package name + SHA-1. (Phase 9 adds a second Android client with the
   release keystore's SHA-1.)

### H4. Web application OAuth client (required by `google_sign_in` on Android as `serverClientId`)

`google_sign_in` 7.x on Android uses Android Credential Manager, which requires the client ID of a **Web application** client from the same project.
1. Credentials → Create credentials → OAuth client ID → Application type **Web application**. Name `Tephra Android server client`.
   Leave "Authorized JavaScript origins" and "Authorized redirect URIs" empty. **Create**.
2. Copy the **Client ID** (ends in `.apps.googleusercontent.com`). The client secret of this client is **not** needed; do not copy it.

### H5. Desktop app OAuth client (Windows loopback sign-in)

1. Credentials → Create credentials → OAuth client ID → Application type **Desktop app**. Name `Tephra Windows`. **Create**.
2. Copy the **Client ID** and the **Client secret**. (For installed apps Google treats this secret as non-confidential, but it still never goes into Git.)

All three clients (H3, H4, H5) **must be in the same Cloud project**: `drive.file` grants access to files created by *this project*,
which is how the phone can read the vault folder the PC created.

### H6. CI test account (for the nightly live Drive contract test)

1. Create (or pick) a dedicated Google account that holds no personal data, e.g. `tephra.ci.test@gmail.com`. Add it as a test user (H2 step 4).
2. After step 03.15 is done, Gemini will ask you to run `dart run tool/google_refresh_token.dart` once and sign in with this account.
   It prints a refresh token. Store it as the GitHub Actions secret `TEPHRA_DRIVE_TEST_REFRESH_TOKEN`, and also store
   `TEPHRA_GOOGLE_DESKTOP_CLIENT_ID` and `TEPHRA_GOOGLE_DESKTOP_CLIENT_SECRET` (values from H5) as secrets.
   (With publishing status Testing this token expires after 7 days; see H2 step 6.)

### H7. Put the IDs into the git-ignored secrets file

Create `D:\script\tephra-gemini\secrets\google_oauth.json` with exactly these keys (replace the values):

```json
{
  "TEPHRA_GOOGLE_ANDROID_SERVER_CLIENT_ID": "1234567890-abc.apps.googleusercontent.com",
  "TEPHRA_GOOGLE_DESKTOP_CLIENT_ID": "1234567890-def.apps.googleusercontent.com",
  "TEPHRA_GOOGLE_DESKTOP_CLIENT_SECRET": "GOCSPX-xxxxxxxxxxxxxxxx"
}
```

- The app reads these values at compile time through `--dart-define-from-file=../secrets/google_oauth.json` (path relative to `app/`).
- **Never commit this file.** `secrets/` is already in `.gitignore` (conventions §9). Gemini verifies with `git check-ignore secrets/google_oauth.json`
  (must print the path) before every commit in this phase.
- Tell Gemini "Google prerequisites done" and name the Google account(s) you added as test users and which option you picked in H2 step 6.

### H8. Hardware for the demo and the exit gate

- A real Android phone (USB or wireless debugging enabled) signed in to a test-user Google account, and this Windows PC.
- Your real vault (or a copy) for the 2-week daily-use beta.

---

## What exists when done

- `packages/tephra_sync` (pure Dart, no Flutter imports) containing:
  - the sync state database (drift) at `<appSupportDir>/sync/<vaultId>.sqlite`;
  - the remote format (identical for Google Drive and Phase 10 Tephra Cloud): `vault.json`, `blobs/`, `journals/`, `snapshots/`,
    `backups/`, `devices/`, `locks/`;
  - crypto: Argon2id KDF with calibration, master key, AES-256-GCM key wrapping, HKDF per-object keys, `TPH1` envelope, recovery key;
  - FastCDC chunking + blob store with deduplication;
  - hybrid logical clock, journal writer/reader, snapshot compaction, remote history (heads, leaves, forks, ancestry);
  - local scanner with selective-sync rules and case-sensitivity detection;
  - three-way merge for Markdown (line-based, frontmatter-aware), JSON key-wise merge for `.tephra/*.json`, conflict-copy naming;
  - the pure planner (full decision table, renames, case conflicts, Windows-invalid names, large-delete guard) and the crash-safe executor;
  - `SyncEngine`, `MemorySyncProvider`, `DriveSyncProvider`, Windows desktop OAuth (loopback + PKCE), token handling;
  - local history (`.tephra/history/`), remote version history, backups (manifests, schedule, retention, verification, restore), garbage collection with leases;
  - a 3-device simulator + fuzz test (100k operations nightly), crypto known-answer tests, a fake Google Drive HTTP server with fault injection,
    a provider contract suite shared by every provider.
- `app/`:
  - Google sign-in on Android (`google_sign_in` 7.x) and Windows (system browser loopback flow); secrets in `flutter_secure_storage`;
  - a long-lived sync worker isolate with triggers (save, start/resume, 30 s Drive polling, manual, schedule);
  - Android background sync via `workmanager` (15-minute periodic task, Wi-Fi-only / charging-only options);
  - Windows tray status and "keep syncing when the window is closed";
  - Sync UI: setup wizard, status indicator, sync log, conflicts screen with diffs, devices screen, sync settings (selective sync, bandwidth),
    version history screen, recently deleted, backups and restore screens;
  - commands: `sync.sync-now`, `sync.pause`, `sync.resume`, `sync.open-log`, `sync.open-conflicts`, `sync.open-devices`, `sync.open-settings`,
    `sync.open-history`, `sync.open-deleted`, `sync.backup-now`, `sync.open-backups`.
- `tool/google_refresh_token.dart` (dev tool for the CI secret) and `.github/workflows/nightly.yml` (fuzz 100k + live Drive contract).
- `docs/decisions/sync-format-v1.md` — the frozen description of the remote format (written in step 03.24 from this file's §"Remote format").

---

## Dependencies

Add each with `dart pub add <pkg>` inside `packages/tephra_sync` or `flutter pub add <pkg>` inside `app/` (conventions §4), then run
`flutter pub get` at the repo root and `dart run tool/check_licenses.dart`. Licences were checked on pub.dev when this file was written;
**re-check each package's pub.dev page (licence + README) when you add it**, because APIs change. If a licence is not in the allowed list,
stop and ask the human.

| Package | Where | Licence | Why |
|---|---|---|---|
| `drift` (+ the sqlite package `tephra_index` already uses) | tephra_sync | MIT | sync state DB (same version as `tephra_index`) |
| `drift_dev`, `build_runner` (dev, **only if** `tephra_index` uses drift code generation) | tephra_sync | MIT / BSD-3-Clause | drift table code generation, exactly as in `tephra_index` |
| `cryptography` (2.9.x) | tephra_sync | Apache-2.0 | Argon2id, HKDF-SHA256, AES-256-GCM, HMAC |
| `crypto` (already in tephra_core) | tephra_sync | BSD-3-Clause | SHA-256 of bytes (`contentHash`) |
| `diff_match_patch` (0.4.1) | tephra_sync | Apache-2.0 | line diffs for the three-way merge and the diff views |
| `googleapis` (17.x) | tephra_sync | BSD-3-Clause | Drive v3 API client (`package:googleapis/drive/v3.dart`) |
| `http` | tephra_sync | BSD-3-Clause | HTTP client for Drive and the OAuth token endpoint |
| `yaml`, `yaml_edit` (already used by Phase 2 properties) | tephra_sync | MIT / BSD-3-Clause | frontmatter-aware merge |
| `path`, `logging` | tephra_sync | BSD-3-Clause | as everywhere |
| `uuid` (only if no UUID helper exists yet) | tephra_core or tephra_sync | MIT | device ids |
| `google_sign_in` (7.2.x) | app | BSD-3-Clause | Android sign-in + Drive authorization |
| `flutter_secure_storage` (11.x) | app | BSD-3-Clause | master key, tokens (Android Keystore-backed / Windows protected storage) |
| `cryptography_flutter` (2.3.x) | app | Apache-2.0 | native AES-GCM/HMAC on Android (Windows uses the Dart/background-isolate fallback) |
| `workmanager` (0.10.x) | app | MIT | Android periodic background sync |
| `url_launcher` | app | BSD-3-Clause | open the system browser for the Windows sign-in |
| `tray_manager` (0.8.x; only if `TrayService` has no Windows implementation yet) | app | MIT | Windows tray icon |
| `window_manager` (only if `WindowService` has no Windows implementation yet) | app | MIT | hide-to-tray on close |
| `file_picker` (only if not already a dependency) | app | MIT | "Save recovery key to a file", restore into a new folder |

No other new dependencies are allowed in this phase. The fake Drive server for tests uses `dart:io` `HttpServer` (no `shelf`).

---

## Steps

Every step below has: **Purpose**, **Files**, **Implementation**, **Tests**, **Verify**, **Pitfalls**.
"Verify" always also means the standard GEMINI.md §3 commands:

```
dart format --output=none --set-exit-if-changed app/lib app/test packages tool
flutter analyze --fatal-infos
```

plus `dart test` in every package you touched (run from the package folder) and `flutter test` in `app/` if you touched the app.
Every new Dart file starts with `// © 2026 Tephra. All rights reserved.` Every public type/member in packages gets a `///` doc comment.
Logger names used in this phase: `sync.engine`, `sync.planner`, `sync.executor`, `sync.merge`, `sync.crypto`, `sync.store`, `sync.remote`,
`sync.drive`, `sync.auth`, `sync.runtime`, `sync.background`, `sync.history`, `sync.backup`, `sync.gc`, `sync.ui`.
**Never log** note text, file contents, passwords, recovery keys, master keys, access or refresh tokens. File paths may be logged at `fine` level only.

---

### 03.1 — `tephra_sync` package skeleton, dependencies and exceptions

**Purpose.** Prepare the package so every later step compiles. No logic yet besides exceptions.

**Files.**
- `packages/tephra_sync/pubspec.yaml` (edit)
- `packages/tephra_sync/lib/tephra_sync.dart` (edit: library doc comment + `export` lines only)
- `packages/tephra_sync/lib/src/errors/sync_exceptions.dart`
- `packages/tephra_sync/lib/src/errors/crypto_exceptions.dart`
- `packages/tephra_sync/test/errors/sync_exceptions_test.dart`
- `packages/tephra_sync/README.md` (edit)

**Implementation.**
1. `pubspec.yaml`: `name: tephra_sync`, `description: "Tephra sync: engine, providers, encryption, history and backup."`,
   `resolution: workspace`, `environment: sdk: ^3.13.0`. Dependencies: `tephra_core`, `tephra_vault` (both `path`-less workspace deps exactly as other
   packages reference them), then add with `dart pub add`: `cryptography`, `diff_match_patch`, `googleapis`, `http`, `yaml`, `yaml_edit`, `path`,
   `logging`, `crypto`, `drift` (+ the sqlite package and dev dependencies exactly as in `packages/tephra_index/pubspec.yaml`). Dev: `test`.
2. Confirm the dependency rule (conventions §3): `tephra_sync` imports only `tephra_core`, `tephra_vault` and the external packages above.
3. `sync_exceptions.dart` — all extend `SyncException` from `tephra_core` (pass a technical English message; the UI maps the **type** to an l10n string):

   | Class | Thrown when | Engine reaction |
   |---|---|---|
   | `AuthRevokedException` | refresh fails with `invalid_grant`, Android authorization needs user interaction in the background, HTTP 401 after one refresh | stop cycle, status `needsAttention`, UI "Reconnect Google Drive" |
   | `NetworkUnavailableException` | socket/DNS/TLS/timeout errors after retries | status `offline`, retry with backoff |
   | `RateLimitedException` (field `Duration? retryAfter`) | 403 `userRateLimitExceeded`/`rateLimitExceeded`, 429 | retried inside the provider; escapes only after 6 retries → treated like offline |
   | `RemoteServerException` (field `int statusCode`) | 5xx after retries | treated like offline |
   | `RemoteQuotaExceededException` | 403 `storageQuotaExceeded`, or free space < 50 MiB | stop uploads, keep downloading, status `error` "Google Drive is full" |
   | `RemoteNotFoundException` (field `String key`) | `get` of a missing key | caller decides |
   | `RemoteFormatException` | `vault.json` has a `formatVersion` newer than this app knows, or malformed remote JSON | stop sync for this vault, UI "Update Tephra" |
   | `RemoteVaultMissingException` | the vault folder or `vault.json` disappeared from Drive | stop, UI explains; **never** treat as "delete everything" |
   | `SyncLockedException` | another engine (e.g. background task) holds the vault's sync lock | skip this cycle silently |
   | `DeviceRevokedException` | this device's revocation file exists | stop sync, UI "This device was removed from sync" |
   | `DeviceCloneDetectedException` | another installation writes journals with this device id | engine switches to a new device id (step 03.7) |
   | `VaultFolderUnavailableException` | the local vault root does not exist or cannot be listed | stop; **never** plan deletes |

4. `crypto_exceptions.dart` — extend `CryptoException` from `tephra_core`: `WrongPasswordException`, `WrongRecoveryKeyException`
   (also used when the recovery key checksum fails), `TamperedDataException` (field `String? key`: GCM tag failure or hash mismatch),
   `UnsupportedEnvelopeException` (unknown magic/version/purpose), `KeyNotAvailableException` (master key not in secure storage).
5. Export both files from `lib/tephra_sync.dart`.
6. README: one paragraph describing the package and a bullet list of the folders under `lib/src/` that later steps create.

**Tests.** `sync_exceptions_test.dart`: every class is a `SyncException`/`CryptoException`, `toString()` contains the runtime type and the message,
fields are stored.

**Verify.** `cd packages/tephra_sync; dart test`. `dart run tool/check_licenses.dart` passes.

**Pitfalls.** Do not create any `RetryException` that wraps everything — callers must catch specific types. Do not add Flutter packages here.

---

### 03.2 — Core models, the `SyncProvider` contract and `MemorySyncProvider`

**Purpose.** Fix the provider interface (conventions §7.6, unchanged), the value types it uses, the remote key layout, and an in-memory provider
for all pure tests. Also create the shared provider **contract test suite**.

**Files.**
- `lib/src/provider/sync_provider.dart` — the interface, copied from conventions §7.6 **exactly** (names, parameter names, return types).
- `lib/src/provider/remote_object.dart`, `remote_changes.dart`, `quota.dart`
- `lib/src/provider/memory_sync_provider.dart`
- `lib/src/remote/remote_layout.dart`
- `test/support/sync_provider_contract.dart`
- `test/provider/memory_sync_provider_test.dart`
- `test/remote/remote_layout_test.dart`

**Implementation.**
1. Value types (immutable, `==`/`hashCode` via `Object.hash`, hand-written `toJson`/`fromJson`):
   ```dart
   final class RemoteObject {
     const RemoteObject({required this.key, required this.size, required this.modified, this.created});
     final String key;          // e.g. 'blobs/9f86d0...'
     final int size;            // bytes
     final DateTime modified;   // server time (UTC). Used for lease expiry (step 03.23).
     final DateTime? created;   // server time (UTC). Used for the GC grace period.
   }
   final class RemoteChanges {
     const RemoteChanges({required this.changedKeys, required this.removedKeys, required this.cursor, this.cursorWasReset = false});
     final List<String> changedKeys;   // created or replaced since the given cursor
     final List<String> removedKeys;   // deleted since the given cursor
     final String cursor;              // pass to the next changesSince call
     final bool cursorWasReset;        // true if the old cursor was unknown/expired: caller must do a full listing
   }
   final class Quota { const Quota({required this.usedBytes, this.limitBytes}); final int usedBytes; final int? limitBytes; // null = unlimited
     int? get freeBytes => limitBytes == null ? null : limitBytes! - usedBytes; }
   ```
2. Semantics of the interface (write these as doc comments on `SyncProvider`; every implementation and the contract suite must follow them):
   - `connect()` — authenticate/open; idempotent; throws `AuthRevokedException`, `NetworkUnavailableException`.
   - `list(prefix)` — every object whose key starts with `prefix` (string prefix, not folder-only), sorted ascending by key, no duplicates.
     `list('')` returns everything. Returns `[]` when nothing matches.
   - `get(key)` — full bytes; throws `RemoteNotFoundException` when absent.
   - `put(key, bytes)` — create or replace. After it returns, `get(key)` returns exactly `bytes`. Zero-length allowed. Keys: 1–512 characters
     from `[A-Za-z0-9._/-]`, no leading/trailing `/`, no `//`, no `.` or `..` segment (throw `ArgumentError` otherwise).
   - `delete(key)` — remove; deleting a missing key is a no-op (no exception). (Drive moves to Drive trash, see step 03.15.)
   - `changesSince(cursor)` — `cursor == null` returns no keys and a fresh cursor (the "start token"). Otherwise returns the keys changed/removed
     since `cursor`. A key may appear in both lists if it was put and then deleted; callers re-`list` when in doubt.
   - `quota()` — `null` if the backend cannot tell.
3. `MemorySyncProvider({Clock clock = const SystemClock(), String id = 'memory'})`: `SplayTreeMap<String, _Obj>` storage, a monotonically increasing
   change counter, a change log `List<(int counter, String key, bool removed)>`; cursor = counter as decimal string; an unknown/garbage cursor →
   `cursorWasReset: true`. Optional fault hooks for tests: `Future<void> Function(String op, String key)? beforeOp` (a test may throw from it),
   `int? quotaLimitBytes` (put beyond it throws `RemoteQuotaExceededException`). `get` returns a **copy** of the stored bytes.
4. `remote_layout.dart` — `abstract final class RemoteLayout` with static key builders and parsers (the only place key strings are built):

   | Key | Builder | Content | Written by |
   |---|---|---|---|
   | `vault.json` | `RemoteLayout.vaultHeader` | public header, plain JSON (step 03.6) | the creating device; later replaced only on password change |
   | `blobs/<64 hex>` | `blob(String sha256Hex)` | file content (envelope, step 03.4); hex = SHA-256 of the **stored bytes** | any device; immutable |
   | `journals/<deviceId>/<10-digit firstSeq>.json.enc` | `journal(deviceId, firstSeq)` | one batch of entries (step 03.7) | only that device; never replaced |
   | `snapshots/<deviceId>/<10-digit seq>.json.enc` | `snapshot(deviceId, seq)` | compacted state (step 03.7) | only that device |
   | `backups/<yyyyMMddTHHmmssZ>/manifest.json.enc` | `backupManifest(DateTime utc)` | backup manifest (step 03.22) | the backing-up device; never replaced |
   | `devices/<deviceId>.json.enc` | `deviceInfo(deviceId)` | device name/platform (step 03.6) | only that device (replaced at most hourly) |
   | `devices/<deviceId>.revoked.json.enc` | `deviceRevocation(deviceId)` | revocation record (step 03.19) | the revoking device; written once |
   | `locks/gc-<deviceId>.json.enc` | `gcLease(deviceId)` | GC lease (step 03.23) | only that device |
   | `locks/gc-state.json.enc` | `gcState` | GC candidate list (step 03.23) | only the current GC lease holder |

   Device ids are lower-case UUID v4 strings (36 chars). `firstSeq`/`seq` are zero-padded to 10 digits (`seq.toString().padLeft(10, '0')`).
   Parsers: `RemoteLayout.parse(String key)` returns a sealed `RemoteKey` (`VaultHeaderKey`, `BlobKey(hash)`, `JournalKey(deviceId, firstSeq)`,
   `SnapshotKey(deviceId, seq)`, `BackupManifestKey(DateTime)`, `DeviceInfoKey(deviceId)`, `DeviceRevocationKey(deviceId)`, `GcLeaseKey(deviceId)`,
   `GcStateKey`, `UnknownKey(key)`). Unknown keys are ignored by every reader (forward compatibility).
5. **Why per-device append-only journals (write this as the class doc comment of `RemoteLayout`):** Google Drive has no reliable
   compare-and-swap. If two devices rewrote one shared manifest, one write would silently overwrite the other. In this layout every mutable
   object has exactly one writer (its device id is in the name), blobs are immutable and named by their hash, and journal file names are unique
   (device id + sequence number). Two devices can therefore never overwrite each other's data, whatever order Drive applies writes in.
6. `test/support/sync_provider_contract.dart` exports
   `void runSyncProviderContract(String name, Future<SyncProvider> Function() create, {Future<void> Function(SyncProvider)? cleanUp})`.
   It registers a `group(name, ...)` with these tests (each uses a fresh random prefix `t<random 8 hex>/` so live runs do not collide):
   1. put → get returns identical bytes (3 sizes: 0 bytes, 1 KiB, 6 MiB of seeded random bytes).
   2. put twice on the same key → get returns the second value; `list` shows the key once.
   3. `list(prefix)` returns exactly the keys under the prefix, sorted, including nested keys (`a/b/c`), and nothing outside it.
   4. `list` on an empty prefix returns `[]`.
   5. delete → get throws `RemoteNotFoundException`; delete again does not throw; list no longer shows the key.
   6. `changesSince(null)` returns a cursor; after a put and a delete, `changesSince(cursor)` reports the put key in `changedKeys` and the
      deleted key in `removedKeys` (allowing a key in both lists), and returns a new cursor; a second call with the new cursor reports nothing new
      (for Drive: retry up to 10 s because the changes feed is eventually consistent).
   7. 20 concurrent puts of different keys all succeed and all are listed.
   8. `RemoteObject.size` equals the byte length; `modified` is within 10 minutes of the local clock (live) or equals the injected clock (memory).
   9. `quota()` returns `null` or a `Quota` with `usedBytes >= 0`.
   10. Invalid keys (`''`, `/a`, `a//b`, `a/../b`, `a b`) throw `ArgumentError` without any network call.

**Tests.** `memory_sync_provider_test.dart` calls `runSyncProviderContract('MemorySyncProvider', ...)` plus memory-only tests: unknown cursor →
`cursorWasReset`, `beforeOp` throwing propagates, quota limit. `remote_layout_test.dart`: every builder ↔ parser round trip, zero padding,
unknown keys → `UnknownKey`.

**Verify.** `cd packages/tephra_sync; dart test`.

**Pitfalls.** `list` must not return "folders" as objects. Do not add methods to `SyncProvider` (contract is fixed); helpers go in separate classes.

---

### 03.3 — Sync state database (drift) and device identity

**Purpose.** Persist everything the engine needs between runs, per vault, outside the vault folder (it must never sync).

**Files.**
- `lib/src/store/sync_tables.dart` (drift table definitions), `lib/src/store/sync_database.dart` (database class, schema version, migrations)
- `lib/src/store/sync_state_store.dart` (the only API the rest of the package uses; hides drift)
- `lib/src/model/device_identity.dart`, `lib/src/model/selective_sync_rules.dart`, `lib/src/model/sync_mode.dart`
- `test/store/sync_state_store_test.dart`

**Implementation.**
1. Location: `<appSupportDir>/sync/<vaultId>.sqlite` where `vaultId` is the **local** id from `<vault>/.tephra/vault.json` (conventions §6.6).
   The package receives the file path from the app; it never calls `path_provider`. Tests use an in-memory database (same helper as `tephra_index` tests).
   Open with WAL journal mode and `PRAGMA foreign_keys = ON`.
2. Tables (schema version **1**; column names exactly as below; `INTEGER` times are milliseconds since epoch UTC):

   | Table | Columns | Notes |
   |---|---|---|
   | `meta` | `key TEXT PK`, `value TEXT NOT NULL` | keys listed in item 3 |
   | `synced_files` | `path TEXT PK`, `case_key TEXT NOT NULL`, `hash TEXT NOT NULL`, `size INTEGER NOT NULL`, `mtime INTEGER NOT NULL`, `version TEXT NOT NULL`, `blob_keys TEXT NOT NULL` (JSON list), `synced_at INTEGER NOT NULL` | the **base** per path; `version` = entry id (`<deviceId>:<seq>`) this device last synced; index on `case_key` |
   | `bases` | `path TEXT PK`, `hash TEXT NOT NULL`, `text_gz BLOB NOT NULL` | last synced text (gzip of UTF-8 of the normalised `\n` text) for mergeable files only (`.md`, `.txt`, synced `.tephra/*.json`) |
   | `local_hash_cache` | `path TEXT PK`, `size INTEGER`, `mtime INTEGER`, `hash TEXT` | avoids re-hashing unchanged files |
   | `remote_entries` | `entry_id TEXT PK`, `device_id TEXT`, `seq INTEGER`, `hlc TEXT`, `op TEXT`, `path TEXT`, `from_path TEXT NULL`, `hash TEXT NULL`, `size INTEGER NULL`, `mtime INTEGER NULL`, `blob_keys TEXT NULL`, `parent TEXT NULL`, `target_parent TEXT NULL`, `merged_parent TEXT NULL`, `time INTEGER` | every journal entry read (own + others); indexes on `path`, `from_path`, `(device_id, seq)` |
   | `remote_heads` | `path TEXT PK`, `entry_id TEXT NOT NULL`, `is_fork INTEGER NOT NULL` | materialised by step 03.7 |
   | `journal_cursors` | `device_id TEXT PK`, `last_seq INTEGER NOT NULL`, `device_name TEXT`, `platform TEXT`, `last_seen_at INTEGER`, `revoked_after_seq INTEGER NULL` | how far each device's journal was read |
   | `pending_ops` | `id INTEGER PK AUTOINCREMENT`, `kind TEXT`, `payload TEXT` (JSON), `state TEXT`, `created_at INTEGER`, `attempts INTEGER`, `last_error TEXT NULL` | crash recovery (journal batches, held deletes) |
   | `remote_file_ids` | `key TEXT PK`, `file_id TEXT NOT NULL`, `size INTEGER`, `created_at INTEGER` | Drive key → fileId cache (step 03.15) |
   | `blob_index` | `plain_hash TEXT`, `blob_key TEXT`, `size INTEGER`, `seen_at INTEGER`, PK `(plain_hash, blob_key)` | dedup: plaintext SHA-256 → existing blob; `seen_at` = last time we confirmed it exists remotely |
   | `sync_log` | `id INTEGER PK AUTOINCREMENT`, `time INTEGER`, `level TEXT`, `kind TEXT`, `path TEXT NULL`, `other_path TEXT NULL`, `device_name TEXT NULL`, `detail TEXT NULL` | human log (step 03.19); keep newest 5,000 rows |
   | `conflicts` | `id INTEGER PK AUTOINCREMENT`, `time INTEGER`, `path TEXT`, `copy_path TEXT`, `kind TEXT`, `other_device TEXT`, `resolved INTEGER` | conflicts screen (step 03.20) |
   | `backups` | `stamp TEXT PK`, `manifest_key TEXT`, `file_count INTEGER`, `total_bytes INTEGER`, `created_at INTEGER` | cache of remote backup list |
   | `backup_verifications` | `id INTEGER PK AUTOINCREMENT`, `time INTEGER`, `stamp TEXT`, `sampled INTEGER`, `ok INTEGER`, `failed INTEGER`, `failed_keys TEXT` | step 03.23 |

3. `meta` keys (all strings; numbers as decimal): `schemaVersion`, `remoteVaultId`, `remoteVaultName`, `providerId` (`gdrive`|`memory`),
   `vaultRootPath`, `syncDeviceId`, `deviceName`, `platform` (`android`|`windows`), `caseInsensitive` (`true`|`false`), `mode`
   (`live`|`backupOnly`|`off`), `hlcMillis`, `hlcCounter`, `nextSeq` (starts at `1`), `changesCursor`, `lastSyncAt`, `lastSnapshotSeq`,
   `selectiveRules` (JSON, item 5), `bandwidthUpKiBps`, `bandwidthDownKiBps` (`0` = unlimited), `backgroundSync`, `wifiOnly`, `chargingOnly`,
   `keepSyncingWhenClosed`, `backupSchedule` (`off`|`hourly`|`daily`|`weekly`), `backupRetention` (JSON `{"hourly":48,"daily":30,"monthly":12}`),
   `lastBackupAt`, `lastVerificationAt`, `lastGcAt`, `heldDeletes` (JSON list of paths, step 03.10), `pausedByUser`.
4. **Device identity.** `DeviceIdentity { final String deviceId; final String deviceName; final String platform; }`.
   On first connect of a vault, `syncDeviceId` is set to the app-level device id (conventions §6.6). It is stored per vault because step 03.7 may
   replace it with a fresh UUID if a clone is detected (a copied app-data folder on a second machine). `deviceName` defaults to the app-level
   device name; if that is empty, `Platform.localHostname` on Windows and `Android device` on Android; the setup wizard lets the user edit it.
5. `SelectiveSyncRules` (immutable, JSON): `excludedFolders: List<String>` (vault paths), `excludedExtensions: Set<String>` (lower-case, no dot),
   `maxFileSizeBytes: int` (default `104857600` = 100 MiB), `mobileMode: bool` (default `false`). `mobileMode` adds these extensions to the
   exclusion: `mp4, mov, mkv, avi, webm, m4v, 3gp, wmv, flv`. Rules are **device-local** (stored in `meta`, never synced).
6. `SyncStateStore` API (async; all multi-row writes in one transaction): `open(String file)`, `close()`, `getMeta/setMeta`, `base(VaultPath)`,
   `allBases()`, `putBase(...)`, `removeBase(...)`, `baseText(path)` / `putBaseText(path, hash, text)`, `cachedHash(path, size, mtime)` /
   `putCachedHash`, `insertRemoteEntries(List<JournalEntry>)`, `entriesForPath(String)`, `allEntries()`, `replaceHeads(...)`, `heads()`,
   `cursor(deviceId)` / `setCursor`, `addPendingOp` / `pendingOps()` / `updatePendingOp` / `removePendingOp`, `fileId(key)` / `putFileId` /
   `removeFileId`, `blobForPlainHash(hash)` / `putBlobIndex` / `touchBlob`, `appendLog(SyncLogEntry)` / `log({int limit})`, `addConflict` /
   `conflicts({bool unresolvedOnly})` / `resolveConflict(id)`, backups and verification methods. Each returns the immutable model classes
   (`BaseState`, `JournalEntry`, `SyncLogEntry`, `ConflictRecord`, ...) — never drift row classes.
7. Migrations: `MigrationStrategy` with `onCreate` creating all tables and `onUpgrade` that throws for unknown versions (only v1 exists).
   Store `schemaVersion = 1` in `meta`.

**Tests.** CRUD round trip for every table through `SyncStateStore`; transaction rollback on an exception leaves no partial rows;
log trimming keeps exactly the newest 5,000 rows; `SelectiveSyncRules` JSON round trip and `mobileMode` extension set; reopening a file-backed DB in a
temp directory keeps the data (simulates app restart).

**Verify.** `cd packages/tephra_sync; dart test test/store`.

**Pitfalls.** Never put this DB inside the vault (it would sync and conflict). If `tephra_index` uses drift code generation, run
`dart run build_runner build --delete-conflicting-outputs` in `packages/tephra_sync` and commit the generated `*.g.dart` exactly as `tephra_index` does.

---

### 03.4 — Crypto: KDF, master key, key wrapping, object envelope, recovery key

**Purpose.** All cryptography in one small, heavily tested module. Format details here are **frozen**: Phase 10 depends on them.

**Files.** `lib/src/crypto/`: `kdf_params.dart`, `kdf_calibrator.dart`, `master_key.dart`, `key_wrap.dart`, `object_purpose.dart`,
`object_cipher.dart` (interface), `encrypting_object_cipher.dart`, `plaintext_object_cipher.dart`, `envelope.dart`, `recovery_key.dart`, `base32.dart`.
Tests: `test/crypto/kat_test.dart`, `envelope_test.dart`, `key_wrap_test.dart`, `recovery_key_test.dart`, `base32_test.dart`, `kdf_calibrator_test.dart`.

**Implementation.**
1. Use `package:cryptography` classes: `Argon2id`, `Hkdf(hmac: Hmac.sha256(), outputLength: 32)`, `AesGcm.with256bits()`, `Hmac.sha256()`,
   `Sha256()`, `SecretKey`, `SecretBox`. Re-read the package README for the current API before coding. Random bytes: `Random.secure()`
   (tests inject a seeded `Random`). The library uses `Cryptography.instance`; the app may switch it to `FlutterCryptography` (step 03.16).
2. **KDF parameters** `KdfParams { alg = 'argon2id', version = 19, memoryKiB, iterations, parallelism, salt (16 random bytes), calibratedMs }`.
   - Floor (never lower): `memoryKiB = 65536` (64 MiB), `iterations = 3`, `parallelism = 1`, hash length 32 bytes.
   - `Argon2id(parallelism: p, memory: memoryKiB, iterations: t, hashLength: 32)` then
     `deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt)` → the **password KEK** (32 bytes).
     (`memory` is counted in 1 KiB blocks.) Passwords are used exactly as typed (no trimming, no Unicode normalisation; state this in the wizard).
   - **Calibration** (`KdfCalibrator.calibrate({required bool isAndroid})`), run in `Isolate.run`:
     - On **Windows**: return the floor without measuring (the phone must later unlock the same vault, and a PC-calibrated value would be too slow on the phone).
     - On **Android**: start at the floor; measure one derivation with `Stopwatch`; while `elapsed < 350 ms` and `memoryKiB < 131072`, double `memoryKiB`
       and measure again; then while `elapsed < 350 ms` and `iterations < 4`, add 1 to `iterations` and measure again. Return the result with
       `calibratedMs` = last elapsed. Never go below the floor, even if the floor takes longer than 500 ms.
     - If the floor takes **more than 5 s** on the human's phone (step 03.24 measures it), stop and ask the human; do not lower the floor yourself.
3. **Master key**: 32 random bytes generated once per remote vault. Never uploaded in clear, never logged.
4. **Key wrapping** (AES-256-GCM used as a key-wrap):
   `WrappedKey { alg = 'aes-256-gcm', nonce (12 random bytes), ciphertext (32-byte master key encrypted, followed by the 16-byte tag = 48 bytes) }`.
   AAD = UTF-8 of `tephra-wrap-v1|<vaultId>|password` or `tephra-wrap-v1|<vaultId>|recovery`.
   Unwrap failure (tag mismatch) → `WrongPasswordException` / `WrongRecoveryKeyException`.
5. **Recovery key**: 16 random bytes `r`. Checksum `c` = first 4 bytes of SHA-256(`r`). Display string = RFC 4648 base32 (alphabet `A–Z2–7`,
   no padding) of the 20 bytes `r ‖ c` = exactly 32 characters, shown as **8 groups of 4** joined by `-` (e.g. `ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567`).
   Parsing: upper-case, remove spaces and `-`, map `0`→`O`, `1`→`I`, `8`→`B` (common misreads), require 32 chars, decode, verify checksum
   (mismatch → `WrongRecoveryKeyException`). Recovery KEK = HKDF-SHA256(ikm = `r`, salt = `recoverySalt` (16 random bytes stored in `vault.json`),
   info = UTF-8 `tephra/v1/recovery-kek`, length 32). No Argon2 (the key already has 128 bits of entropy).
6. **Object purposes** (`enum ObjectPurpose` with a byte code and an HKDF info string; frozen):

   | Purpose | Code | HKDF info | Used for |
   |---|---|---|---|
   | `blob` | 1 | `tephra/v1/blob` | file content chunks |
   | `journal` | 2 | `tephra/v1/journal` | journal batches |
   | `snapshot` | 3 | `tephra/v1/snapshot` | snapshots |
   | `manifest` | 4 | `tephra/v1/manifest` | backup manifests |
   | `device` | 5 | `tephra/v1/device` | device info + revocation files |
   | `lock` | 6 | `tephra/v1/lock` | GC leases |
   | `gcState` | 7 | `tephra/v1/gc-state` | GC state |

7. **Envelope `TPH1`** (every encrypted object; byte layout frozen):

   | Offset | Length | Field |
   |---|---|---|
   | 0 | 4 | magic ASCII `TPH1` = `0x54 0x50 0x48 0x31` |
   | 4 | 1 | envelope version = `0x01` |
   | 5 | 1 | purpose code (table above) |
   | 6 | 16 | object salt (random) |
   | 22 | 12 | AES-GCM nonce (random 96 bits) |
   | 34 | n | ciphertext (same length as plaintext) |
   | 34+n | 16 | GCM tag |

   Object key = HKDF-SHA256(ikm = master key, salt = object salt, info = purpose info string, length 32). A fresh salt per object means a fresh key
   per object, so random 96-bit nonces never repeat under one key. AAD = the 34 header bytes followed by UTF-8 of the remote vault id
   (binds every object to its vault and purpose). Decrypt checks magic → version → purpose (expected purpose passed by the caller) → GCM tag;
   any failure → `UnsupportedEnvelopeException` (magic/version/purpose) or `TamperedDataException` (tag).
8. `ObjectCipher` interface: `Future<List<int>> seal(List<int> plaintext, ObjectPurpose purpose)`,
   `Future<List<int>> open(List<int> stored, ObjectPurpose purpose)`, `bool get encrypts`.
   - `EncryptingObjectCipher(SecretKey masterKey, String vaultId, {Random? random})` implements the envelope.
   - `PlaintextObjectCipher` (vault created with **encryption off**): `seal` returns the bytes unchanged; `open` returns them unchanged but first
     rejects data that starts with `TPH1` (a mixed-up vault) with `UnsupportedEnvelopeException`.
   - **Encryption off — decision:** blobs are stored as the raw file bytes (open any blob in Drive and it is the original file; text notes are readable),
     and journals/snapshots/manifests are stored as plain UTF-8 JSON (snapshots/manifests gzip-compressed, see step 03.7/03.22), so file paths are
     readable inside them. Drive **file names** are still hashes and sequence numbers in both modes; there is no browsable mirror of the vault tree.
     Encryption cannot be switched on/off after a remote vault is created (it would need a full re-upload); the user creates a new remote vault instead.
9. Long operations (Argon2id, sealing/opening many objects) always run off the UI isolate (conventions §5.6): Argon2id via `Isolate.run`;
   bulk sealing happens inside the sync worker isolate.

**Tests.**
- **Known-answer tests** (`kat_test.dart`), byte-exact:
  - AES-256-GCM, key = 32 zero bytes, nonce = 12 zero bytes, empty plaintext, no AAD → tag `530f8afbc74536b9a963b4f1c4cb738b`.
  - AES-256-GCM, same key/nonce, plaintext = 16 zero bytes → ciphertext `cea7403d4d606b6e074ec5d3baf39d18`, tag `d0d1c8a799996bf0265b98b5d48ab919`.
  - HKDF-SHA256 (RFC 5869 test case 1): IKM = 22 bytes `0x0b`, salt = `000102030405060708090a0b0c`, info = `f0f1f2f3f4f5f6f7f8f9`, L = 42 →
    `3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865`.
  - Argon2id (RFC 9106 §5.3): memory 32 KiB, passes 3, lanes 4, tag 32 bytes, password = 32 bytes `0x01`, salt = 16 bytes `0x02`,
    secret = 8 bytes `0x03` (`optionalSecret`), associated data = 12 bytes `0x04` (`associatedData`) →
    `0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659`. Open https://www.rfc-editor.org/rfc/rfc9106 §5.3 and compare once by eye.
- Frozen envelope vector: with a seeded `Random(42)` for salt/nonce, master key = bytes `0..31`, vault id `00000000-0000-4000-8000-000000000000`,
  purpose `blob`, plaintext UTF-8 `hello tephra` → record the resulting hex in the test as a golden constant on first run, then assert it forever
  (this protects the format from accidental change). Add a comment saying so.
- Envelope: round trip for 0 B, 1 B, 1 MiB; flipping any single byte in header, ciphertext or tag → exception; wrong purpose → `UnsupportedEnvelopeException`;
  wrong vault id → `TamperedDataException`; two seals of the same plaintext differ.
- Key wrap: wrap/unwrap; wrong password → `WrongPasswordException`; changing AAD purpose (`password` vs `recovery`) fails.
- Recovery key: format regex `^[A-Z2-7]{4}(-[A-Z2-7]{4}){7}$`; parse tolerates lower case, spaces, missing dashes, `0/1/8` misreads; one changed
  character → `WrongRecoveryKeyException` (checksum).
- Base32: RFC 4648 §10 vectors (`f`→`MY`, `fo`→`MZXQ`, `foo`→`MZXW6`, `foob`→`MZXW6YQ`, `fooba`→`MZXW6YTB`, `foobar`→`MZXW6YTBOI`; no padding).
- Calibrator: with an injected fake timer function, Windows returns the floor; Android doubles memory until ≥ 350 ms; never below floor; caps respected.

**Verify.** `cd packages/tephra_sync; dart test test/crypto`. All KATs pass.

**Pitfalls.** Never reuse a nonce with the same key (always use a fresh salt+nonce). Never compare MACs with `==` on strings — GCM checks the tag for you.
Do not invent your own primitives. The pure-Dart Argon2id at 64 MiB can take 1–3 s on a phone: always show a progress spinner in the UI.

---

### 03.5 — FastCDC chunking and the blob store (dedup, verify)

**Purpose.** Turn file bytes into immutable remote blobs and back, with deduplication and end-to-end verification.

**Files.** `lib/src/blobs/fastcdc.dart`, `lib/src/blobs/blob_store.dart`, `lib/src/blobs/blob_ref.dart`;
tests `test/blobs/fastcdc_test.dart`, `test/blobs/blob_store_test.dart`.

**Implementation.**
1. **Chunking rule (frozen, recorded in `vault.json` as `"chunking": {"alg": "fastcdc-gear32-v1", "min": 262144, "avg": 1048576, "max": 4194304, "singleBlobMax": 4194304}`):**
   - Files of **≤ 4 MiB** (4,194,304 bytes) → exactly one chunk (the whole file).
   - Larger files → FastCDC with min 256 KiB, average 1 MiB, max 4 MiB (normalised chunking level 2).
2. FastCDC "gear32" (write it yourself from this description; it is a published algorithm):
   - Gear table: 256 unsigned 32-bit values; `gear[i]` = the first 4 bytes (big-endian) of SHA-256 of the UTF-8 string `tephra-gear-v1-<i>`
     (`i` in decimal). Compute once, cache in a `static final Uint32List`.
   - Rolling hash `h` (32-bit): for each byte `b`: `h = ((h << 1) + gear[b]) & 0xFFFFFFFF`.
   - Masks (use exactly these two constants): `maskS = 0xFFFFFC00` (the top 22 bits set; harder; used before the average point)
     and `maskL = 0xFFFFC000` (the top 18 bits set; easier; used after the average point).
   - For each chunk starting at offset `s`: skip the first `min` bytes (no cut possible); for positions up to `s + avg` cut when `(h & maskS) == 0`;
     after that up to `s + max` cut when `(h & maskL) == 0`; force a cut at `s + max`. Reset `h = 0` at each chunk start. The last chunk may be short.
   - Output: `List<(int offset, int length)>`. Deterministic: same bytes → same cuts on every platform.
3. `BlobRef { final String key; final int size; }` — `key` is the full remote key `blobs/<hex>`.
4. `BlobStore(SyncProvider provider, ObjectCipher cipher, SyncStateStore store, {Clock clock})`:
   - `Future<List<String>> putFile(List<int> bytes, {required String plainHash})` → list of blob keys in order:
     for each chunk: `chunkHash = contentHash(chunk)`; look up `blob_index` by `chunkHash`; if a row exists with `seen_at ≥ now − 24 h`, reuse its key;
     if a row exists but is older, confirm with `provider.list(blobKey)` (exact key as prefix) — present → `touchBlob`, reuse; absent → upload.
     Upload: `stored = cipher.seal(chunk, ObjectPurpose.blob)`, `key = RemoteLayout.blob(contentHash(stored))`, `provider.put(key, stored)`,
     `putBlobIndex(chunkHash, key, size, seen_at = now)`.
     For a one-chunk file `chunkHash == plainHash`.
   - `Future<List<int>> getFile(List<String> blobKeys, {required String expectedPlainHash})`: for each key: `stored = provider.get(key)`;
     verify `contentHash(stored)` equals the hash in the key, else `TamperedDataException(key)`; `chunk = cipher.open(stored, blob)`;
     concatenate; verify `contentHash(all) == expectedPlainHash`, else `TamperedDataException`. Record `blob_index(contentHash(chunk), key)`.
   - Transfers run with at most **4** concurrent provider calls (a simple semaphore), so the planner can upload several files in parallel later.
5. With `PlaintextObjectCipher`, stored == chunk, so the blob key hash equals the chunk hash (still verified the same way).

**Tests.** FastCDC: deterministic cuts for a seeded 20 MiB random buffer (record the first 5 cut offsets as golden constants on first run, then assert);
all chunks within [min, max] except the last; inserting 10 bytes at offset 5 MiB changes at most 3 chunks; files ≤ 4 MiB → one chunk.
BlobStore with `MemorySyncProvider` + both ciphers: round trip 0 B, 10 B, 4 MiB, 4 MiB + 1, 12 MiB; second `putFile` of identical bytes performs
zero `put` calls (count via `beforeOp`); a stale `blob_index` row whose blob was deleted remotely causes a re-upload; corrupting one stored byte
→ `TamperedDataException`; wrong expected hash → `TamperedDataException`.

**Verify.** `cd packages/tephra_sync; dart test test/blobs`.

**Pitfalls.** Use `Uint8List` and `BytesBuilder(copy: false)` to avoid copies of large files. Do not compress blobs (format v1 has no compression flag).
The 32-bit masks must be applied to the **top** bits as specified (the low bits of a left-shifting gear hash depend only on the last few bytes).

---

### 03.6 — Remote vault header (`vault.json`), `RemoteVaultManager` and device files

**Purpose.** Create, find, unlock and re-key a remote vault; register this device.

**Files.** `lib/src/remote/vault_header.dart`, `lib/src/remote/remote_vault_manager.dart`, `lib/src/remote/device_registry.dart`,
`lib/src/model/remote_device.dart`; tests `test/remote/vault_header_test.dart`, `remote_vault_manager_test.dart`, `device_registry_test.dart`.

**Implementation.**
1. `vault.json` (plain JSON, UTF-8, pretty-printed with 2 spaces; unknown fields must be preserved when the file is rewritten):
   ```json
   {
     "format": "tephra-remote",
     "formatVersion": 1,
     "vaultId": "6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11",
     "vaultName": "My Vault",
     "createdAt": "2026-10-11T09:30:00.000Z",
     "createdBy": { "deviceId": "…uuid…", "deviceName": "Office PC" },
     "updatedAt": "2026-10-11T09:30:00.000Z",
     "encryption": "aes-256-gcm",
     "kdf": { "alg": "argon2id", "version": 19, "memoryKiB": 65536, "iterations": 3, "parallelism": 1,
              "salt": "<base64 16 bytes>", "calibratedMs": 0 },
     "wrappedKeys": {
       "password": { "alg": "aes-256-gcm", "nonce": "<base64 12>", "ciphertext": "<base64 48>" },
       "recovery": { "alg": "aes-256-gcm", "nonce": "<base64 12>", "ciphertext": "<base64 48>", "salt": "<base64 16>" }
     },
     "chunking": { "alg": "fastcdc-gear32-v1", "min": 262144, "avg": 1048576, "max": 4194304, "singleBlobMax": 4194304 }
   }
   ```
   With encryption off: `"encryption": "none"` and **no** `kdf` / `wrappedKeys` fields. Base64 = standard alphabet with padding.
   `VaultHeader.fromJson` throws `RemoteFormatException` if `format != 'tephra-remote'`, if `formatVersion > 1`, or if a required field is missing.
   The remote vault id is a new UUID v4 (it is **not** the local `.tephra/vault.json` id; devices bind local→remote in their sync DB).
2. `RemoteVaultManager(SyncProvider provider, {Clock clock, Random? random})`:
   - `Future<CreatedVault> create({required String vaultName, required String? password, required DeviceIdentity device, required bool isAndroid})`:
     if `password == null` → encryption off. Otherwise: calibrate KDF (`Isolate.run`), generate master key, recovery key, salts, wrap master key twice,
     write `vault.json` **last** (after `devices/<id>.json.enc`), so a half-created vault has no header and is ignored by listings.
     Returns `CreatedVault { VaultHeader header; SecretKey? masterKey; String? recoveryKeyDisplay; }`.
   - `Future<VaultHeader> readHeader()`.
   - `Future<SecretKey> unlockWithPassword(VaultHeader h, String password)` (KDF in `Isolate.run`) → `WrongPasswordException` on failure.
   - `Future<SecretKey> unlockWithRecoveryKey(VaultHeader h, String recoveryKey)`.
   - `Future<void> changePassword({required VaultHeader h, required SecretKey masterKey, required String newPassword, required bool isAndroid})`:
     new salt (and re-calibration on Android), re-wrap the **same** master key, keep the recovery wrap unchanged, set `updatedAt`, `put('vault.json')`.
     No blob is re-uploaded. Other devices keep working (they cache the master key) and use the new password only when they next unlock.
   - `Future<String> regenerateRecoveryKey({required VaultHeader h, required SecretKey masterKey})` — new recovery key + salt, rewrap, put header,
     return display string (shown once).
   - Concurrent password changes from two devices: last writer wins on `vault.json`; both wraps protect the same master key, so no data is lost.
     Document this in the doc comment.
3. `DeviceRegistry(SyncProvider, ObjectCipher, {Clock clock})`:
   - Device info file `devices/<deviceId>.json.enc` (purpose `device`), JSON:
     `{"v":1,"deviceId":"…","deviceName":"Pixel 8","platform":"android","appVersion":"0.3.0","registeredAt":"…","updatedAt":"…"}`.
     `register(DeviceIdentity)` writes it; `heartbeat(...)` rewrites it at most once per hour (only the owning device writes this key).
   - Revocation file `devices/<targetId>.revoked.json.enc`: `{"v":1,"deviceId":"<target>","revokedBy":"<id>","revokedAt":"…","lastAcceptedSeq":123}`.
     `revoke(targetId, lastAcceptedSeq)` writes it once (if it already exists, do nothing: the first revocation stands).
   - `listDevices()` → `List<RemoteDevice { deviceId, deviceName, platform, registeredAt, updatedAt, revoked, lastAcceptedSeq }>`.
4. Listing remote vaults is provider-specific (Drive lists vault folders); it is done in step 03.15, not here.

**Tests.** Header JSON round trip (both modes), unknown extra fields preserved after `changePassword`, `formatVersion: 2` → `RemoteFormatException`;
create → unlock with password → same master key bytes; unlock with recovery key → same; wrong password/recovery → typed exceptions; change password
→ old password fails, new works, recovery still works, blob created before the change still decrypts; `vault.json` is written after the device file
(assert order with `beforeOp`); device register/heartbeat throttling (fake clock); revoke twice keeps the first record.
Use a test-only `KdfParams` floor override (`memoryKiB: 1024, iterations: 1`) via a constructor parameter `@visibleForTesting KdfParams? floorOverride`
so tests stay fast; one test uses the real floor to prove it works (tag it `@Tags(['slow'])`).

**Verify.** `cd packages/tephra_sync; dart test test/remote`.

**Pitfalls.** `vault.json` must stay readable without any key (it is the entry point). Never put the master key, password or recovery key in it.
The vault name is visible in `vault.json` and as the Drive folder name (`Tephra/<vault name>/`) by design; the wizard tells the user this.

---

### 03.7 — Hybrid logical clock, journals, remote history and snapshots

**Purpose.** Write this device's changes as append-only journal batches, read everyone's journals, and compute per path the head, the leaves and forks.

**Files.** `lib/src/model/hlc.dart`, `lib/src/model/journal_entry.dart`, `lib/src/model/journal_batch.dart`,
`lib/src/remote/journal_writer.dart`, `lib/src/remote/journal_reader.dart`, `lib/src/remote/remote_history.dart`,
`lib/src/remote/snapshot_store.dart`; tests for each under `test/model/` and `test/remote/`.

**Implementation.**
1. **HLC** `Hlc { final int millis; final int counter; final String deviceId; }`, ordered by `(millis, counter, deviceId)`.
   String form (sortable): `millis` padded to 15 digits + `.` + `counter` padded to 6 digits + `.` + deviceId, e.g. `001760175000000.000003.6f1c…`.
   `HlcClock(Clock clock, String deviceId, {int millis, int counter})` keeps state `(l, c)`, persisted in `meta.hlcMillis/hlcCounter` after every change:
   - **local event / send** (`tick()`): `pt = clock.now().toUtc().millisecondsSinceEpoch`; `l2 = max(l, pt)`; `c2 = (l2 == l) ? c + 1 : 0`; store; return `Hlc(l2, c2, me)`.
   - **receive** (`observe(Hlc m)`, called for every remote entry read): `pt = now`; `l2 = max(l, m.millis, pt)`;
     if `l2 == l && l2 == m.millis` → `c2 = max(c, m.counter) + 1`; else if `l2 == l` → `c2 = c + 1`; else if `l2 == m.millis` → `c2 = m.counter + 1`;
     else `c2 = 0`. If `m.millis > pt + 24 h`, log a warning "remote clock far ahead" (still accept).
2. **Journal entry** (`JournalEntry`, immutable). Entry id = `<deviceId>:<seq>`. JSON (inside a batch):
   ```json
   { "seq": 41, "hlc": "001760175000000.000003.<deviceId>", "time": "2026-10-11T09:30:00.000Z",
     "op": "put", "path": "Folder/Note.md", "fromPath": null,
     "hash": "<sha256 hex of plaintext>", "size": 1234, "mtime": 1760175000000,
     "blobKeys": ["blobs/<hex>"], "parent": "<entryId or null>", "targetParent": null, "mergedParent": null }
   ```
   - `op: "put"` — the file at `path` now has content `hash` stored in `blobKeys`. `parent` = id of the head at `path` the writer had seen (null if none).
   - `op: "delete"` — the file at `path` is deleted; `hash`/`blobKeys` = the deleted version (kept for history); `parent` = head at `path`.
   - `op: "move"` — the file moved from `fromPath` to `path` without content change; `hash`/`blobKeys` = its content; `parent` = head at `fromPath`;
     `targetParent` = head at `path` if one existed (it must be a delete), else null. A move acts as a delete at `fromPath` and a put at `path`.
   - `mergedParent` — set only when this entry resolves a fork: the id of the other leaf it merged (step 03.10).
   - `deviceId` is not repeated per entry; it comes from the batch.
3. **Journal batch** = one remote object `journals/<deviceId>/<firstSeq>.json.enc` (purpose `journal`; plain JSON if encryption is off):
   `{"v":1,"deviceId":"…","firstSeq":41,"lastSeq":57,"createdAt":"…","entries":[…]}`. Rules: `entries` are contiguous seqs `firstSeq..lastSeq`;
   at most 1,000 entries per batch; the next batch starts at `lastSeq + 1`; a batch key is never written twice with different content.
4. `JournalWriter(SyncProvider, ObjectCipher, SyncStateStore, HlcClock)`:
   - `stage(...)` builds entries in memory with `seq = nextSeq++` (persisted only on commit) and `hlc = tick()`.
   - `commit()` (the **commit point** of a sync cycle): serialise the batch → `seal` → **first** store it in `pending_ops` (`kind: 'journalBatch'`,
     payload = `{firstSeq, lastSeq, key, bytesBase64}`, state `pending`) → `provider.put(key, bytes)` → set `meta.nextSeq = lastSeq + 1` and
     `remove pending op` in one transaction → insert the entries into `remote_entries` (they are now remote facts).
   - `recover()` (start of every cycle): for each pending `journalBatch`: `list(key)`; if present and `get(key)` equals the stored bytes → finish the
     transaction above; if present with different bytes → clone conflict (item 7); if absent → `put` the stored bytes again, then finish.
5. `JournalReader(SyncProvider, ObjectCipher, SyncStateStore, HlcClock)`:
   - `refresh({Set<String>? changedKeys})`: determine device folders (`list('journals/')`, unique device ids); for each device (including this one):
     read batches whose `firstSeq == cursor + 1`, in order, until the next expected one is missing (Drive listings may lag; never skip a gap).
     Decrypt, validate (`deviceId` matches folder, seqs contiguous), `observe` every HLC, insert entries, `setCursor(device, lastSeq)`.
     A batch that fails to decrypt → `TamperedDataException` logged at `severe`, that device's reading stops at that point (never skipped), UI shows a
     "damaged remote data" error naming the device.
   - Entries of a **revoked** device (`devices/<id>.revoked.json.enc`, stored as `journal_cursors.revoked_after_seq`) with `seq > lastAcceptedSeq` are
     ignored (not deleted).
   - With `changedKeys` (from `changesSince`), only devices whose journal keys changed are listed again.
6. `RemoteHistory` (pure, built from `List<JournalEntry>`; recomputed after each refresh and materialised into `remote_heads`):
   - "Entries touching path P" = entries with `path == P`, plus moves with `fromPath == P`.
   - `parentAt(e, P)` = `e.parent` if (`e.op` is put/delete and `e.path == P`) or (`e.op == move` and `e.fromPath == P`); = `e.targetParent` if
     `e.op == move && e.path == P`.
   - Effective op at P: put → present; delete → deleted; move with `path == P` → present; move with `fromPath == P` → deleted (moved away).
   - **Leaves at P** = entries touching P that are not referenced by `parentAt(x, P)` or `x.mergedParent` of any other entry `x` touching P.
   - **Head at P** = the leaf with the greatest HLC. **Fork at P** = more than one leaf.
   - `isAncestorOrEqual(String ancestorId, String entryId, String path)` — breadth-first walk over `parentAt` and `mergedParent` links, limited to
     entries touching `path`; unknown ids end the walk (return false).
   - `lowestCommonAncestor(String a, String b, String path)` — collect all ancestors-or-self of `a`; walk ancestors of `b` in descending HLC order;
     return the first one in the set, or null.
   - `livePaths()` → paths whose head is "present". `versions(path)` → entries touching path in descending HLC (used by history, step 03.21).
7. **Clone detection.** If `refresh` finds in this device's own folder a batch with `firstSeq >= meta.nextSeq` that has no matching pending op, another
   installation uses the same device id. Throw `DeviceCloneDetectedException`. The engine then: generates a new UUID, stores it as `syncDeviceId`,
   resets `nextSeq = 1`, clears `synced_files` and `bases` (the next cycle behaves like a first "merge both" sync, which keeps every file), registers
   the new device file, logs `deviceIdRenewed`.
8. **Snapshots (compaction).** After a commit, if `lastSeq` crossed a multiple of **500** since `meta.lastSnapshotSeq`, write
   `snapshots/<me>/<lastSeq>.json.enc` (purpose `snapshot`; content = gzip of UTF-8 JSON):
   `{"v":1,"deviceId":"…","seq":1500,"createdAt":"…","hlc":"…","covers":{"<deviceId>":<lastSeq read>,…},"entries":[ … ]}` where `entries` =
   for every path: all leaves, plus for each forked path the lowest common ancestor of its leaves. Each entry JSON also carries `"deviceId"`.
   Keep this device's newest **3** snapshots and delete its older snapshot objects (only the owner deletes them).
   **Bootstrap** of a device with an empty `remote_entries` table: list `snapshots/`, decrypt the snapshot with the greatest sum of `covers` values
   (ties: greatest `hlc`), insert its entries, set each cursor to `covers[device]`, then `refresh()` reads the rest. Journals are **never deleted** in
   Phase 3 (they are small and are the source of remote history).

**Tests.** HLC: monotonic under a clock that goes backwards; `observe` rules (all four branches) with exact expected values; string ordering equals
tuple ordering. Journal: batch JSON round trip; writer commit order (pending op stored before `put`; assert with `beforeOp` throwing at `put` →
pending op survives, `recover()` completes it on next run; crash after `put` before DB update → `recover()` finishes without re-`put` of different
bytes); reader stops at gaps, resumes when the gap fills; revoked device entries beyond `lastAcceptedSeq` ignored; tampered batch stops that device only.
RemoteHistory: linear chain (head = last); fork (two puts with same parent) → two leaves, head = higher HLC; merge entry with `mergedParent` → one leaf;
move chain across paths; delete then re-create; LCA on a diamond; unknown parent ids. Snapshot: written at 500, keeps newest 3, bootstrap from snapshot +
journals gives the same heads as replaying all journals (property test over a seeded random history of 3 devices × 2,000 entries).

**Verify.** `cd packages/tephra_sync; dart test test/model test/remote`.

**Pitfalls.** Never order entries by wall-clock `time` — only by HLC. Never "fix" a gap by skipping. The engine must read its **own** journal too
(that is how a crash between `put` and the DB update is repaired).

---

### 03.8 — Local scanner, path rules, case sensitivity, Windows names

**Purpose.** Produce the local side of the planner input: `path → (hash, size, mtime)` for every file that participates in sync.

**Files.** `lib/src/local/local_file_state.dart`, `lib/src/local/sync_path_rules.dart`, `lib/src/local/local_scanner.dart`,
`lib/src/local/case_sensitivity.dart`, `lib/src/local/windows_names.dart`; tests under `test/local/`.

**Implementation.**
1. `LocalFileState { VaultPath path; String hash; int size; int mtimeMs; }`.
2. `SyncPathRules.participates(VaultPath p, int size, SelectiveSyncRules rules)` returns false (path is ignored by sync on **this** device) when any is true:
   - any segment is `.obsidian`, `.git`, `.trash`, `node_modules`;
   - the path starts with `.tephra/` and is **not** one of the synced Tephra files: `.tephra/settings.json`, `.tephra/hotkeys.json`,
     `.tephra/bookmarks.json`, `.tephra/types.json`, `.tephra/workspace.json`, `.tephra/stickies.json`
     (so `.tephra/vault.json`, `.tephra/cache/**`, `.tephra/history/**` never sync);
   - any other segment starts with `.` (hidden files/folders);
   - the path is inside one of `rules.excludedFolders`, or its extension is excluded (including `mobileMode` extensions), or `size > rules.maxFileSizeBytes`;
   - the file name ends with `.tephra-tmp` or contains `.tephra-case-` (temporary names used by the executor) .
   Non-participating paths are removed from **local, base and remote** inputs before planning, so an excluded file is never treated as deleted.
3. `LocalScanner(VaultFileSystem fs, SyncStateStore store)`. `scan(SelectiveSyncRules rules)`:
   - If `fs.stat(VaultPath.root)` fails or `fs.list()` throws → `VaultFolderUnavailableException` (never return an empty map in that case).
   - `fs.list(recursive: true)` → files only → filter by rules → for each: if `local_hash_cache` has the same `(size, mtime)` use its hash, else
     `readBytes` → `contentHash` → `putCachedHash`. Hash at most 4 files concurrently. Returns `Map<VaultPath, LocalFileState>`.
   - Runs inside the sync worker isolate (never on the UI isolate).
4. `CaseSensitivity.detect(VaultFileSystem fs)`: write `.tephra/cache/case-probe-<8 random hex>.tmp` (lower-case), `stat` the upper-case form of the
   same path, delete the probe. Found → case-insensitive. Store in `meta.caseInsensitive` once per vault (re-detect if the vault root path changes).
5. `WindowsNames.isValid(String segment)` false when: contains any of `< > : " / \ | ? *` or a control char (code < 32); ends with `.` or space;
   base name (before the first `.`, case-insensitive) is one of `CON PRN AUX NUL COM1–COM9 LPT1–LPT9`. `WindowsNames.sanitize(segment)`: replace each
   invalid char with `_`, strip trailing dots/spaces (replace with `_`), append `_` to reserved base names. Used only on Windows devices (step 03.10).

**Tests.** Rules table test (each bullet, plus synced `.tephra` files allowed); excluded folder files are absent from the scan; scan uses the cache
(count `readBytes` calls on a `MemoryVaultFileSystem` wrapper); missing root → exception; case probe on a `MemoryVaultFileSystem` in both modes
(see Pitfalls); Windows name validity and sanitising (20 cases).

**Verify.** `cd packages/tephra_sync; dart test test/local`.

**Pitfalls.** `MemoryVaultFileSystem` probably has no case-insensitive mode. Add an optional named constructor parameter
`MemoryVaultFileSystem({bool caseInsensitive = false})` in `tephra_vault` (lookups and `move` conflicts compare `caseKey` when true; listing returns the
stored case). This is an additive change to an implementation, not to the `VaultFileSystem` contract; note it in `PROGRESS.md`. Run `tephra_vault`
tests after the change.

---

### 03.9 — Three-way merge (Markdown, plain text, `.tephra` JSON) and conflict naming

**Purpose.** Merge concurrent edits when safe; otherwise produce a deterministic conflict-copy name.

**Files.** `lib/src/merge/line_codec.dart`, `lib/src/merge/line_diff.dart`, `lib/src/merge/three_way_merge.dart`,
`lib/src/merge/frontmatter_merge.dart`, `lib/src/merge/json_merge.dart`, `lib/src/merge/merge_kind.dart`, `lib/src/merge/conflict_naming.dart`;
tests under `test/merge/`.

**Implementation.**
1. `MergeKind kindOf(VaultPath p)`: `markdown` for `md`; `plainText` for `txt`; `jsonObject` for the six synced `.tephra/*.json` files;
   `binary` for everything else (including `canvas`, `base`, `pdf`, images).
2. Text inputs are decoded with `TextDocument.decode` (conventions §6.2). Merge works on the normalised `\n` text. The result is encoded with the
   **local** document's BOM and line ending. If any of the three inputs is `malformed` → no merge (conflict).
3. **Line codec** (the Dart `diff_match_patch` package has no public lines-to-chars helper, so write it): split each text into lines keeping the
   trailing `\n` on every line except possibly the last; map each distinct line to one UTF-16 code unit, starting at `0x0100`, skipping the surrogate
   range `0xD800–0xDFFF`; same map shared by all three texts; if more than 60,000 distinct lines → no merge (conflict).
4. **Line diff** `List<Hunk> lineHunks(List<String> base, List<String> other)`: encode both, `DiffMatchPatch()..diffTimeout = 5.0`,
   `diff(encBase, encOther, false)` (third argument `false` = no extra line-mode pass, we already encoded lines), then walk the diffs keeping a base
   line index and emit `Hunk { int baseStart; int baseEnd; List<String> lines; }` (replace base lines `[baseStart, baseEnd)` with `lines`; an insertion
   has `baseStart == baseEnd`). Adjacent delete+insert pairs form one hunk.
5. **Three-way merge** `MergeOutcome merge3(String base, String local, String remote)`:
   1. If `local == remote` → clean, result `local`. If `local == base` → clean, `remote`. If `remote == base` → clean, `local`.
   2. `hl = lineHunks(base, local)`, `hr = lineHunks(base, remote)`.
   3. Two hunks (one from each side) **clash** when their base ranges overlap, or touch (`a.baseEnd == b.baseStart` or `b.baseEnd == a.baseStart`), or
      both are insertions at the same `baseStart` — **unless** both hunks are identical (same range and same lines), in which case keep one.
   4. If any clash → `MergeOutcome.conflict`. Otherwise apply all hunks to the base lines in descending `baseStart` order → `MergeOutcome.clean(text)`.
   This is deliberately conservative (like Git): two edits separated by at least one unchanged line merge; edits on the same or neighbouring lines conflict.
6. **Frontmatter-aware merge** (Markdown only), used before step 5:
   1. Split each text into frontmatter YAML + body with the Phase 1/2 rule (conventions §6.4: first line `---` … next `---` line).
   2. If all three have valid frontmatter whose YAML root is a map (or a side has none → treat as an empty map) → merge frontmatter key-wise:
      for each top-level key, compare base/local/remote values (deep equality of decoded YAML): unchanged on one side → take the other side's;
      changed identically → take it; changed differently on both sides → **conflict**. Keys added on one side are added; keys removed on one side and
      unchanged on the other are removed.
   3. Build the merged frontmatter text by starting from the **local** frontmatter text with `YamlEditor` and applying only the remote side's changes
      (`update([key], value)` / `remove([key])`); this keeps the local formatting and comments. Body: `merge3(baseBody, localBody, remoteBody)`.
      Clean only if both parts are clean. If no side changed the frontmatter, it is copied byte-for-byte.
   4. If any frontmatter is invalid YAML or not a map → plain `merge3` on the whole text.
7. **JSON merge** (`jsonObject` kind): decode all three as JSON objects; top-level key-wise merge with the same rules as item 6.2, recursing one level
   into objects whose top-level key is a device id (this makes `workspace.json` and `stickies.json` — which are keyed by device id — merge cleanly).
   Output: `JsonEncoder.withIndent('  ')` + trailing `\n`. Invalid JSON on any side → conflict.
8. **Conflict naming** `String conflictCopyName(VaultPath path, DateTime localTime, String deviceName, bool Function(VaultPath) exists)`:
   `<stem> (conflict YYYY-MM-DD HH-mm <DeviceName>).<ext>` in the same folder, e.g. `Note (conflict 2026-10-11 14-05 Pixel 8).md`. `DeviceName` is
   sanitised: remove `\ / : * ? " < > |` and control chars, collapse spaces, trim, max 40 chars, `Device` if empty. If the name exists, append
   ` 2`, ` 3`, … inside the parentheses (`(conflict 2026-10-11 14-05 Pixel 8 2)`). Files without extension: no trailing dot.
   `String caseConflictName(VaultPath path, exists)` → `<stem> (case conflict).<ext>`, then `(case conflict 2)`, …

**Tests.** (Each with exact expected strings.) Identical edits; one side unchanged; edits in different paragraphs separated by a blank line → clean;
same line → conflict; neighbouring lines → conflict; both insert at end of file → conflict unless identical; deletion vs edit of the same line →
conflict; last line without `\n`; CRLF local doc → result re-encoded CRLF; BOM kept; 60,001 distinct lines → conflict; frontmatter: different keys
changed → clean and body merged; same key changed differently → conflict; key removed one side; comments in local YAML preserved; invalid YAML →
falls back to line merge; JSON: workspace.json with two device keys edited on two sides → clean; conflict naming with collisions, unsafe device names,
no extension; case-conflict naming. Property test: for 2,000 seeded random (base, local, remote) triples where local and remote edit disjoint line
ranges separated by ≥ 1 unchanged line, the merge is clean and contains both edits.

**Verify.** `cd packages/tephra_sync; dart test test/merge`.

**Pitfalls.** If `diff_match_patch` 0.4.1 fails to resolve or compile with Dart 3.13, write a line-level Myers diff yourself in `line_diff.dart`
behind the same `lineHunks` function (the algorithm is public knowledge; write your own code) and remove the dependency. Never insert Git-style
`<<<<<<<` markers into notes (they would damage Obsidian notes); conflicts always produce a separate copy.

---

### 03.10 — The planner (pure function): decision table, renames, case conflicts, delete guard

**Purpose.** Decide, without any I/O, what a sync cycle must do. This is the heart of "no data loss": every row of the table below must keep every version.

**Files.** `lib/src/planner/sync_action.dart` (the sealed classes), `lib/src/planner/base_update.dart`, `lib/src/planner/planner_input.dart`,
`lib/src/planner/sync_plan.dart`, `lib/src/planner/planner.dart`, `lib/src/planner/rename_detector.dart`,
`lib/src/planner/case_conflict_resolver.dart`, `lib/src/planner/delete_guard.dart`, `lib/src/model/base_state.dart`;
tests `test/planner/decision_table_test.dart`, `renames_test.dart`, `case_conflicts_test.dart`, `delete_guard_test.dart`.

**Implementation.**
1. **Actions** — exactly the eight variants of conventions §7.6, `final class X extends SyncAction`, all immutable with value equality:
   ```dart
   sealed class SyncAction { const SyncAction(this.path); final VaultPath path; }
   final class Upload extends SyncAction {        // publish local content at path as a 'put' entry
     final String localHash; final String? parent; final String? mergedParent;
     final List<String>? reuseBlobKeys; }         // non-null: content already remote (no blob upload), e.g. closing a benign fork
   final class Download extends SyncAction {      // replace/create local file with the remote entry's content
     final JournalEntry entry; final String? expectedLocalHash; }   // null = local file must be absent
   final class Merge extends SyncAction {         // three-way merge, then write locally and publish
     final MergeKind kind; final String localHash; final JournalEntry remote;
     final VaultPath basePath; final String? baseEntryId;           // baseEntryId null = use the stored base text of basePath
     final String? mergedParent; }
   final class ConflictCopy extends SyncAction {  // keep both: local content → conflict copy, remote content → path
     final String localHash; final JournalEntry remote; final String? mergedParent; }
   final class DeleteLocal extends SyncAction { final String expectedHash; final String remoteEntryId; }
   final class DeleteRemote extends SyncAction { final String parent; final String hash; final List<String> blobKeys; }
   final class RenameLocal extends SyncAction { final VaultPath to; final String expectedHash; final String remoteEntryId; }
   final class RenameRemote extends SyncAction { final VaultPath to; final String parent; final String? targetParent;
     final String hash; final List<String> blobKeys; }
   ```
   Bookkeeping that needs no file or remote change is **not** an action: `BaseUpdate` (`BaseUpdate.set(path, hash, version, blobKeys, size, mtime)`
   / `BaseUpdate.remove(path)`) in a separate list.
2. **Input / output.**
   ```dart
   final class PlannerInput {
     final Map<VaultPath, LocalFileState> local;      // already filtered by SyncPathRules
     final Map<VaultPath, BaseState> base;            // from synced_files (filtered)
     final RemoteHistory remote;                      // from step 03.7 (filtered: non-participating paths ignored)
     final String deviceId; final bool caseInsensitive; final bool isWindows;
     final Map<VaultPath, DeleteDecision> deleteDecisions;   // approve | keep, from the user (item 8)
   }
   final class SyncPlan { final List<SyncAction> actions; final List<BaseUpdate> baseUpdates;
     final List<VaultPath> heldDeletes; final List<PlanNote> notes; }      // notes → sync log lines
   abstract final class Planner { static SyncPlan plan(PlannerInput input); }   // pure, deterministic, no I/O, no clock
   ```
   `actions` are sorted by (phase, path): phase 1 `RenameLocal`, 2 `DeleteLocal`, 3 `Download`, 4 `Merge`, 5 `ConflictCopy`, 6 `Upload`,
   7 `RenameRemote`, 8 `DeleteRemote`.
3. **Classification of one path P.** `B` = base (may be absent). `L` = local state (may be absent). `H` = head at P (may be absent).
   Local status: **L0** (no L, no B) · **L=** (L.hash == B.hash) · **LM** (L and B, hashes differ) · **LC** (L, no B) · **LD** (no L, B present).
   Remote status (effective op of H per step 03.7):
   - **R0**: H absent, or H deleted and B absent.
   - **Rgone**: H absent and B present (history unknown, e.g. ignored revoked-device entries).
   - **RC**: H present and B absent.
   - **R=**: H present, B present, and (`H.id == B.version`, or `isAncestorOrEqual(B.version, H.id)` and `H.hash == B.hash`).
   - **RM**: H present, B present, `isAncestorOrEqual(B.version, H.id)`, `H.hash != B.hash`.
   - **RD**: H deleted, B present, `isAncestorOrEqual(B.version, H.id)`.
   - **RF+** / **RF−**: B present and `B.version` is **not** an ancestor-or-equal of H (a fork relative to our base); `+` if H present, `−` if deleted.
   "Mine" below = `B.version` was written by this device (its id starts with `<deviceId>:`). "Mergeable" = `MergeKind` is not `binary`.
4. **Rule zero (before the table):** if L and H are both present and `L.hash == H.hash` → no action; `BaseUpdate.set(P, H)`. This also settles
   benign forks (both sides reached the same content).
5. **Decision table** (every combination; rows not listed cannot occur):

   | # | Local | Remote | Actions | Why it is safe |
   |---|---|---|---|---|
   | 1 | L0 | R0 | none | nothing exists |
   | 2 | L0 | RC | `Download(P, H, expected: null)` | new remote file |
   | 3 | L= | R= | none (+`BaseUpdate` if `H.id != B.version`) | in sync |
   | 4 | L= | RM | `Download(P, H, expected: L.hash)` | local equals base; base version stays in remote history |
   | 5 | L= | RD | `DeleteLocal(P)` (to `.trash/`) | remote deleted; local copy goes to vault trash, remote keeps history |
   | 6 | L= | Rgone | `Upload(P, parent: null)` + note `republished` | keep data whose remote history is unknown |
   | 7 | L= | RF+ | Mine: `Merge(P, basePath: P, baseEntryId: LCA(B.version, H), remote: H, mergedParent: B.version)` (binary: `ConflictCopy(..., mergedParent: B.version)`). Not mine: `Download(P, H, expected: L.hash)` | our published version lost an HLC race; its author (us) merges it; another author's losing leaf is merged by that author |
   | 8 | L= | RF− | Mine: `Upload(P, parent: H.id, mergedParent: B.version)` + note `keptEditedFileDeletedElsewhere`. Not mine: `DeleteLocal(P)` | an edit never loses against a concurrent delete |
   | 9 | LM | R= | `Upload(P, parent: H.id)` | local edit |
   | 10 | LM | RM | Mergeable: `Merge(P, basePath: P, baseEntryId: null, remote: H)`. Binary: `ConflictCopy(P, H)` | both edited |
   | 11 | LM | RD | `Upload(P, parent: H.id)` + note `keptEditedFileDeletedElsewhere` | edit wins over delete |
   | 12 | LM | Rgone | `Upload(P, parent: null)` + note `republished` | keep data |
   | 13 | LM | RF+ | Mergeable: `Merge(P, basePath: P, baseEntryId: LCA(B.version, H), remote: H, mergedParent: B.version)`. Binary: `ConflictCopy(P, H, mergedParent: B.version)` | merges our edit and the lost leaf |
   | 14 | LM | RF− | `Upload(P, parent: H.id, mergedParent: B.version)` + note `keptEditedFileDeletedElsewhere` | edit wins over delete |
   | 15 | LC | R0 | `Upload(P, parent: H?.id)` (H is a delete head or absent) | new local file |
   | 16 | LC | RC | `ConflictCopy(P, H)` (rule zero already handled equal content) | two different files created with one name; never auto-merge without a base |
   | 17 | LD | R= | `DeleteRemote(P, parent: H.id, hash: B.hash, blobKeys: B.blobKeys)` (subject to the delete guard) | remote history keeps the content |
   | 18 | LD | RM | `Download(P, H, expected: null)` + note `restoredDeletedFileChangedElsewhere` | a remote edit wins over a local delete |
   | 19 | LD | RD | `BaseUpdate.remove(P)` | deleted on both sides |
   | 20 | LD | Rgone | `BaseUpdate.remove(P)` | gone everywhere; content is in local `.trash/` or remote history |
   | 21 | LD | RF+ | `Download(P, H, expected: null)` + note `restoredDeletedFileChangedElsewhere` | remote content wins over a delete |
   | 22 | LD | RF− | `BaseUpdate.remove(P)` | deleted on both sides |
   | 23 | L0 | (H deleted) | none | already deleted |

   When a row says "LCA" and `RemoteHistory.lowestCommonAncestor` returns null, or the LCA's blobs later turn out to be missing, the executor falls back
   to `ConflictCopy` (never to an overwrite).
6. **Rename detection (runs before the table; paired paths are removed from table processing).**
   - **Local moves:** `D` = paths in state LD; `C` = paths in state LC. For each `c` in `C` (sorted), pick an unpaired `d` in `D` with
     `B(d).hash == L(c).hash`, preferring (1) same file name in another folder, (2) same folder, (3) smallest path. Pair only if the remote at `c` is R0.
     Then by the remote status of `d`:

     | Remote at `d` | Actions |
     |---|---|
     | R= | `RenameRemote(d → c, parent: H(d).id, targetParent: H(c)?.id, hash: B(d).hash, blobKeys: B(d).blobKeys)` |
     | RM | `Download(c, H(d), expected: L(c).hash)` then `RenameRemote(d → c, parent: H(d).id, targetParent: H(c)?.id, hash: H(d).hash, blobKeys: H(d).blobKeys)` |
     | H(d) is a move away to `x` with `x == c` | `BaseUpdate.remove(d)`, `BaseUpdate.set(c, H(c))` (both devices did the same move) |
     | H(d) is a move away to `x != c`, `x` absent locally | `RenameLocal(c → x, expectedHash: L(c).hash, remoteEntryId: H(x).id)` (remote location wins; same content) |
     | anything else (RD, RF±, Rgone, `x` exists locally) | do not pair; both paths go through the table |
   - **Remote moves:** for each head `H` at `t` with `op == move`, `fromPath == f`, `B(f)` present, `B(t)` absent, local `t` absent:
     - L(f) = L= and `H.hash == B(f).hash` → `RenameLocal(f → t, expectedHash: L(f).hash, remoteEntryId: H.id)`.
     - L(f) = LM → `RenameLocal(f → t, …)` then, at `t`: if `H.hash == B(f).hash` → `Upload(t, parent: H.id)`; else mergeable →
       `Merge(t, basePath: f, baseEntryId: null, remote: H)`, binary → `ConflictCopy(t, H)`.
     - Any other combination → no special handling; both paths go through the table (this may re-download content; it never loses it).
   - **Folders** are implicit: a folder exists remotely when a file below it exists. A folder rename is a set of file moves. Empty folders are not
     synced (documented limitation). After a cycle, the executor removes local folders that became empty **because of** that cycle's `DeleteLocal`/`RenameLocal`.
7. **Case conflicts and invalid names (case-insensitive / Windows devices only; runs before rename detection).**
   - Group remote live paths by `caseKey`. In a group with more than one path, **keep** the path whose oldest entry (minimum HLC among entries touching it)
     is smallest; every other path `x` gets `RenameRemote(x → caseConflictName(x), parent: H(x).id, targetParent: null, hash: H(x).hash, blobKeys: H(x).blobKeys)`.
     If this device's base contains `x` (the local file on disk is `x`'s content), also emit `RenameLocal(x → caseConflictName(x), expectedHash: B(x).hash, remoteEntryId: H(x).id)`.
     Paths `x` are excluded from the rest of this cycle's planning. Example: Android created `Note.md` (first) and `note.md`; a Windows device renames
     `note.md` to `note (case conflict).md` for everyone.
   - On Windows (`isWindows`), every remote live path with a segment where `WindowsNames.isValid` is false gets
     `RenameRemote(x → sanitised path, …)` (if the sanitised path is taken, append ` 2`, ` 3` to the stem); `x` is excluded from local planning.
   - If two Windows devices do this concurrently, both write the same move with the same content; rule zero makes the resulting fork benign.
   - On a case-insensitive device a **local** case-only rename (`note.md` → `Note.md`) appears as LD(`note.md`) + LC(`Note.md`) with equal hash and is
     paired by item 6 into a `RenameRemote`. The executor performs case-only `RenameLocal` in two steps (step 03.11).
8. **Large-delete guard** (`DeleteGuard`): count `DeleteLocal` + `DeleteRemote` actions that are not part of a rename and not already approved in
   `deleteDecisions`. Trigger if `count > 50`, or `count >= 3 && count > 0.20 × max(1, base.length)`. When triggered: remove those delete actions from
   `actions`, put their paths in `heldDeletes` (all other actions stay). For paths with decision **approve**: keep the delete action. For decision
   **keep**: a held `DeleteRemote` (file missing locally) becomes `Download(P, H(P), expected: null)`; a held `DeleteLocal` (deleted remotely) becomes
   `Upload(P, parent: H(P).id)`. Decisions are consumed once used.

**Tests.** `decision_table_test.dart`: one test per row (1–23) building inputs by hand with a small helper DSL (e.g. `world.base('a.md', 'h1', 'devA:1')`,
`world.local('a.md','h2')`, `world.remotePut('devB:5', 'a.md', 'h3', parent: 'devA:1')`) and asserting the exact action list and base updates; rule zero;
binary vs mergeable variants of rows 7, 10, 13, 16; "mine" vs "not mine" variants of 7 and 8; LCA null. `renames_test.dart`: every row of both rename tables,
pairing preference order, folder rename of 30 files → 30 `RenameRemote`. `case_conflicts_test.dart`: Android-made `Note.md`+`note.md` on a Windows device;
local case-only rename; invalid Windows names (`a:b.md`, `CON.md`, `trailing.` ) → sanitised; case-sensitive device does nothing. `delete_guard_test.dart`:
thresholds (2 of 5 no guard, 3 of 10 guard, 51 of 10,000 guard, 50 of 10,000 no guard), approve and keep decisions. Determinism: planning the same
input twice gives identical plans; shuffled map insertion order gives identical plans.

**Verify.** `cd packages/tephra_sync; dart test test/planner`.

**Pitfalls.** The planner must never read files, the clock or randomness. Do not "simplify" rows 7, 8, 13, 14 — they are what makes concurrent offline
edits converge without losing the losing side. Excluded paths (step 03.8) must be filtered from local, base **and** remote before classification.

---

### 03.11 — The executor and `SyncEngine.syncOnce` (crash-safe, idempotent, resumable)

**Purpose.** Carry out a plan so that a crash or network loss at **any** point leaves a state the next cycle completes without loss.

**Files.** `lib/src/executor/executor.dart`, `lib/src/executor/crash_injector.dart`, `lib/src/executor/editor_guard.dart`,
`lib/src/engine/sync_engine.dart`, `lib/src/engine/sync_lock.dart`, `lib/src/engine/sync_report.dart`, `lib/src/engine/sync_progress.dart`,
`lib/src/engine/sync_trigger.dart`, `lib/src/engine/sync_cancel_token.dart` (only if no `CancelToken` exists in core), `lib/src/model/sync_log_entry.dart`,
`lib/src/model/conflict_record.dart`; tests `test/executor/executor_test.dart`, `test/engine/sync_engine_test.dart`, `test/engine/sync_lock_test.dart`.

**Implementation.**
1. `CrashInjector` — `void Function(CrashPoint point, VaultPath? path)?` called at these named points; tests throw `SimulatedCrash` from it:
   `cycleStart`, `afterRemoteRefresh`, `afterScan`, `beforeLocalWrite`, `afterLocalWrite`, `afterLocalStateUpdate`, `beforeBlobUpload`,
   `afterBlobUpload`, `beforeJournalPut`, `afterJournalPut`, `afterCommitStateUpdate`, `beforeSnapshot`, `cycleEnd`.
2. `EditorGuard` (implemented by the app, step 03.16; a no-op default in the package):
   `Future<bool> mayReplace(VaultPath path, String expectedHash)` — the app flushes any unsaved editor buffer for `path`, then answers `true` only if
   the file on disk still has `expectedHash` and the editor has no unsaved edits. `false` → the executor skips that action this cycle (re-planned next cycle).
3. **Precondition checks (idempotency).** Before every local change the executor re-reads the target: `Download` requires the current local hash to equal
   `expectedLocalHash` (or the file to be absent when `null`); `DeleteLocal`/`RenameLocal` require `expectedHash`; `Merge`/`ConflictCopy` require
   `localHash`. If the local file already has the **target** content (e.g. a previous run wrote it before crashing), only the state update is done.
   Any other mismatch → skip the action, log `fine`, re-plan next cycle. Every local overwrite of an existing text file (`md`, `txt`, `canvas`, `base`,
   `.tephra` json) first calls `LocalHistory.snapshot(path, currentBytes, reason: beforeSyncOverwrite)` (step 03.21).
4. **Per-action behaviour.**
   - `RenameLocal(from → to)`: if `from.caseKey == to.caseKey` (case-only) → `fs.move(from, tmp)` then `fs.move(tmp, to)` where
     `tmp = <from>.tephra-case-<8 hex>`; else if `to` exists locally → move `from` to `conflictCopyName(to, …)` instead and log; else `fs.move(from, to)`.
     State: move the base row to `to`.
   - `DeleteLocal`: `fs.delete(path, mode: TrashMode.vaultTrash)` (always vault trash, whatever the user's trash setting), then `removeBase`.
   - `Download`: `BlobStore.getFile(entry.blobKeys, expectedPlainHash: entry.hash)` (full verification) → `EditorGuard.mayReplace` (if file exists) →
     history snapshot → `fs.writeBytes(path, bytes)` (atomic temp + rename, conventions §7.2) → `putBase(path, entry)` and, for mergeable kinds,
     `putBaseText`.
   - `Merge`: load base text (stored base of `basePath`, or download `baseEntryId`'s content), local bytes, remote content; run step 03.9's merge for the
     kind. Clean → write merged text locally (guard + snapshot), then stage `Upload(path, parent: remote.id, mergedParent)` of the merged bytes. Not clean,
     or base unavailable → behave exactly like `ConflictCopy`.
   - `ConflictCopy`: `copy = conflictCopyName(path, now, deviceName, exists)`; **first** check whether a file named `<stem> (conflict …)` in the same folder
     already has `localHash` (a previous crashed run) and reuse it; otherwise `fs.writeBytes(copy, localBytes)`; then perform a `Download(path, remote)`
     (guard + snapshot); then stage `Upload(copy, parent: null)`. If `mergedParent != null` also stage
     `Upload(path, parent: remote.id, mergedParent, reuseBlobKeys: remote.blobKeys)` to close the fork. Insert a `conflicts` row and a log line.
   - `Upload`: re-hash the local file; if it no longer equals `localHash` → skip. Else `BlobStore.putFile` (unless `reuseBlobKeys`) and stage a `put` entry.
   - `RenameRemote` / `DeleteRemote`: stage a `move` / `delete` entry (no blob upload; blobs already exist).
5. **Cycle order** in `SyncEngine.syncOnce` (the order is the crash-safety argument; keep it):
   1. Acquire `SyncLock` (item 7); else throw `SyncLockedException`.
   2. `JournalWriter.recover()`.
   3. `provider.changesSince(meta.changesCursor)` → `JournalReader.refresh(changedKeys)` (full listing if `cursorWasReset` or first run) → check this
      device's revocation (→ `DeviceRevokedException`) → rebuild `RemoteHistory`, materialise heads.
   4. `LocalScanner.scan`.
   5. `Planner.plan` (with stored delete decisions) → store `heldDeletes` in meta → apply `baseUpdates` (one transaction).
   6. **Local phase** (phases 1–5 of the sort order): apply each action; after each successful local write, update its state row immediately.
      Local writes never depend on a later remote write, so a crash here is repaired by the next plan (rule zero sees local == remote head).
   7. **Upload phase**: upload blobs for all staged uploads (max 4 files in parallel). Blobs are immutable; uploading one that is never referenced only
      wastes space until GC.
   8. **Commit**: `JournalWriter.commit()` in batches of ≤ 1,000 entries. Only after a batch is committed are the corresponding `synced_files`/`bases`
      rows written (`afterCommitStateUpdate`). A crash between `put` and this update is repaired by reading our own journal (step 03.7) plus rule zero.
   9. Snapshot if due; device heartbeat if older than 1 hour; trim log; save `meta.lastSyncAt`; release lock; emit `SyncReport`
      `{uploaded, downloaded, merged, conflicts, deletedLocal, deletedRemote, renamed, heldDeletes, bytesUp, bytesDown, duration, errors}`.
   - If uploads are blocked by `RemoteQuotaExceededException`, steps 6 (local phase) still run; staged entries whose blobs failed are dropped (the files
     stay as local changes and are retried next cycle).
   - `cancel` is checked between actions; cancelling finishes the current action, commits what is staged, then stops.
6. **Progress**: `Stream<SyncProgress>` with `{phase (refreshing|scanning|planning|applying|uploading|committing|done), filesDone, filesTotal, bytesDone,
   bytesTotal, currentPath}` — emitted at most every 100 ms.
7. **`SyncLock`**: a file `<appSupportDir>/sync/<vaultId>.lock` opened with `RandomAccessFile.lock(FileLock.exclusive)` using a non-blocking attempt
   (`FileLock.exclusive`, catch the failure). This excludes the foreground worker and the Android background task (separate isolates/engines) from running
   at the same time. Tests use an in-memory lock implementation behind a small `SyncLock` interface.
8. `SyncEngine` constructor (all dependencies injected; nothing global):
   ```dart
   SyncEngine({required VaultFileSystem fs, required SyncProvider provider, required SyncStateStore store,
     required ObjectCipher cipher, required String remoteVaultId, required DeviceIdentity device,
     required SyncLock lock, Clock clock = const SystemClock(), Random? random,
     CrashInjector? crashInjector, EditorGuard editorGuard = const AllowAllEditorGuard(), LocalHistory? localHistory});
   Stream<SyncProgress> get progress;  Stream<SyncLogEntry> get log;
   Future<SyncReport> syncOnce({SyncTrigger trigger = SyncTrigger.manual, SyncCancelToken? cancel});
   Future<void> decideHeldDeletes(Map<VaultPath, DeleteDecision> decisions);
   Future<void> dispose();
   ```
   `SyncTrigger { manual, save, appStart, appResume, remotePoll, background, schedule, setup }`.
9. Every applied action appends a `SyncLogEntry { time, level, kind, path, otherPath, deviceName, detail }` with `kind` one of:
   `uploaded, downloaded, merged, conflictCopy, deletedLocal, deletedRemote, renamedLocal, renamedRemote, caseConflictRenamed, invalidNameRenamed,
   keptEditedFileDeletedElsewhere, restoredDeletedFileChangedElsewhere, republished, heldDeletes, deviceIdRenewed, error`.

**Tests.** `executor_test.dart`: each action type against `MemoryVaultFileSystem` + `MemorySyncProvider`; precondition mismatch skips; already-applied
target content only updates state; case-only rename on a case-insensitive memory FS; `ConflictCopy` reuses an existing identical copy after a crash;
`EditorGuard` returning false skips the overwrite; history snapshot is written before every text overwrite. `sync_engine_test.dart`: two devices
(two engines, one provider) — create/edit/delete/rename round trips; for **every** `CrashPoint`, run a cycle that crashes there, then a normal cycle on
a fresh engine instance (same FS + same store) and assert: no file content lost, both devices converge after two more rounds. Quota exceeded mid-upload →
local phase done, no partial journal, retry succeeds after quota is raised. Cancel mid-cycle → consistent state.

**Verify.** `cd packages/tephra_sync; dart test test/executor test/engine`.

**Pitfalls.** Never write the journal batch before its blobs exist. Never update `synced_files` for an upload before its journal batch is committed.
Never call `fs.delete` with `TrashMode.permanent` from sync. Never treat an empty local scan as "user deleted everything" — the scanner throws
`VaultFolderUnavailableException` when the folder is missing, and the delete guard catches the rest.

---

### 03.12 — Multi-device simulator and the fuzz test

**Purpose.** Prove the exit-gate claim "no content lost, all devices converge" with random operations, offline periods and crashes.

**Files.** `test/simulator/sim_world.dart`, `test/simulator/sim_device.dart`, `test/simulator/sim_ops.dart`, `test/simulator/invariants.dart`,
`test/simulator/fuzz_test.dart`, `test/simulator/scenarios_test.dart`.

**Implementation.**
1. `SimWorld(int seed)`: one `MemorySyncProvider` with a `FakeClock` (advances 1–5,000 ms per op), three `SimDevice`s:
   `A` (Android-like: case-sensitive), `B` (Windows-like: `MemoryVaultFileSystem(caseInsensitive: true)`, `isWindows: true`), `C` (Windows-like).
   All share one remote vault created with `EncryptingObjectCipher` and a fixed master key (skip the KDF for speed).
   Each device: its own memory FS, its own in-memory `SyncStateStore` that survives "restarts" (crash = drop the engine object, keep FS + store),
   an `OfflineSwitch` wrapper around the provider that throws `NetworkUnavailableException` while offline.
2. Operations (chosen with `Random(seed)`; weights in brackets): edit lines of an existing `.md` (insert/delete/replace 1–3 lines) [30];
   create a note `.md` with 1–40 random lines (some names differ only by case, some with characters invalid on Windows) [10];
   create a binary file (1 KiB–6 MiB of random bytes; 5% above 4 MiB to exercise chunking) [3]; overwrite a binary [3]; delete a file [6];
   rename a file within its folder [4]; move a file to another folder [3]; case-only rename [2]; rename a folder [1]; edit frontmatter keys [3];
   `syncOnce` on a random online device [25]; go offline [3]; go online [3]; `syncOnce` with the crash injector firing at a random `CrashPoint` [3];
   "same line" scenario — two devices edit the same line of the same note while one is offline [1].
   Held deletes are auto-approved by the simulator (record each occurrence).
3. **Observation for the no-loss invariant:** before every `syncOnce` on a device, record every participating file's content hash and bytes into
   `mustSurvive` (a map hash → bytes). This defines "every version that sync ever saw".
4. **End of run:** all devices online, no crash injection; run rounds (each device `syncOnce` in order A, B, C) until one full round applies zero actions on
   every device (max 10 rounds; more = failure "no convergence").
5. **Invariants** (`invariants.dart`):
   - **No loss:** every hash in `mustSurvive` is found in at least one of: any device's vault files (including conflict copies), any device's `.trash/`,
     any device's `.tephra/history/` (decompressed), or remote history (any journal entry with that hash whose blobs all exist and decrypt).
   - **Convergence:** all devices have the same participating map `path → hash`, and it equals the remote live heads `path → hash`; no path is a fork.
   - **Integrity:** no unexpected exception type escaped (`SimulatedCrash`, `NetworkUnavailableException` and `SyncLockedException` are expected).
   - **Determinism:** running the same seed twice gives identical final states.
6. `fuzz_test.dart`, tagged `@Tags(['fuzz'])`: ops count from env `TEPHRA_FUZZ_OPS` (default **3,000**), seeds from `TEPHRA_FUZZ_SEED` (default runs seeds
   1, 2, 3). On failure, print `FUZZ FAILURE seed=<seed> op=<index> <invariant message>` and the last 50 ops (conventions §8). The nightly CI run uses
   `TEPHRA_FUZZ_OPS=100000` with 3 random seeds (printed first).
7. `scenarios_test.dart` (deterministic, readable): the PHASE_PLAN demo sequences — offline edit on A + different paragraph on B → clean merge; same line →
   conflict copy on the right device with the right name; delete on A while B edits → file kept; rename on A while B edits → edit follows the file;
   Android `Note.md` + `note.md` reaching B → `note (case conflict).md` for all; 60 deletes → held, then approved; device clone → new device id, no loss.

**Tests.** As above. `dart test test/simulator` must pass with defaults in under 5 minutes on this PC; run once locally with
`$env:TEPHRA_FUZZ_OPS='100000'` and record duration and result in `PROGRESS.md`.

**Verify.**
```
cd packages/tephra_sync
dart test test/simulator
$env:TEPHRA_FUZZ_OPS='100000'; dart test test/simulator/fuzz_test.dart; Remove-Item Env:TEPHRA_FUZZ_OPS
```

**Pitfalls.** A fuzz failure is a real bug: fix the engine, add the failing seed as a fixed regression test, never loosen an invariant. If the 100k run
takes more than 60 minutes, profile (likely RemoteHistory recomputation) and make history updates incremental — do not reduce the op count.

---

### 03.13 — Human-prerequisite gate and OAuth configuration loading

**Purpose.** Stop for the human's Google set-up, then load the OAuth client IDs safely at compile time.

**Files.** `packages/tephra_sync/lib/src/auth/google_oauth_config.dart`, `app/lib/core/sync/oauth_config.dart`,
`secrets/google_oauth.example.json` (committed; placeholder values only), `README.md` (edit: "Running with Google Drive sync"), `.gitignore` (check only).

**Implementation.**
1. **Stop here** and send the human the whole "Human prerequisites" section (H1–H8). Wait until the human says the prerequisites are done.
   Record in `PROGRESS.md`: date, test-user account names (not passwords), and the H2 step 6 choice (Testing with weekly reconnect, or In production).
2. Check: `Test-Path secrets/google_oauth.json` is `True`; `git check-ignore secrets/google_oauth.json` prints the path; the JSON has the three keys and
   no value contains `REPLACE`. If any check fails, tell the human exactly what is wrong and wait.
3. `secrets/google_oauth.example.json` — same three keys with values `REPLACE_ME`. Commit it (this is the only file in `secrets/` that is committed:
   add the negation line `!secrets/google_oauth.example.json` to `.gitignore` if `secrets/` is ignored as a folder; if the pattern is `secrets/`,
   change it to `secrets/*` so the negation works). Run `git status` and make sure `google_oauth.json` is **not** listed.
4. `GoogleOAuthConfig` (pure Dart value class): `androidServerClientId`, `desktopClientId`, `desktopClientSecret`; `bool get isComplete` (all non-empty);
   constant scope list `GoogleOAuthConfig.scopes = ['https://www.googleapis.com/auth/drive.file']`.
5. `app/lib/core/sync/oauth_config.dart`: `const googleOAuthConfig = GoogleOAuthConfig(androidServerClientId: String.fromEnvironment('TEPHRA_GOOGLE_ANDROID_SERVER_CLIENT_ID'), …)`.
   If `isComplete` is false at run time, the sync setup screen shows "This build has no Google sign-in configuration" (l10n `syncErrorNoOAuthConfig`)
   instead of crashing.
6. README "Running with Google Drive sync": run commands (from `app/`):
   ```
   flutter run -d windows --dart-define-from-file=../secrets/google_oauth.json
   flutter run -d <android-device-id> --dart-define-from-file=../secrets/google_oauth.json
   ```
   Dev Launcher's web preview (`dart run tool/dev.dart`) is unchanged and does not sync (web shows "Sync is not available in the web preview").
7. If `.vscode/launch.json` exists, add the `--dart-define-from-file` argument to the Windows and Android configurations.

**Tests.** `GoogleOAuthConfig.isComplete` true/false cases.

**Verify.** `git check-ignore secrets/google_oauth.json` prints the path; `git status --porcelain` does not list it;
`flutter run -d windows --dart-define-from-file=../secrets/google_oauth.json` starts (close it after the main window shows).

**Pitfalls.** Never paste the client secret into code, tests, logs, commit messages or `PROGRESS.md`. `String.fromEnvironment` must be used in a `const`
context or it returns empty strings.

---

### 03.14 — Google authentication: Android (`google_sign_in` 7) and Windows (loopback + PKCE)

**Purpose.** Obtain and refresh access tokens for the `drive.file` scope on both platforms, store secrets securely, and turn revoked access into
`AuthRevokedException` → "Reconnect".

**Files.**
- Package (pure Dart): `lib/src/auth/access_token_source.dart`, `lib/src/auth/secret_store.dart`, `lib/src/auth/oauth_tokens.dart`,
  `lib/src/auth/desktop_oauth_flow.dart`, `lib/src/auth/desktop_token_source.dart`, `lib/src/auth/authed_client.dart`.
- App: `app/lib/core/sync/secure_secret_store.dart`, `app/lib/core/sync/google_auth_service.dart` (interface + provider),
  `app/lib/core/sync/google_auth_android.dart`, `app/lib/core/sync/google_auth_windows.dart`, `app/lib/core/sync/google_auth_unsupported.dart`.
- Tests: `test/auth/desktop_oauth_flow_test.dart`, `test/auth/desktop_token_source_test.dart`, `test/auth/authed_client_test.dart`,
  `app/test/core/sync/google_auth_service_test.dart`.

**Implementation.**
1. Package interfaces:
   ```dart
   abstract interface class AccessTokenSource {
     Future<String> accessToken({bool forceRefresh = false});   // throws AuthRevokedException / NetworkUnavailableException
     Future<void> signOut();                                     // forget tokens locally and revoke if possible
   }
   abstract interface class SecretStore {                        // implemented in the app with flutter_secure_storage
     Future<String?> read(String key); Future<void> write(String key, String value); Future<void> delete(String key);
   }
   ```
   Secret keys used in this phase (exact strings): `tephra.google.desktop.refreshToken`, `tephra.google.accessToken`,
   `tephra.google.accessTokenExpiry` (ISO UTC), `tephra.google.accountEmail`, `tephra.sync.<remoteVaultId>.masterKey` (base64 32 bytes).
2. `AuthedClient extends http.BaseClient` wraps an inner `http.Client` and an `AccessTokenSource`: adds `Authorization: Bearer <token>`; on HTTP 401,
   calls `accessToken(forceRefresh: true)` once and retries the request once (requests with a non-replayable streamed body are buffered first);
   a second 401 → `AuthRevokedException`.
3. **Windows: `DesktopOAuthFlow`** (pure Dart, `dart:io` only; browser opening is injected):
   ```dart
   DesktopOAuthFlow({required String clientId, required String clientSecret, required Future<void> Function(Uri) openBrowser,
     http.Client? httpClient, Random? random, Duration timeout = const Duration(minutes: 5)});
   Future<OAuthTokens> signIn();   // OAuthTokens { accessToken, refreshToken, expiresAt, scope, email? }
   ```
   Steps: (1) `code_verifier` = 64 random bytes → base64url without padding (86 chars); `code_challenge` = base64url-no-padding(SHA-256(ASCII verifier));
   `state` = 16 random bytes base64url. (2) `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` → random port; `redirect_uri = http://127.0.0.1:<port>`.
   (3) Open `https://accounts.google.com/o/oauth2/v2/auth?client_id=…&redirect_uri=…&response_type=code&scope=https://www.googleapis.com/auth/drive.file%20openid%20email&code_challenge=…&code_challenge_method=S256&state=…&access_type=offline&prompt=consent`
   (all values URL-encoded with `Uri(queryParameters: …)`). (4) Wait for the first request to the server: verify `state` (mismatch → respond 400 and keep
   waiting); `error` parameter → respond with a short HTML page "Sign-in cancelled. You can close this tab." and throw `AuthRevokedException('cancelled')`;
   `code` → respond with HTML "Tephra is connected. You can close this tab and return to the app." (5) Close the server. (6) POST
   `https://oauth2.googleapis.com/token` form-encoded: `code, client_id, client_secret, redirect_uri, grant_type=authorization_code, code_verifier`.
   (7) Parse `access_token, expires_in, refresh_token, scope, id_token` (take `email` from the id_token payload's middle part, base64url-decoded JSON,
   for display only; no signature check needed because it came directly from Google over TLS). Missing `refresh_token` → throw `AuthRevokedException`
   (ask the user to try again; `prompt=consent` should always return one). Timeout → `AuthRevokedException('timeout')`. Endpoints are constructor
   parameters with these defaults so tests can point them at a local fake.
4. **`DesktopTokenSource(DesktopOAuthFlow flow, SecretStore store, {Clock clock, http.Client? client})`**: caches the access token in memory and in
   `SecretStore`; refreshes when < 2 minutes remain: POST token endpoint with `grant_type=refresh_token, refresh_token, client_id, client_secret`.
   Response `400 {"error":"invalid_grant"}` → delete stored tokens, throw `AuthRevokedException` (expired 7-day testing token or revoked access).
   Network errors → `NetworkUnavailableException`. `signOut()` → POST `https://oauth2.googleapis.com/revoke?token=<refresh token>` (ignore failures),
   delete stored keys.
5. **App `SecureSecretStore`** implements `SecretStore` with `FlutterSecureStorage()` default options (Android: Keystore-backed; Windows: the
   plugin's protected storage). Re-read the plugin README for the current options before coding.
6. **Android (`GoogleAuthAndroid`)** — `google_sign_in` 7.x (re-read the README and the example of the exact installed version before coding; the API
   below is the 7.x shape):
   ```dart
   final signIn = GoogleSignIn.instance;
   await signIn.initialize(serverClientId: googleOAuthConfig.androidServerClientId);   // once per process (also in the background isolate)
   // Interactive sign-in (only from a button press in the wizard / reconnect banner):
   final GoogleSignInAccount account = await signIn.authenticate();                   // supportsAuthenticate() is true on Android
   final authz = await account.authorizationClient.authorizeScopes(GoogleOAuthConfig.scopes);   // shows the Drive consent if needed
   final String token = authz.accessToken;
   // Silent (start-up, worker, background):
   final GoogleSignInAccount? acct = await signIn.attemptLightweightAuthentication();
   final silent = await acct?.authorizationClient.authorizationForScopes(GoogleOAuthConfig.scopes);  // null → needs user interaction
   ```
   `GoogleAuthAndroid` implements `AccessTokenSource`: returns the cached token from `SecretStore` if it expires in more than 2 minutes (Android tokens live
   ~1 hour; store `expiry = now + 55 min` because the API does not return an expiry); otherwise silent authorization; null or an exception that means
   "user interaction required" → `AuthRevokedException`. `forceRefresh: true` → call `authorizationClient.clearAuthorizationToken(accessToken: old)` and
   authorize silently again. `signOut()` → `signIn.disconnect()` and delete stored keys. Store the account email for display.
7. **Windows (`GoogleAuthWindows`)** = `DesktopTokenSource` + `DesktopOAuthFlow(openBrowser: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))`.
8. `GoogleAuthService` (app interface): `Future<GoogleAccount> signInInteractive()`, `Future<GoogleAccount?> currentAccount()`, `AccessTokenSource get tokens`,
   `Future<void> signOut()`. `googleAuthServiceProvider` (in `app/lib/core/providers.dart`) picks Android / Windows / unsupported (web and others; every
   method throws `UnsupportedError`) with `Platform.isAndroid` / `Platform.isWindows` (allowed: platform-only feature, conventions §5.9), guarded by `kIsWeb`.

**Tests.** Desktop flow against a local fake token endpoint (a `dart:io` `HttpServer` in the test) and a fake `openBrowser` that performs the redirect
request itself: success; wrong `state` ignored then correct one accepted; `error=access_denied` → exception; PKCE: the token request's `code_verifier`
hashes to the `code_challenge` sent in the auth URL; timeout. Token source: refresh before expiry; `invalid_grant` → `AuthRevokedException` and stored
tokens deleted; network error mapping; sign-out revokes. `AuthedClient`: 401 → refresh → retry succeeds; 401 twice → `AuthRevokedException`.
App: the provider returns the unsupported implementation on web (override platform via an injected `TargetPlatformInfo` if the app has one, else test the
selection function directly).

**Verify.** Package and app tests pass. Manual (record in `PROGRESS.md`): on Windows, a temporary debug-only "Test Google sign-in" button in the sync
settings screen (removed again at the end of step 03.18) opens the browser, signs in with a test user and shows the account email; on the phone the same
with the Android flow. If Android sign-in fails with "canceled" immediately, check the SHA-1 (H3) and the Web client id (H4) before changing code.

**Pitfalls.** Never log tokens or the authorization code. Bind the loopback server to `127.0.0.1` only (not `0.0.0.0`). `google_sign_in` has no Windows
implementation — never call it on Windows. Calling `authorizeScopes` outside a user gesture can fail on Android; only the wizard and the reconnect banner
call it.

---

### 03.15 — Fake Drive server, `DriveSyncProvider`, retries and fault injection

**Purpose.** Implement `SyncProvider` on Google Drive v3 with `drive.file`, test it against a local fake Drive server with faults, and against a real
account in the nightly job.

**Files.**
- `lib/src/drive/drive_sync_provider.dart`, `lib/src/drive/drive_folders.dart`, `lib/src/drive/drive_retry.dart`, `lib/src/drive/drive_errors.dart`,
  `lib/src/drive/drive_vault_finder.dart`.
- `test/support/fake_drive_server.dart`, `test/drive/drive_sync_provider_test.dart`, `test/drive/drive_faults_test.dart`,
  `test/drive/drive_live_test.dart` (tagged `live`), `tool/google_refresh_token.dart`.

**Implementation.**
1. Use `import 'package:googleapis/drive/v3.dart' as drive;` and `drive.DriveApi(authedClient, rootUrl: rootUrl)` (`rootUrl` default
   `https://www.googleapis.com/`; tests pass the fake server URL). Re-check the `googleapis` 17.x API docs for `files.create/update/get/list/delete`,
   `changes.getStartPageToken/list`, `about.get`, `drive.Media`, `drive.DownloadOptions.fullMedia`, `drive.UploadOptions` / `drive.ResumableUploadOptions`.
   Always request explicit `$fields` (e.g. `files(id,name,parents,size,createdTime,modifiedTime,appProperties,trashed),nextPageToken`).
2. **Folder layout on Drive** (all created by the app, so `drive.file` can see them):
   `My Drive/Tephra/` (`appProperties: {tephraKind: 'root'}`) → `<vault name>/` (`appProperties: {tephraKind: 'vault', tephraVaultId: '<id>'}`) →
   sub-folders `blobs`, `journals`, `snapshots`, `backups`, `devices`, `locks` (created by the vault creator), `journals/<deviceId>` and
   `snapshots/<deviceId>` (created only by that device), `backups/<stamp>` (created by the backing-up device). Folder MIME type
   `application/vnd.google-apps.folder`. Object files: name = last key segment (e.g. `0000000041.json.enc`), MIME type `application/octet-stream`
   (`vault.json`: `application/json`), `appProperties: {tephraKey: '<full key>'}` when the key is ≤ 100 characters.
   Vault folder name = the vault name with `/ \ : * ? " < > |` replaced by `_`.
3. **Key → file mapping.** `DriveFolders` resolves a key's parent folder path segment by segment, caching folder ids in memory and file ids in
   `remote_file_ids` (store from step 03.3). Lookup by name inside a folder: `q = "'<folderId>' in parents and name = '<name>' and trashed = false"`
   (escape `'` and `\` in names). If a lookup returns **several** files with the same name (two devices uploaded the same blob concurrently, or duplicate
   folders were created): for blobs use any (identical content), for folders use the oldest `createdTime` for writes but list the union of all duplicates
   for reads, for other files use the newest `modifiedTime`. A cached id that returns 404 is removed from the cache and looked up again once.
4. **Operations.**
   - `connect()`: get a token (`accessToken()`), `about.get($fields: 'user(emailAddress),storageQuota')`, find the vault folder by
     `appProperties has { key='tephraVaultId' and value='<id>' } and trashed = false` (`RemoteVaultMissingException` if absent, except during creation).
   - `put`: bytes ≤ 5 MiB → `files.create` / `files.update` with `uploadMedia: drive.Media(Stream.value(bytes), bytes.length)` (multipart);
     bytes > 5 MiB → `uploadOptions: drive.ResumableUploadOptions(chunkSize: 4 * 1024 * 1024)`. Existing file id → `update` (replace content), else `create`.
     Blob keys: if the file already exists, return without uploading (immutable). Note: blobs are ≤ 4 MiB + 50 bytes by construction (step 03.5), so
     resumable uploads are only used for large snapshots and backup manifests; interrupted transfers therefore resume at blob granularity (already uploaded
     blobs are skipped via `blob_index`/listing) and a large metadata object is simply re-sent.
   - `get`: `files.get(id, downloadOptions: drive.DownloadOptions.fullMedia)` → read the `drive.Media` stream fully.
   - `delete`: **move to Drive trash** with `files.update(drive.File()..trashed = true, id)` (the user can still recover it from Drive's trash for 30 days),
     never `files.delete`. Missing → no-op.
   - `list(prefix)`: resolve the deepest existing folder of the prefix, list recursively with pagination (`pageSize: 1000`, follow `nextPageToken`), build
     keys from folder paths + names, filter by the string prefix, sort, de-duplicate.
   - `changesSince(null)`: `changes.getStartPageToken()` → cursor. `changesSince(token)`: `changes.list(pageToken: token, pageSize: 1000,
     includeRemoved: true, spaces: 'drive', $fields: 'nextPageToken,newStartPageToken,changes(fileId,removed,file(id,name,parents,trashed,appProperties))')`;
     follow `nextPageToken` until `newStartPageToken` appears; map file ids to keys via the caches (`appProperties.tephraKey` first, else parent folder
     path + name); ignore files outside this vault folder; trashed/removed → `removedKeys`. HTTP 400/404 for the token → `cursorWasReset: true` with a fresh token.
   - `quota()`: `about.get($fields: 'storageQuota')` → `Quota(usedBytes: usage, limitBytes: limit)` (`limit` absent = unlimited).
5. **Retries (`DriveRetry`)**: retry on 429, 403 with reason `userRateLimitExceeded` or `rateLimitExceeded`, 500, 502, 503, 504, `SocketException`,
   `TimeoutException`, `http.ClientException`. Delay = random in `[0, min(64 s, 1 s × 2^attempt)]` (full jitter), honour `Retry-After` when present,
   **max 6 retries**. Request timeout 60 s (per call). After the last retry: rate limit → `RateLimitedException`, 5xx → `RemoteServerException`,
   network → `NetworkUnavailableException`. Never retry 400, 401 (handled by `AuthedClient`), 403 `storageQuotaExceeded`
   (→ `RemoteQuotaExceededException`), 403 `insufficientPermissions`/`forbidden` (→ `AuthRevokedException`, the user must reconnect), 404
   (→ `RemoteNotFoundException`). Parse the reason from `drive.DetailedApiRequestError.errors[].reason`.
6. **Drive full**: before an upload phase, if `quota().freeBytes` is not null and `< 50 MiB + bytes to upload` → `RemoteQuotaExceededException` without
   uploading; the engine re-checks at most every 10 minutes; usage above 90% → log + UI warning `syncWarningDriveAlmostFull`.
7. **`DriveVaultFinder`**: `listRemoteVaults()` → for each folder with `tephraKind = 'vault'`: read its `vault.json` (skip folders without one) → list of
   `RemoteVaultInfo { vaultId, vaultName, createdAt, createdByDeviceName, encrypted }`. `createVaultFolders(vaultName, vaultId)` creates `Tephra/`
   (reusing the oldest existing app-created `Tephra` root) and the vault folder with its six sub-folders.
8. **Fake Drive server** (`test/support/fake_drive_server.dart`, `dart:io` `HttpServer` on `127.0.0.1:0`) implementing exactly the endpoints the
   provider uses: `GET /drive/v3/files` (supporting the `q` forms used above joined with `and`: `'<id>' in parents`, `name = '…'`,
   `trashed = false`, `mimeType = '…'`, `appProperties has { key='…' and value='…' }`; `pageSize`, `pageToken`), `POST /drive/v3/files` (folder
   create, metadata only), `POST /upload/drive/v3/files?uploadType=multipart` (parse `multipart/related`), `uploadType=resumable` (initial POST returns a
   `Location` session URL; `PUT` chunks with `Content-Range`; final chunk returns the file), `PATCH /drive/v3/files/<id>` (metadata, `trashed`),
   `PATCH /upload/drive/v3/files/<id>?uploadType=multipart|resumable` (content replace), `GET /drive/v3/files/<id>?alt=media`,
   `GET /drive/v3/changes/startPageToken`, `GET /drive/v3/changes`, `GET /drive/v3/about`. Responses use Drive's JSON field names.
   Fault injection: `FakeDriveFaults { int failNextRequests; int statusCode; String? reason; Duration? delay; bool dropConnectionMidUpload;
   int? quotaLimitBytes; bool revokeToken /* 401 for every request */; }` plus a request log for assertions. Check the expected bearer token.
9. `tool/google_refresh_token.dart`: reads `secrets/google_oauth.json`, runs `DesktopOAuthFlow` (opening the browser with `Process.run('cmd', ['/c', 'start', '', url])`
   on Windows), and prints the refresh token with the warning "Store this as the GitHub secret TEPHRA_DRIVE_TEST_REFRESH_TOKEN. Do not share it." This is the
   only place a token may be printed.

**Tests.**
- `drive_sync_provider_test.dart`: `runSyncProviderContract('DriveSyncProvider (fake server)', …)`; folder creation layout; key ↔ file mapping through
  the cache and after cache loss; duplicate same-name files handled per item 3; `delete` sets `trashed` (not a DELETE request); pagination across 2,500 files;
  changes mapping (put, replace, trash) and token reset; `listRemoteVaults`.
- `drive_faults_test.dart`: 429 ×3 then success; 403 `userRateLimitExceeded` ×7 → `RateLimitedException` after exactly 6 retries (count requests); 500 →
  retry; timeout (delay > timeout) → retry then `NetworkUnavailableException`; connection dropped mid resumable upload → the next `put` succeeds and the
  stored object is complete; 403 `storageQuotaExceeded` → `RemoteQuotaExceededException`, no retry; revoked token → `AuthRevokedException`; a full
  `SyncEngine` two-device sync over the fake server with random faults injected into 10% of requests (seeded) converges with no loss.
- `drive_live_test.dart` (`@Tags(['live'])`, skipped unless env `TEPHRA_DRIVE_TEST_REFRESH_TOKEN`, `TEPHRA_GOOGLE_DESKTOP_CLIENT_ID` and
  `TEPHRA_GOOGLE_DESKTOP_CLIENT_SECRET` are set): builds a `DesktopTokenSource` from the refresh token, creates a vault folder named
  `ci-<yyyyMMddHHmmss>-<random>`, runs the contract suite, then trashes the folder.
- Exclude tags by default: create/extend `packages/tephra_sync/dart_test.yaml` with `tags: {live: {skip: "needs Google credentials"}, fuzz: {}}`
  and run live tests with `dart test --run-skipped -t live`.

**Verify.** `cd packages/tephra_sync; dart test test/drive`. Then ask the human to run `dart run tool/google_refresh_token.dart` (H6) and store the
secrets; run `dart test --run-skipped -t live test/drive/drive_live_test.dart` locally with the env vars set in your shell (from the human) and record the result.

**Pitfalls.** With `drive.file`, files the user created manually in Drive are invisible to the app — that is expected. Do not use `spaces: 'appDataFolder'`
(the folder must be visible). Do not use `files.delete` anywhere. The changes feed is eventually consistent: never treat "not in changes" as "absent".

---

### 03.16 — Sync runtime: worker isolate, triggers, polling, editor guard, offline queue, bandwidth

**Purpose.** Run the engine continuously in the app without touching the UI isolate's frame budget.

**Files.** `app/lib/core/sync/sync_worker.dart` (isolate entry), `app/lib/core/sync/sync_worker_client.dart`, `app/lib/core/sync/sync_messages.dart`,
`app/lib/core/sync/sync_triggers.dart`, `app/lib/core/sync/editor_guard_host.dart`, `app/lib/core/sync/sync_paths.dart`,
`packages/tephra_sync/lib/src/provider/throttled_sync_provider.dart`, `packages/tephra_sync/lib/src/engine/backoff_schedule.dart`;
tests `app/test/core/sync/sync_worker_client_test.dart`, `app/test/core/sync/sync_triggers_test.dart`, `packages/tephra_sync/test/provider/throttled_sync_provider_test.dart`,
`packages/tephra_sync/test/engine/backoff_schedule_test.dart`.

**Implementation.**
1. **One worker per open, sync-enabled vault**, started with `Isolate.spawn(syncWorkerMain, SyncWorkerArgs(...))` from the main isolate (same isolate group, so
   immutable message objects can be sent directly). Args: `RootIsolateToken.instance!`, vault root path, sync DB path, remote vault id, device identity,
   provider id, `SendPort` for replies. In the worker: `BackgroundIsolateBinaryMessenger.ensureInitialized(token)`, then (Android only) try
   `FlutterCryptography.enable()`; if it throws, keep the Dart implementation and log `info` (both produce identical bytes). Create `IoVaultFileSystem`,
   `SyncStateStore`, cipher (master key read from `SecureSecretStore` inside the worker), provider, `SyncEngine`.
2. **Tokens in the worker**: the worker's `AccessTokenSource` sends `TokenRequest(forceRefresh)` to the main isolate and awaits `TokenReply(token | error type)`,
   because `google_sign_in` and the interactive Windows flow live in the main isolate. Cache the token in the worker until 2 minutes before expiry.
3. **Messages** (sealed classes in `sync_messages.dart`, each request has an `int requestId`; replies carry the same id):
   main → worker: `SyncNow(trigger)`, `NotifyLocalChange(paths)`, `SetPaused(bool)`, `UpdateSettings(settings)`, `DecideHeldDeletes(map)`, `QueryLog(limit)`,
   `QueryConflicts()`, `ResolveConflict(id, ConflictResolution, String? mergedText)`, `QueryDevices()`, `RevokeDevice(deviceId)`, `QueryHistory(path)`,
   `LoadVersion(versionRef)`, `RestoreVersion(versionRef, path)`, `QueryDeleted()`, `ListBackups()`, `BackupNow()`, `RestoreBackup(request)`,
   `RunVerification()`, `TokenReply`, `EditorGuardReply`, `Shutdown()`.
   worker → main: `StatusUpdate(SyncStatusSnapshot)`, `ProgressUpdate(SyncProgress)`, `LogAppended(SyncLogEntry)`, `TokenRequest`, `EditorGuardRequest(path, expectedHash)`,
   `Reply(requestId, payload | errorType)`.
4. `SyncStatusSnapshot { SyncUiState state; int pendingLocalChanges; int unresolvedConflicts; List<VaultPath> heldDeletes; DateTime? lastSyncAt;
   String? errorKind; Quota? quota; String? accountEmail; }` with `enum SyncUiState { notConfigured, idle, syncing, pending, offline, paused, needsAttention, error }`.
   Mapping: `AuthRevokedException`, held deletes, unresolved conflicts, `DeviceRevokedException` → `needsAttention`; network/rate-limit/server → `offline`;
   quota, format, tamper, vault missing → `error`.
5. **Triggers** (`SyncTriggers`, main isolate):
   - **Save**: the editor's save hook and the vault watcher (external edits) call `notifyLocalChange(path)`; debounce **5 s** after the last change, then `SyncNow(save)`.
   - **App start** (after the vault opens) and **resume** (`AppLifecycleState.resumed`) → `SyncNow(appStart|appResume)`.
   - **Remote poll**: every **30 s** while the app is in the foreground (`resumed`), the worker calls `changesSince`; if any changed key is under `journals/`
     (of another device), `devices/` or `vault.json`, it runs a cycle (`remotePoll`). Polling stops when the app is paused/hidden (Android) and continues on
     Windows while the window is hidden only if "keep syncing when closed" is on.
   - **Schedule**: the worker checks every 5 minutes whether a backup (step 03.22) or verification/GC (step 03.23) is due.
   - **Manual**: command `sync.sync-now`.
   - Triggers arriving during a cycle set a "run again" flag (one extra cycle after the current one), never queue many cycles.
6. **Offline / errors** (`BackoffSchedule`): after a cycle fails with offline-type errors, retry after 30 s, 1 min, 2 min, 5 min, then every 5 min; a
   manual trigger or app resume retries immediately. Pending local changes are not lost while offline: they are simply the difference between disk and
   base, so the next successful cycle uploads them (the "offline queue" is the state DB itself plus `pending_ops`).
7. **Editor guard host**: the main isolate answers `EditorGuardRequest(path, expectedHash)` by asking the editor/tabs layer (find how open documents are
   tracked in `app/lib/editor/`): if the note is open with unsaved changes → save it now, reply `false`; otherwise hash the file on disk (in `Isolate.run`)
   and reply `hash == expectedHash`. Timeout 5 s → `false`.
8. **Bandwidth limit**: `ThrottledSyncProvider(SyncProvider inner, {int upKiBps, int downKiBps, Clock clock})` — token bucket per direction (capacity =
   1 second of budget, minimum 16 KiB/s when non-zero); `0` = unlimited. The engine is built with this wrapper around the Drive provider.
9. **Pause**: `sync.pause` / `sync.resume` commands set `meta.pausedByUser`; while paused no cycles run (status `paused`), local changes accumulate safely.
10. Riverpod: `syncWorkerClientProvider` (Provider, per open vault via `.family` on the vault id), `syncStatusProvider` (StreamProvider.family),
    `syncProgressProvider`, `syncLogProvider`. Disposing the vault session sends `Shutdown` and closes the ports (cancel every subscription, conventions §5.6).
11. Web: `kIsWeb` → no worker; status `notConfigured` with the message `syncNotAvailableOnWeb`.

**Tests.** Worker client with a fake worker (in-process `ReceivePort` loop): request/reply matching, token request round trip, shutdown closes ports;
triggers with a fake clock: 5 s debounce, polling every 30 s only while resumed, "run again" coalescing; throttled provider timing with a fake clock;
backoff sequence.

**Verify.** App and package tests. Manual: run on Windows with a configured vault (after step 03.18 exists you can use the wizard; until then use a
debug-only command `sync.debug-connect-memory` that connects the vault to a `MemorySyncProvider` and remove it again at the end of step 03.18) and check in
the log that a save triggers a cycle about 5 s later and the UI stays smooth (no jank in the Flutter performance overlay while syncing 500 files).

**Pitfalls.** Never run `SyncEngine` on the UI isolate. Plugins (secure storage) in a background isolate need `BackgroundIsolateBinaryMessenger.ensureInitialized`.
The vault watcher in the main isolate will see the worker's writes as external changes — that is intended (the index and open editors reload).

---

### 03.17 — Android background sync (WorkManager) and Windows tray / keep-running

**Purpose.** Sync while the app is closed on Android, and while the window is closed on Windows (optional).

**Files.** `app/lib/core/sync/background_sync.dart`, `app/lib/core/sync/headless_sync_runner.dart`,
`app/lib/core/platform/tray_service.dart` (extend if needed), `app/lib/core/platform/windows_tray_service.dart` (if not present),
`app/lib/core/platform/window_service.dart` (extend if needed), `app/android/app/src/main/AndroidManifest.xml` (check only);
tests `app/test/core/sync/headless_sync_runner_test.dart`, `app/test/core/platform/tray_service_test.dart`.

**Implementation — Android.**
1. Add `workmanager` (re-read its README for the Android set-up of the installed version; recent versions need no manual `Application` class).
2. `background_sync.dart`:
   ```dart
   @pragma('vm:entry-point')
   void tephraBackgroundDispatcher() {
     Workmanager().executeTask((String task, Map<String, dynamic>? input) async {
       WidgetsFlutterBinding.ensureInitialized();          // plugins are available in this background engine
       return HeadlessSyncRunner().runAll(budget: const Duration(minutes: 8));   // true = success / nothing to do
     });
   }
   ```
   In `main.dart` (Android only, after logging is set up): `Workmanager().initialize(tephraBackgroundDispatcher)`.
3. Registration (`BackgroundSyncScheduler.apply(settings)`), called after setup and whenever the related settings change:
   if any vault has `mode != off` and `backgroundSync == true` →
   `Workmanager().registerPeriodicTask('tephra-sync-periodic', 'tephraSync', frequency: const Duration(minutes: 15),
   constraints: Constraints(networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected, requiresCharging: chargingOnly,
   requiresBatteryNotLow: true), existingWorkPolicy: ExistingPeriodicWorkPolicy.update, backoffPolicy: BackoffPolicy.exponential,
   backoffPolicyDelay: const Duration(minutes: 5))`; otherwise `Workmanager().cancelByUniqueName('tephra-sync-periodic')`.
   Check the exact enum value names (`NetworkType.unmetered`/`connected`, `ExistingPeriodicWorkPolicy.update`) in the installed version's API docs.
   WorkManager runs at most every 15 minutes and respects Doze and battery saver; that is accepted.
4. `HeadlessSyncRunner.runAll`: set up `package:logging` to the rotating log file (as `main.dart` does, without stdout); read the app settings to find
   `<appSupportDir>/sync/*.sqlite`; for each DB with `mode != off` and `backgroundSync == true`: build `IoVaultFileSystem(meta.vaultRootPath)`; build
   the token source **without UI**: Android `GoogleAuthAndroid` in silent-only mode (`initialize`, cached token, `attemptLightweightAuthentication`,
   `authorizationForScopes`; never `authenticate`/`authorizeScopes`); read the master key from secure storage (missing → skip vault, log
   `KeyNotAvailableException`); run `SyncEngine.syncOnce(trigger: background)` with a cancel token fired at the budget; `SyncLockedException` → skip
   (the foreground worker is syncing); `AuthRevokedException` → store status `needsAttention` in meta (the UI shows "Reconnect" on next open) and post a
   notification through `NotificationService` only once per 24 h ("Tephra sync needs you to reconnect Google Drive"). Also run due backups (step 03.22).
   Return `true` unless an unexpected exception occurred.
5. Battery rules: no polling loop in the background; one cycle per task run; if `changesSince` reports no changes for this vault **and** the local scan's
   `(size, mtime)` cache shows no changes, the cycle ends after the scan (no uploads, no downloads).
6. Manifest: confirm `android.permission.INTERNET` is present (it is required by sync; add it if Phase 0 did not). Do not add foreground services.

**Implementation — Windows.**
7. `TrayService` (conventions §5.9). If it already has a Windows implementation, add only what is missing; otherwise implement it with `tray_manager`
   0.8.x (new API: keep a reference to the `TrayIcon`; re-read the README). Methods used by sync:
   `Future<void> show({required String tooltip})`, `Future<void> setTooltip(String text)`, `Future<void> setMenu(List<TrayMenuEntry> entries)`,
   `Stream<String> get menuClicks` (entry ids), `Stream<void> get iconClicks`, `Future<void> hide()`. No-op implementation for other platforms.
   Icon: the existing `windows/runner/resources/app_icon.ico` (copy to `app/assets/tray/tray.ico` and declare the asset). Status is shown in the tooltip:
   `Tephra — Up to date`, `Tephra — Syncing 12 files…`, `Tephra — Offline`, `Tephra — Needs attention` (all from l10n).
   Menu: `Open Tephra` (`tray.open`), `Sync now` (`tray.sync-now`), `Pause sync` / `Resume sync` (`tray.pause-toggle`), `Quit Tephra` (`tray.quit`).
8. **Keep syncing when closed** (setting `keepSyncingWhenClosed`, default **off**): when on, `WindowService` prevents the close (window_manager
   `setPreventClose(true)` + `onWindowClose` → `hide()`), the tray icon stays, and the worker keeps polling. `Open Tephra` / icon click shows the window.
   `Quit Tephra` performs a real exit: send `Shutdown` to workers, wait up to 10 s for a running cycle to reach a safe point (cancel token), then exit.
   When the setting is off, closing the window also cancels and shuts down the worker cleanly before exit.
9. There is no Windows background sync when the process is not running (no Windows service in v1).

**Tests.** Headless runner with fakes: skips vaults with `backgroundSync=false`, missing key, locked vault; `AuthRevokedException` → meta status +
one notification per 24 h (fake clock); budget cancellation. Tray service: menu click ids map to commands; tooltip text per status (with a fake tray backend).

**Verify.**
- Android (real phone): enable background sync, close the app (swipe away), edit a note on the PC, wait; force a run with
  `adb shell cmd jobscheduler run -f com.tephra.app <jobId>` (find the job id with `adb shell dumpsys jobscheduler | Select-String tephra`), then open the vault
  folder with a file manager or `adb shell cat` and confirm the change arrived. Record in `PROGRESS.md`.
- Windows: turn on "keep syncing when closed", close the window, edit on the phone, confirm the file changes on disk within ~60 s and the tray tooltip updates.

**Pitfalls.** The dispatcher must be a top-level function with `@pragma('vm:entry-point')`. Never call interactive Google APIs from the background.
Two engines on one vault are prevented only by `SyncLock` — never remove it.

---

### 03.18 — Sync UI 1: the setup wizard

**Purpose.** Connect a vault to Google Drive safely: sign in → create or connect → password / recovery key → first sync with progress.

**Files.** `app/lib/sync_ui/providers.dart`, `app/lib/sync_ui/setup/sync_setup_controller.dart` (Notifier), `app/lib/sync_ui/setup/sync_setup_wizard.dart`,
`app/lib/sync_ui/setup/pages/` (`sign_in_page.dart`, `choose_vault_page.dart`, `create_password_page.dart`, `recovery_key_page.dart`,
`confirm_recovery_page.dart`, `unlock_page.dart`, `first_sync_choice_page.dart`, `first_sync_progress_page.dart`, `done_page.dart`),
`app/lib/sync_ui/setup/sync_setup_service.dart`; `app/lib/l10n/app_en.arb` (keys); tests `app/test/sync_ui/setup/*_test.dart`.

**Implementation.**
1. Entry points: Settings → "Sync & backup" → **Set up sync** button (if the vault has no sync DB or `mode == off`), and the command `sync.open-settings`.
   Layout: full-screen route on phone; a centred 560-dp-wide dialog on desktop (≥ 840 dp). Every page has Back (except progress) and Cancel; cancelling
   before the first sync leaves no remote or local changes except an empty created vault folder (which is listed but harmless).
2. Pages and rules (state machine in `SyncSetupController`; network and crypto work in `SyncSetupService`, Argon2id via `Isolate.run`, never awaited synchronously on the UI isolate):
   1. **Sign in** — text: what will be stored where ("Tephra stores your vault in a folder named Tephra in your Google Drive. With encryption on, Google
      cannot read your notes or file names."). Button "Sign in with Google" → `googleAuthService.signInInteractive()`. Shows the signed-in email and a
      "Use another account" link (signs out, signs in again).
   2. **Choose** — list from `DriveVaultFinder.listRemoteVaults()` (name, created date, created-by device, lock icon if encrypted) + a "Create a new remote
      vault" card (default name = local vault folder name). Loading and error states (offline → retry button).
   3a. **Create → password**: toggle "Encrypt (recommended)" default **on**. With encryption: password + confirm, minimum **10** characters, must match;
      warning text: "If you lose both your password and your recovery key, nobody — including Tephra — can recover your synced data. Your notes on this
      device are not affected." Turning encryption off shows a confirmation dialog explaining that notes will be readable in Google Drive.
      Device name field (prefilled from settings). Button "Create" → `RemoteVaultManager.create` (spinner with "Securing your vault… this can take a few
      seconds") → store master key in secure storage (`tephra.sync.<remoteVaultId>.masterKey`).
   3b. **Create → recovery key** (encryption only): show the key in a monospace, selectable, large box; buttons "Copy" and "Save as text file"
      (`file_picker` save dialog; file content: vault name, date, key, one sentence of instructions). Checkbox "I have saved my recovery key somewhere
      safe". Next is disabled until checked.
   3c. **Confirm recovery key**: ask the user to type groups **2** and **7** of the key (two 4-character fields, case-insensitive). Wrong → error text,
      stays. "Show the key again" goes back to 3b. Only then continue.
   4. **Connect → unlock** (existing encrypted vault): password field; "Use recovery key instead" link switches to a recovery key field.
      Wrong password → `syncErrorWrongPassword` (stay on page, no lock-out). Device name field. Success → store master key.
   5. **First sync choice**: if the remote vault is new → only "Upload this vault" (shows local file count and size). If connecting to an existing vault:
      if the local vault has no participating files → "Download the vault" only; else two radio options: **"Merge both (recommended)"** — explained as
      "Files that exist on both sides with different content are kept twice; nothing is overwritten or deleted" — and **"Download into a new empty folder"**
      (folder picker; creates a new local vault there and switches to it). There is deliberately no option that replaces or deletes local files.
      Also on this page: background sync switch (Android, default on), Wi-Fi only (Android, default **on**), mobile mode (Android, default on).
   6. **Progress**: `SyncProgress` → "Uploading 1,234 of 5,678 files · 120 MB of 900 MB" + current file name + linear progress; "Run in background"
      button closes the wizard (sync continues; the status indicator shows progress); errors show the mapped message + Retry.
   7. **Done**: summary (`SyncReport` counts), "Turn on daily backups" switch (default on → `backupSchedule = daily`), Close.
3. The wizard writes the sync DB `meta` values (step 03.3 list), registers the device (`DeviceRegistry.register`), starts the worker and applies the
   background scheduler (step 03.17). The first cycle uses `SyncTrigger.setup`; the large-delete guard never triggers on a first sync because there is no base.
4. **Reconnect** (after `AuthRevokedException`): a banner in the sync panel and the settings screen "Google Drive access expired. Reconnect" → runs
   page 1 only, then resumes sync. Does not ask for the vault password (the master key is still stored).
5. **Disconnect** (settings): "Stop syncing this vault on this device" → confirmation → stop worker, set `mode = off`, cancel background task,
   delete the master key from secure storage; keeps local files and the Drive data untouched; "Also sign out of Google" checkbox.
6. Remove the debug-only buttons/commands added in steps 03.14 and 03.16.
7. l10n keys (add all to `app_en.arb` with `@` descriptions where ambiguous): `syncSetupTitle`, `syncSetupSignInExplain`, `syncSetupSignInButton`,
   `syncSetupSignedInAs`, `syncSetupUseAnotherAccount`, `syncSetupChooseTitle`, `syncSetupCreateNew`, `syncSetupRemoteVaultCreated`,
   `syncSetupEncryptToggle`, `syncSetupPassword`, `syncSetupPasswordConfirm`, `syncSetupPasswordTooShort`, `syncSetupPasswordMismatch`,
   `syncSetupPasswordWarning`, `syncSetupEncryptionOffConfirm`, `syncSetupDeviceName`, `syncSetupCreating`, `syncSetupRecoveryTitle`,
   `syncSetupRecoveryExplain`, `syncSetupCopy`, `syncSetupSaveToFile`, `syncSetupRecoverySavedCheckbox`, `syncSetupConfirmRecoveryTitle`,
   `syncSetupConfirmRecoveryGroup` (placeholder `{number}`), `syncSetupConfirmRecoveryWrong`, `syncSetupShowKeyAgain`, `syncSetupUnlockTitle`,
   `syncSetupUseRecoveryKey`, `syncErrorWrongPassword`, `syncErrorWrongRecoveryKey`, `syncSetupFirstSyncTitle`, `syncSetupUploadOption`,
   `syncSetupDownloadOption`, `syncSetupMergeOption`, `syncSetupMergeExplain`, `syncSetupNewFolderOption`, `syncSetupBackgroundSync`,
   `syncSetupWifiOnly`, `syncSetupMobileMode`, `syncSetupProgress` (placeholders `{done}`, `{total}`, `{bytesDone}`, `{bytesTotal}`),
   `syncSetupRunInBackground`, `syncSetupDoneTitle`, `syncSetupEnableDailyBackup`, `syncReconnectBanner`, `syncReconnectButton`,
   `syncDisconnect`, `syncDisconnectConfirm`, `syncDisconnectAlsoSignOut`, `syncErrorNoOAuthConfig`, `syncNotAvailableOnWeb`.

**Tests.** Widget tests with a fake `SyncSetupService` and fake auth: full create path (password rules, recovery checkbox gate, wrong group entry blocks,
correct entry continues); connect path with wrong then right password; recovery-key path; first-sync options shown per case (new remote / empty local /
non-empty local); no destructive option exists; progress page renders counts; reconnect flow; both phone (400 dp) and desktop (1200 dp) widths.

**Verify.** Tests pass. Manual on Windows with a real test account: create an encrypted remote vault from a 50-note copy of a test vault; open
https://drive.google.com and see `Tephra/<vault name>/` with sub-folders and hash-named files. Record in `PROGRESS.md`.

**Pitfalls.** Never keep the password in a provider's state after use (clear the controller field). The recovery key is shown only on pages 3b/3c and is
never stored anywhere by Tephra.

---

### 03.19 — Sync UI 2: status indicator, sync panel, sync log, settings, devices

**Purpose.** Always show what sync is doing, explain every change in plain words, and let the user tune sync per device.

**Files.** `app/lib/sync_ui/status/sync_status_indicator.dart`, `app/lib/sync_ui/status/sync_panel.dart`, `app/lib/sync_ui/log/sync_log_screen.dart`,
`app/lib/sync_ui/log/sync_log_text.dart`, `app/lib/sync_ui/settings/sync_settings_screen.dart`, `app/lib/sync_ui/devices/devices_screen.dart`,
`app/lib/sync_ui/held_deletes/held_deletes_sheet.dart`, `app/lib/sync_ui/sync_commands.dart`; tests mirror these files.

**Implementation.**
1. **Status indicator** (`SyncStatusIndicator`, `ConsumerWidget`): desktop status bar (right side) and phone app bar (action icon). Icon + (desktop) short text:

   | `SyncUiState` | Icon | Text key |
   |---|---|---|
   | notConfigured | `Icons.cloud_outlined` (grey) | `syncStatusNotConfigured` |
   | idle | `Icons.cloud_done_outlined` | `syncStatusUpToDate` |
   | syncing | `Icons.sync` (rotating, 1 turn/s; static when "reduce motion" is on) | `syncStatusSyncing` (`{done}/{total}`) |
   | pending | `Icons.cloud_upload_outlined` | `syncStatusPending` (`{count}`) |
   | offline | `Icons.cloud_off_outlined` | `syncStatusOffline` |
   | paused | `Icons.pause_circle_outline` | `syncStatusPaused` |
   | needsAttention | `Icons.warning_amber_rounded` (amber) | `syncStatusNeedsAttention` |
   | error | `Icons.error_outline` (error colour) | `syncStatusError` |

   Tooltip/semantics label = the long text (last sync time "Last synced 2 minutes ago"). Tap → **sync panel** (desktop: popover anchored to the indicator;
   phone: modal bottom sheet) showing: state + last sync time, account email, Drive usage bar (from `Quota`), buttons "Sync now", "Pause/Resume",
   links "Conflicts (n)", "Held deletions (n)", "Sync log", "Settings", and the reconnect banner when needed.
2. **Held deletions sheet**: list of paths (folder-grouped) with the explanation "Sync wants to delete {count} files because they were deleted on another
   device or on this device. Check before continuing." Buttons: "Delete them" (approve all) and "Keep them" (keep all), plus per-file switches. Sends
   `DecideHeldDeletes`.
3. **Sync log screen**: newest first, grouped by day; each entry rendered by `SyncLogText.describe(entry, l10n)` into one sentence, e.g.
   `uploaded` → "Uploaded **Folder/Note.md**"; `downloaded` → "Updated **Note.md** from Pixel 8"; `merged` → "Merged changes from Pixel 8 into **Note.md**";
   `conflictCopy` → "**Note.md** was changed on two devices; your version was saved as **Note (conflict …).md**"; `deletedLocal` → "Moved **Note.md** to the
   vault trash (deleted on Pixel 8)"; `deletedRemote` → "Deleted **Note.md** from sync (it stays in version history)"; `renamedLocal`/`renamedRemote` →
   "Renamed **A.md** to **B.md**"; `caseConflictRenamed`, `invalidNameRenamed`, `keptEditedFileDeletedElsewhere`, `restoredDeletedFileChangedElsewhere`,
   `republished`, `heldDeletes`, `deviceIdRenewed`, `error` (mapped message). Tapping an entry with a path opens the note (or its history if deleted).
   Filter chips: All / Changes / Problems. "Copy log" button (plain text, paths included, no contents).
4. **Sync settings screen** (Settings → Sync & backup): account + vault info (remote vault name, device name editable, encryption on/off read-only);
   switches/fields stored in `meta` through `UpdateSettings`: excluded folders (folder picker list with remove buttons), excluded file types (chips input,
   lower-case without dot), maximum file size (dropdown 10 MB / 50 MB / 100 MB / 500 MB / no limit = 2 GB), mobile mode (Android), background sync (Android),
   Wi-Fi only (Android), charging only (Android), keep syncing when the window is closed (Windows), upload limit and download limit (KiB/s, 0 = unlimited),
   "Change vault password" (current password or recovery key + new password twice → `changePassword`), "Show new recovery key" (regenerate; same 3b/3c pages),
   backups section (step 03.22), "Devices" link, "Disconnect" (step 03.18). Changing exclusions shows: "Excluded files stay on this device and in Google Drive;
   they are just not synced on this device."
5. **Devices screen**: from `DeviceRegistry.listDevices()` + `journal_cursors` (`last_seen_at` = time of that device's newest entry or heartbeat): name,
   platform icon, "This device" label, last seen ("3 hours ago"), "Removed" badge. Action "Remove device" (not on this device) → confirmation dialog:
   "{name} will stop syncing. Changes it makes after now are ignored. It keeps its local files. Its access to Google Drive is not revoked — to fully block it,
   change the vault password and remove the Google account's access to Tephra on that device." → `RevokeDevice(deviceId)` writes the revocation with
   `lastAcceptedSeq` = our cursor for that device. (Master-key rotation is a later feature; note this in the dialog text above.)
   A revoked device, on its next cycle, throws `DeviceRevokedException` → its UI shows "This device was removed from sync" with "Reconnect as a new device"
   (generates a new device id, clears bases, runs a "merge both" first sync — no loss).
6. **Commands** (`sync_commands.dart`, registered in the command registry, conventions §7.8): `sync.sync-now` (no default shortcut;
   users can assign one in hotkey settings), `sync.pause`, `sync.resume`, `sync.open-log`, `sync.open-conflicts`, `sync.open-devices`,
   `sync.open-settings`, `sync.open-history` (current note), `sync.open-deleted`, `sync.backup-now`, `sync.open-backups`. `isAvailable` hides them when
   sync is not configured (except `sync.open-settings`). `sync.sync-now` has `showInMobileToolbar: false`.
7. l10n keys: the `syncStatus*` keys above, `syncPanelLastSynced` (`{when}`), `syncPanelDriveUsage` (`{used}`, `{total}`), `syncPanelSyncNow`, `syncPanelPause`,
   `syncPanelResume`, `syncPanelConflicts` (`{count}`), `syncPanelHeldDeletes` (`{count}`), `syncPanelLog`, `syncPanelSettings`, `syncHeldDeletesExplain`
   (`{count}`), `syncHeldDeletesDelete`, `syncHeldDeletesKeep`, one key per log kind `syncLog<Kind>` (e.g. `syncLogUploaded` with `{path}`), `syncLogFilterAll`,
   `syncLogFilterChanges`, `syncLogFilterProblems`, `syncLogCopy`, `syncSettings*` for each control in item 4, `syncDevicesTitle`, `syncDevicesThisDevice`,
   `syncDevicesLastSeen` (`{when}`), `syncDevicesRemoved`, `syncDevicesRemove`, `syncDevicesRemoveConfirm` (`{name}`), `syncDeviceRevokedTitle`,
   `syncDeviceRevokedReconnect`, error keys `syncErrorAuthRevoked`, `syncErrorOffline`, `syncErrorDriveFull`, `syncWarningDriveAlmostFull`,
   `syncErrorRemoteFormatNewer`, `syncErrorTampered` (`{device}`), `syncErrorVaultMissing`, `syncErrorVaultFolderUnavailable`, `syncErrorKeyMissing`,
   and command labels `commandSyncNow`, `commandSyncPause`, `commandSyncResume`, `commandSyncOpenLog`, `commandSyncOpenConflicts`, `commandSyncOpenDevices`,
   `commandSyncOpenSettings`, `commandSyncOpenHistory`, `commandSyncOpenDeleted`, `commandSyncBackupNow`, `commandSyncOpenBackups`.

**Tests.** Indicator renders each state (icon + semantics label) at 400 dp and 1200 dp; panel buttons send the right messages (fake worker client); every
log kind has a sentence (test iterates the enum); settings changes produce `UpdateSettings` with the right values; devices list + remove confirmation;
held-deletes approve/keep/per-file.

**Verify.** Tests pass. Manual on both platforms: indicator moves through syncing → up to date after an edit; airplane mode → offline; log entries readable.

**Pitfalls.** Never block the panel on network calls; everything comes from the worker's cached snapshot. Do not hard-code any string (GEMINI.md rule 11).

---

### 03.20 — Conflicts screen with diff view and resolution actions

**Purpose.** Let the user review every conflict copy and resolve it: keep mine, keep theirs, keep both, or edit a merge.

**Files.** `app/lib/sync_ui/conflicts/conflicts_screen.dart`, `app/lib/sync_ui/conflicts/conflict_detail_screen.dart`,
`app/lib/sync_ui/diff/diff_view.dart` (shared with step 03.21), `app/lib/sync_ui/diff/diff_model.dart`,
`packages/tephra_sync/lib/src/merge/display_diff.dart`, `packages/tephra_sync/lib/src/engine/conflict_resolver.dart`; tests mirror.

**Implementation.**
1. `display_diff.dart` (pure): `List<DiffLine> lineDiff(String a, String b)` using the step 03.9 line codec + `diff_match_patch`, followed by
   `diffCleanupSemantic`; `DiffLine { DiffKind kind (same|removed|added); String text; int? aLine; int? bLine; }`; plus `List<SideBySideRow> sideBySide(...)`
   pairing removed/added runs row by row. Runs in `Isolate.run` for texts over 2,000 lines.
2. **Conflicts screen**: list of unresolved `ConflictRecord`s (path, conflict copy path, other device, time, kind text/binary/case). Empty state text.
   Badge count also in the sync panel.
3. **Conflict detail**: "Their version" = the file at `path` (the remote version that won the path); "Your version" = the conflict copy. For text:
   desktop (≥ 840 dp) shows a **side-by-side** diff (two scroll-synchronised columns, removed lines red tint, added lines green tint, line numbers);
   phone shows a **stacked** unified diff (one column, `-`/`+` gutters). For binary: file names, sizes, modified times, image thumbnails for images, and
   "Open" buttons for both files.
4. Actions (`ConflictResolver` in the package, executed in the worker through `ResolveConflict`):
   - **Keep mine**: snapshot both into local history, write the conflict copy's content to `path` (normal edit → synced), move the conflict copy to vault trash.
   - **Keep theirs**: move the conflict copy to vault trash.
   - **Keep both**: mark resolved; files stay as they are.
   - **Edit merge** (text only): opens an editor pane (a plain multi-line `TextField` with monospace font is sufficient here) prefilled with "their" text;
     the diff stays visible above (desktop) or in a toggle (phone); Save → write the edited text to `path`, move the copy to vault trash.
   Every action marks the record resolved and writes a log line. Nothing is ever deleted permanently (vault trash + remote history keep everything).
5. If the user resolves a conflict outside this screen (deletes the copy in the explorer), the next cycle marks the record resolved automatically when the
   copy file no longer exists.
6. l10n keys: `conflictsTitle`, `conflictsEmpty`, `conflictsFrom` (`{device}`, `{time}`), `conflictTheirVersion`, `conflictYourVersion`,
   `conflictKeepMine`, `conflictKeepTheirs`, `conflictKeepBoth`, `conflictEditMerge`, `conflictSaveMerge`, `conflictResolved`, `conflictBinaryExplain`,
   `conflictKindText`, `conflictKindBinary`, `conflictKindCase`, `diffSideBySide`, `diffInline`.

**Tests.** `display_diff` cases (insert, delete, replace, unchanged; side-by-side pairing); resolver actions on memory FS (each action: resulting files,
trash contents, history snapshots, record resolved); widget tests at 400 dp (stacked) and 1200 dp (side-by-side); auto-resolve when the copy disappears.

**Verify.** Tests pass. Manual: create a same-line conflict between phone and PC (demo script), resolve with each action once.

**Pitfalls.** "Keep mine" writes through the normal vault write path so the editor/index update; never write via a second file-system instance in the UI
isolate while the worker also writes — always go through the worker message.

---

### 03.21 — Version history: local snapshots, remote versions, history screen, recently deleted

**Purpose.** Every note has a browsable history; any old version can be restored (as a new edit) or partly copied; deleted files can be brought back.

**Files.** `packages/tephra_sync/lib/src/history/local_history.dart`, `packages/tephra_sync/lib/src/history/version_history.dart`,
`packages/tephra_sync/lib/src/history/history_retention.dart`, `app/lib/sync_ui/history/history_screen.dart`,
`app/lib/sync_ui/history/deleted_files_screen.dart`, editor hook edit in `app/lib/editor/` (the autosave code); tests mirror.

**Implementation.**
1. **Local snapshots** in the vault (conventions §6.6 `.tephra/history/`, never synced): `.tephra/history/<pathHash>/<yyyyMMddTHHmmssSSSZ>.<ext>.gz`
   where `pathHash` = first 16 hex chars of SHA-256 of the UTF-8 vault path, plus `.tephra/history/<pathHash>/path.txt` containing the vault path (UTF-8,
   rewritten when missing). Content = gzip of the raw file bytes. Kinds: `md`, `txt`, `canvas`, `base` and the synced `.tephra/*.json` (text files only;
   binaries rely on remote history).
   `LocalHistory(VaultFileSystem fs, {Clock clock})`: `snapshot(path, bytes, {required SnapshotReason reason})` (`editing`, `beforeSyncOverwrite`,
   `beforeRestore`, `beforeConflictResolution`) — skip if identical to the newest snapshot of that path; `list(path)`; `read(snapshotRef)`; `prune()`.
2. **Editing snapshots**: the editor's autosave hook calls `localHistory.snapshot(path, bytes, reason: editing)` when the newest snapshot for that path is
   older than **10 minutes** (and the content differs). Runs async, never blocks typing (gzip in `Isolate.run` for files > 256 KiB).
3. **Local retention** (`prune`, run once per day by the worker): keep all snapshots younger than 7 days; between 7 and 30 days keep the newest per day;
   delete older; then, if the total size of `.tephra/history/` exceeds **100 MiB**, delete the oldest snapshots (never the newest snapshot of any path) until
   below. Deleting history files is permanent (they are copies, not user files).
4. **Remote versions**: `VersionHistory.versions(path)` merges (a) local snapshots and (b) remote entries touching the path (`RemoteHistory.versions`, put
   and move entries carry content) into `List<VersionInfo { VersionRef ref; DateTime time; String source /* device name or 'Local snapshot' */; int? size; String? hash; VersionOrigin origin; }>`
   sorted newest first, de-duplicated by hash (keep the newest occurrence, list the others' sources). Remote versions whose blobs were garbage-collected are
   shown as "no longer available" (greyed), not hidden.
5. **Remote history retention** (`HistoryRetention`, pure, used by GC in step 03.23): for each path: always keep every leaf/head; keep every version younger than
   30 days; for 30–365 days keep the newest version per calendar day (UTC); drop versions older than 365 days. Deleted files: the last put before the delete
   follows the same rule (so a deleted note stays restorable for up to a year). Configurable later; constants in one place.
6. **History screen** (command `sync.open-history`, also "Version history" in the note's more-menu and in the explorer context menu): left/top: timeline list
   (time, source, size; "Current" pinned first); selecting a version shows a diff against the current file: **inline** (unified) on phone, and a toggle
   **inline / side-by-side** on desktop (uses `diff_view.dart`). Buttons: "Restore this version" → confirmation → snapshot current (`beforeRestore`) → write
   the old content as a **new edit** (synced like any edit, never destructive); "Copy" → copies the selected text, or the whole version if nothing is selected
   (the version text is selectable). Binary files: list + "Restore" + "Save a copy as…".
7. **Recently deleted** (command `sync.open-deleted`, link in the explorer and sync panel): union of (a) remote paths whose head is a delete within retention,
   (b) files in the vault `.trash/` folder. Each row: path, deleted time, deleting device; "Restore" recreates the file at its path (if the path is taken:
   `<stem> (restored YYYY-MM-DD).<ext>`) from the newest available version; "History" opens the history screen for that path.
8. l10n keys: `historyTitle` (`{name}`), `historyCurrent`, `historyLocalSnapshot`, `historyFromDevice` (`{device}`), `historyUnavailable`, `historyRestore`,
   `historyRestoreConfirm` (`{time}`), `historyRestored`, `historyCopy`, `historyCopied`, `historySaveCopyAs`, `historyEmpty`, `deletedTitle`, `deletedEmpty`,
   `deletedBy` (`{device}`, `{time}`), `deletedRestore`, `deletedRestoredAs` (`{path}`), `deletedOpenHistory`.

**Tests.** Local history: naming, `path.txt`, skip identical, 10-minute rule with fake clock, retention (7/30 days, size cap, newest per path kept);
version merge + de-dup + unavailable flag; retention function table test (ages 1, 29, 31, 200, 364, 366 days; heads always kept); restore writes a new
edit and snapshots the current content; recently deleted from both sources; restore name collision; widget tests at both widths.

**Verify.** Tests pass. Manual: edit a note over 25 minutes (or use a fake clock in a debug build) → at least 2 local snapshots; restore an older version →
change syncs to the other device; delete a note → restore it from "Recently deleted".

**Pitfalls.** `.tephra/history/` must stay excluded from the index (conventions §6.1 ignores `.tephra/`) and from sync (step 03.8). Never restore by
overwriting without a snapshot first.

---

### 03.22 — Backup mode: manifests, schedule, retention, backup-only mode

**Purpose.** Scheduled, encrypted, deduplicated point-in-time snapshots of the local vault that live sync cannot damage.

**Files.** `packages/tephra_sync/lib/src/backup/backup_manifest.dart`, `backup_service.dart`, `backup_retention.dart`, `backup_schedule.dart`;
`app/lib/sync_ui/backups/backups_screen.dart`; tests `test/backup/*_test.dart`, `app/test/sync_ui/backups/backups_screen_test.dart`.

**Implementation.**
1. **Manifest** `backups/<yyyyMMddTHHmmssZ>/manifest.json.enc` (purpose `manifest`; content = gzip of UTF-8 JSON; plain gzip JSON when encryption is off):
   ```json
   { "v": 1, "vaultId": "…", "createdAt": "2026-10-11T03:00:00.000Z", "deviceId": "…", "deviceName": "Office PC",
     "kind": "scheduled", "fileCount": 5678, "totalBytes": 912345678,
     "files": [ { "path": "Folder/Note.md", "hash": "<sha256>", "size": 1234, "mtime": 1760175000000, "blobKeys": ["blobs/<hex>"] } ] }
   ```
   `kind`: `scheduled` | `manual` | `preRestore`. `files` sorted by path. Includes every **participating** file of this device (step 03.8 rules), so
   mobile-mode exclusions also apply to that device's backups (stated in the UI).
2. `BackupService.runBackup({required BackupKind kind})`: acquire `SyncLock`; scan; for each file `BlobStore.putFile` (dedup → only new/changed chunks
   upload; unchanged files cost nothing); write the manifest **last** (a crash before it leaves only unreferenced blobs, collected later); insert into the
   `backups` table; `meta.lastBackupAt`. Progress reported like a sync. Backups never read or write journals and never delete anything except through
   retention (item 4), so a sync mistake cannot change an existing backup.
3. **Schedule** (`BackupSchedule.isDue(now, lastBackupAt, schedule)`): `hourly` → due when `now − last ≥ 1 h`; `daily` → due when `now − last ≥ 24 h`
   **or** the local date changed and local time ≥ 03:00; `weekly` → `≥ 7 days`. Checked by the worker every 5 minutes, at app start, and by the Android
   background task. Only one device needs backups on; every device with backups on writes its own manifests (labelled with its name).
4. **Retention** (`BackupRetention.select(List<DateTime> stamps, {hourly = 48, daily = 30, monthly = 12})` → set to keep; pure): sort newest first;
   keep the newest backup in each of the most recent `hourly` distinct UTC hour buckets, each of the most recent `daily` distinct UTC day buckets, and each of
   the most recent `monthly` distinct UTC month buckets (union); always keep the newest backup and every `preRestore` backup younger than 30 days.
   Values are configurable in settings (`meta.backupRetention`). Pruning (deleting manifests not kept; only manifests written by **this** device) runs after
   each backup. Blobs are never deleted here — only GC (step 03.23) deletes blobs.
5. **Backup-only mode** (`meta.mode = backupOnly`): offered in the setup wizard's choose page as a second card "Back up only (one device, no live sync)"
   and in settings. The engine then skips journals entirely: no `syncOnce`, only scheduled backups, verification and GC. The remote vault and crypto are the
   same, so the user can later switch to live sync (first sync "Merge both").
6. **Backups screen** (`sync.open-backups`, settings section): schedule selector (off/hourly/daily/weekly), retention fields, "Back up now", list of
   backups (date, device, files, size), last verification result, "Restore…" per backup (step 03.23).
7. l10n keys: `backupsTitle`, `backupsSchedule`, `backupsScheduleOff`, `backupsScheduleHourly`, `backupsScheduleDaily`, `backupsScheduleWeekly`,
   `backupsRetentionHourly`, `backupsRetentionDaily`, `backupsRetentionMonthly`, `backupsBackUpNow`, `backupsRunning` (`{done}`, `{total}`), `backupsEntry`
   (`{date}`, `{device}`, `{files}`, `{size}`), `backupsEmpty`, `backupsLastVerification` (`{date}`, `{ok}`, `{failed}`), `backupsRestore`,
   `backupsOnlyModeCard`, `backupsOnlyModeExplain`, `backupsMobileModeNote`.

**Tests.** Manifest JSON round trip; second backup of an unchanged 1,000-file vault uploads zero blobs (count puts); one changed file → exactly its chunks;
crash before the manifest → no manifest, next backup completes; schedule `isDue` table (fake clock, DST-free UTC tests plus one local-time test); retention
property tests (hourly backups for 400 days → 48 + 30 + 12 rule exactly, newest kept, preRestore kept); backup-only mode never writes journals.

**Verify.** `dart test test/backup`; app widget test. Manual: "Back up now" on Windows, then again → second run uploads ~0 bytes (log shows bytes).

**Pitfalls.** A manifest is immutable; never rewrite one. Do not create a separate blob area for backups — dedup across sync and backups is intended, and GC
protects backup-referenced blobs.

---

### 03.23 — Garbage collection (mark-and-sweep with leases), backup verification, restore

**Purpose.** Reclaim space without ever deleting a referenced blob; prove backups are readable; restore files, folders or whole vaults.

**Files.** `packages/tephra_sync/lib/src/gc/garbage_collector.dart`, `gc_lease.dart`, `gc_state.dart`; `packages/tephra_sync/lib/src/backup/backup_verifier.dart`,
`restore_service.dart`; `app/lib/sync_ui/backups/restore_screen.dart`; tests `test/gc/*`, `test/backup/backup_verifier_test.dart`,
`test/backup/restore_service_test.dart`, app widget test.

**Implementation.**
1. **When GC runs**: at most once per 7 days per vault (`meta.lastGcAt`), only on a device on an unmetered network and (Windows, or Android while charging),
   from the worker's schedule check or the background task. Never during the first sync.
2. **Lease** (Drive has no compare-and-swap, so there is no single shared lock file; each device writes its own lease and a deterministic rule picks one
   winner):
   1. Write `locks/gc-<me>.json.enc` (purpose `lock`): `{"v":1,"deviceId":"…","hlc":"…","createdAt":"…"}`.
   2. Wait at least **2 minutes** (the GC is a state machine across worker ticks; do not block).
   3. `list('locks/')`; a lease is **live** if its `RemoteObject.modified` (server time) is ≥ my lease's `modified` − 30 minutes. Among live leases, the winner
      is the smallest `(hlc, deviceId)`. Not the winner → delete my lease, stop. Winner → proceed, and rewrite my lease every 10 minutes while working.
   4. At the end delete my lease. Comparing server timestamps only avoids problems with wrong device clocks.
3. **Mark** (complete, not incremental): read **all** journal batches of **all** devices from seq 1 (stream them; do not rely on snapshots or on the local
   `remote_entries` cache), all snapshots, all backup manifests (after this device's retention pruning), and compute the live set:
   (a) blobs of every head and every leaf of every path; (b) blobs of every version kept by `HistoryRetention` (step 03.21); (c) blobs referenced by every
   existing snapshot; (d) blobs referenced by every existing backup manifest; (e) blobs referenced by entries of revoked devices (kept too).
   If any journal batch, snapshot or manifest fails to read or decrypt → **abort GC** (log `severe`), delete nothing.
4. **Sweep (two-phase)**: `locks/gc-state.json.enc` (purpose `gcState`): `{"v":1,"updatedAt":"…","candidates":{"blobs/<hex>":"<firstSeenUnreferencedAt ISO>"}}`.
   For every remote blob (`list('blobs/')`) not in the live set: if `created` (server time) is younger than **7 days** → skip (it may belong to an upload whose
   journal commit is pending); if not yet a candidate → add with now; if a candidate for ≥ **24 h** → `provider.delete` (Drive: moves to Drive trash) and
   remove from candidates. Candidates that became referenced again are removed from the state. Write the new state. Delete at most 5,000 blobs per run.
5. Executor safety link (already in step 03.5): reused blobs whose `blob_index.seen_at` is older than 24 h are re-confirmed before reuse, so a blob that is a GC
   candidate is either re-confirmed (and its new reference stops its deletion on the next run) or re-uploaded.
6. **Backup verification** (`BackupVerifier.verify(stamp)`): weekly (`meta.lastVerificationAt`), also via "Verify now": take the newest backup manifest;
   sample 5% of its blob keys at random (minimum 20, maximum 500, all if fewer than 20); download each, check the hash in the key, decrypt, check that
   files made only of sampled one-chunk blobs match their manifest hash. Store a `backup_verifications` row; any failure → `needsAttention` with
   `backupVerificationFailed` and the failed keys in the log (never deletes anything).
7. **Restore** (`RestoreService`): input `RestoreRequest { String stamp; List<VaultPath> selection /* empty = whole vault */; RestoreTarget target }` with
   `RestoreTarget.intoVault` or `RestoreTarget.newFolder(String absolutePath)`.
   - Into the vault: for each selected file: absent locally → write it; present with the same hash → skip; present with a different hash → write as
     `<stem> (restored YYYY-MM-DD).<ext>` next to it (never overwrite). Before a whole-vault restore into the vault, run a `preRestore` backup.
   - New folder: must be empty or not exist; write all files with their paths (creating folders) through a new `IoVaultFileSystem(absolutePath)`; afterwards
     offer "Open as vault" (uses the Phase 1 vault picker logic).
   - Every file is verified (`getFile` with the expected hash). Progress + a final report (restored, skipped, renamed, failed). Runs in the worker.
8. **Restore screen**: choose backup (list from step 03.22) → tree browser of the manifest (folders expandable, checkboxes; "Select all") → target choice
   (into this vault / into a new folder via folder picker) → confirm → progress → report. Also reachable from "Recently deleted" for a specific file.
9. l10n keys: `gcRunning`, `gcDone` (`{count}`, `{bytes}`), `backupVerificationFailed` (`{count}`), `backupsVerifyNow`, `restoreTitle`, `restoreChooseFiles`,
   `restoreSelectAll`, `restoreTargetVault`, `restoreTargetNewFolder`, `restoreNewFolderMustBeEmpty`, `restoreConfirm` (`{count}`), `restoreRunning`
   (`{done}`, `{total}`), `restoreReport` (`{restored}`, `{skipped}`, `{renamed}`, `{failed}`), `restoreOpenAsVault`.

**Tests.** GC with `MemorySyncProvider` and a fake clock: referenced blobs never deleted across 1,000 random histories (property test: build random histories
with the simulator from step 03.12, run GC repeatedly while advancing time 8 days, then assert every head, retained version, snapshot and backup still fully
downloads); unreferenced blob deleted only after the 7-day grace **and** a second run ≥ 24 h later; unreadable journal → abort, nothing deleted; two devices
running GC concurrently → exactly one proceeds (lease rule with controlled server timestamps); expired leases ignored. Verifier: all-good report; corrupted
blob → failure recorded. Restore: each target and collision rule; new folder must be empty; whole-vault restore runs a preRestore backup first.

**Verify.** `dart test test/gc test/backup`. Manual: restore yesterday's whole vault into a new folder on Windows (demo script) and open it.

**Pitfalls.** GC is the **only** code that deletes blobs. When in doubt (any read error, any unknown key format, any manifest version > 1), GC deletes nothing.

---

### 03.24 — Nightly CI, live contract, format document, real-device test procedure

**Purpose.** Wire the long tests into CI, freeze the remote-format document for Phase 10, and run the real-device checks the exit gate needs.

**Files.** `.github/workflows/nightly.yml`, `.github/workflows/ci.yml` (edit: exclude `fuzz`/`live` tags), `docs/decisions/sync-format-v1.md`,
`docs/testing/sync-real-device.md`, `PROGRESS.md`.

**Implementation.**
1. `ci.yml`: the existing package test step must run `dart test -x live` in `packages/tephra_sync` (fuzz with its small default stays included).
   Before any app build step that needs OAuth values, create the secrets file from repository secrets (or the example file when secrets are absent):
   ```yaml
   - name: OAuth config
     shell: pwsh
     run: |
       New-Item -ItemType Directory -Force secrets | Out-Null
       if ($env:CID) { @{TEPHRA_GOOGLE_ANDROID_SERVER_CLIENT_ID=$env:ASID; TEPHRA_GOOGLE_DESKTOP_CLIENT_ID=$env:CID; TEPHRA_GOOGLE_DESKTOP_CLIENT_SECRET=$env:CSEC} | ConvertTo-Json | Set-Content -Encoding utf8 secrets/google_oauth.json }
       else { Copy-Item secrets/google_oauth.example.json secrets/google_oauth.json }
     env:
       ASID: ${{ secrets.TEPHRA_GOOGLE_ANDROID_SERVER_CLIENT_ID }}
       CID: ${{ secrets.TEPHRA_GOOGLE_DESKTOP_CLIENT_ID }}
       CSEC: ${{ secrets.TEPHRA_GOOGLE_DESKTOP_CLIENT_SECRET }}
   ```
   and pass `--dart-define-from-file=../secrets/google_oauth.json` to the app build commands. (Ask the human to add `TEPHRA_GOOGLE_ANDROID_SERVER_CLIENT_ID`
   as a secret too.)
2. `nightly.yml`: `on: schedule: - cron: '30 1 * * *'` and `workflow_dispatch`. Job on `ubuntu-latest` (pure Dart, cheaper minutes): checkout, set up
   Flutter 3.47.7 (same action as `ci.yml`), `flutter pub get`, then in `packages/tephra_sync`:
   - `dart test test/simulator/fuzz_test.dart` with `TEPHRA_FUZZ_OPS: 100000` and `TEPHRA_FUZZ_SEED: ${{ github.run_number }}` (timeout 120 minutes);
   - `dart test --run-skipped -t live test/drive/drive_live_test.dart` with the three secrets as env vars (step skipped with a notice if the refresh token
     secret is empty).
   If sqlite loading differs on Linux, copy the exact set-up `tephra_index`'s CI job uses. Failure output must include the seed.
3. `docs/decisions/sync-format-v1.md`: copy (do not paraphrase) the frozen parts of this file: remote key table (03.2), envelope + purposes + KDF + key wrap +
   recovery key (03.4), chunking (03.5), `vault.json` (03.6), HLC + entry + batch + snapshot (03.7), manifest (03.22), lease/GC-state (03.23), and the Drive
   folder mapping (03.15). Add a "Compatibility rules" section: readers ignore unknown JSON fields and unknown keys; any change to bytes on the wire requires
   `formatVersion` 2 and a migration plan.
4. `docs/testing/sync-real-device.md` — the procedure below; run it and record every result (pass/fail, numbers) in `PROGRESS.md`:
   1. **Fresh install pair**: PC creates an encrypted remote vault from a copy of the human's real vault; phone connects (wrong password once, then right);
      first sync downloads everything; compare file count and a hash list (`tool` not required: use the sync log counts + spot-check 10 notes).
   2. **Latency**: with both apps open, edit a note on the PC, start a stopwatch at save; stop when the phone shows the change. Repeat 10 times both
      directions; record max and median. Gate: every run ≤ 60 s.
   3. **Airplane day**: phone in airplane mode edits 10 notes over a day; PC edits 5 of the same notes (different paragraphs in 3, same line in 2) and 5 others;
      reconnect → expect 3 clean merges, 2 conflict copies, all other edits present on both devices.
   4. **Network loss mid-upload**: start uploading a 50 MB video on the PC, pull the network for 2 minutes, restore → upload completes, no duplicate file.
   5. **Rate limiting**: run the fake-server fault test (already automated) and, on the real account, sync a folder of 3,000 small files; any 403/429 in the
      log must be followed by success without user action.
   6. **Expired token**: on Windows, delete the stored access token and set the refresh token to an invalid value (debug command `sync.debug-break-token`,
      debug builds only) → "Reconnect" appears → reconnect → sync resumes without asking for the vault password. On Android, remove Tephra's access at
      https://myaccount.google.com/permissions → reconnect flow works.
   7. **Drive full**: use a test account filled close to its limit (or the fake server quota in a debug build via `sync.debug-fake-quota`) → warning shown,
      uploads stop, downloads continue, freeing space resumes uploads.
   8. **Background 24 h**: phone unplugged, app closed, background sync on, normal vault; after 24 h record the "Tephra" battery percentage from
      Settings → Battery (gate: < 2%/day) and confirm that edits made on the PC during the day arrived.
   9. **Readable-data check** (encryption on): download the whole `Tephra/<vault>` folder from drive.google.com (zip); on the PC search the extracted files for
      5 distinctive words from notes and 5 note file names (`Select-String -Path <folder> -Pattern '<word>' -Recurse -SimpleMatch`): zero matches expected
      (the vault name may appear in `vault.json`, by design). Repeat with a test vault created with encryption off and confirm text is readable.
   10. **Clone safety**: copy the PC's `<appSupportDir>/sync` folder to a second Windows user account/PC (optional if no second PC) → the clone is detected and
       gets a new device id; nothing lost.
   11. **Daily beta**: install the build on the human's phone and PC; use daily for 2 weeks; each day note any sync problem in `PROGRESS.md`.
5. Debug-only commands named above (`sync.debug-break-token`, `sync.debug-fake-quota`) exist only when `kDebugMode` is true and are not shown in release builds.
6. Run the Argon2id floor timing on the human's phone (`Stopwatch` around unlock, recorded in the log at `info`) and record it; > 5 s → stop and ask (step 03.4).

**Tests.** None new beyond workflow linting: run `dart test -x live` locally to mirror CI.

**Verify.** Push the branch; CI is green; trigger `nightly.yml` manually (`gh workflow run nightly.yml --ref phase-03`) and record its result and duration.

**Pitfalls.** Never echo secrets in workflow logs (`Set-Content` only; no `cat`). GitHub disables scheduled workflows in repositories without activity for
60 days — not an issue during active development, but mention it in `PROGRESS.md`.

---

## Demo script

Run on the human's real phone and this PC with a real Google test-user account (steps follow PHASE_PLAN Phase 3). Record each result in `PROGRESS.md`.

1. **PC**: open the vault → Settings → Sync & backup → Set up sync → sign in with Google in the browser → "Create a new remote vault" → encryption on,
   set a password → save the recovery key to a file → confirm groups 2 and 7 → "Upload this vault" → progress reaches 100% → Done with "daily backups" on.
2. Open drive.google.com → `Tephra/<vault name>/` exists with `blobs`, `journals`, … and only hash/number-named files.
3. **Phone**: open/create an empty vault folder → Set up sync → Sign in with Google → pick the remote vault → enter the password → "Download the vault" →
   all notes appear; open one note and compare with the PC.
4. Put the phone in airplane mode; on the phone edit paragraph 1 of `Demo.md`; on the PC edit paragraph 3 of the same note; turn airplane mode off →
   within 60 s both devices show both edits; the log says "Merged changes from …".
5. Edit the **same line** of `Demo.md` on both devices while the phone is offline; reconnect → one device shows `Demo (conflict YYYY-MM-DD HH-mm <Device>).md`;
   the conflicts screen shows the side-by-side diff (PC) / stacked diff (phone); choose "Edit merge", combine both lines, save → both devices converge,
   the conflict disappears.
6. Delete `Delete me.md` on the PC → it disappears on the phone (it is in the phone's vault trash) → on the phone open "Recently deleted" → Restore →
   the note returns on both devices.
7. Open the history of `Demo.md` → pick an older version → inline diff (phone) / side-by-side (PC) → "Restore this version" → restored as a new edit on both.
8. PC: Backups → "Back up now" (if no backup from yesterday exists, take one now and one after editing a few notes) → "Restore…" on the older backup →
   whole vault → "into a new folder" → open the new folder as a vault → the notes match that point in time.
9. Show the tray tooltip (PC) and the status indicator states syncing → up to date (both devices).

## Exit gate

Check every item; record numbers and dates in `PROGRESS.md`. Any failing item → stop and ask the human (GEMINI.md §5).

- [ ] All steps 03.1–03.24 ticked; `flutter analyze --fatal-infos` 0 issues; every package's tests and `flutter test` pass; `dart run tool/check_licenses.dart` passes; `git check-ignore secrets/google_oauth.json` prints the path.
- [ ] Fuzz test: 100k operations, 0 lost content, convergence every run — nightly job green for **7 consecutive nights** (record seeds and durations).
- [ ] Crypto known-answer tests pass (AES-GCM, HKDF, Argon2id RFC 9106) and the frozen envelope/chunking golden constants are unchanged.
- [ ] Provider contract suite passes for `MemorySyncProvider`, `DriveSyncProvider` on the fake server, and the live Drive test account (nightly).
- [ ] Demo script passes on a real phone and the PC with a real Google account.
- [ ] A save on one device appears on the other within **60 s** when both apps are open (10 runs each direction; record median and max).
- [ ] Sync recovers by itself after: network loss mid-upload, Drive rate limiting, expired/revoked token (after the user taps Reconnect, without re-entering the vault password), Drive storage full (with a clear warning) — real-device procedure items 4–7.
- [ ] Android background sync works with the app closed for 24 h; Tephra battery use < 2%/day (record the percentage).
- [ ] With encryption on, the downloaded Drive folder contains no readable note text and no note file names (real-device item 9; the vault name in `vault.json` / folder name is allowed by design).
- [ ] Argon2id unlock time on the phone recorded (floor parameters) and ≤ 5 s.
- [ ] Performance budgets of conventions §10 still met with sync enabled and idle (cold start, typing latency, search); no dropped frames while a 500-file sync runs.
- [ ] `dart run tool/dev.dart` (web preview) still starts and shows "Sync is not available in the web preview" in the sync settings.
- [ ] Beta build installed on the human's phone and PC and used daily for **2 weeks** with no data loss (daily notes in `PROGRESS.md`; record whether weekly reconnects happened because of the Testing-mode 7-day token limit).
- [ ] `docs/decisions/sync-format-v1.md` and `docs/testing/sync-real-device.md` committed.
- [ ] Merge `phase-03` into `main` with `--no-ff`, tag `v0.03.0`, stop and report to the human.

## Hand-off

What Phase 10 (Tephra Cloud) relies on. All of it is frozen in `docs/decisions/sync-format-v1.md`; changing any of it needs `formatVersion` 2.

1. **Provider interface** — `SyncProvider` exactly as conventions §7.6 with the semantics written in step 03.2 (string-prefix `list`, sorted and
   de-duplicated; `put` = create or replace; `delete` of a missing key is a no-op; `changesSince(null)` returns only a start cursor; `cursorWasReset`;
   `RemoteObject.modified/created` are **server** times). The shared contract suite `runSyncProviderContract` must pass for the Tephra Cloud provider.
   The engine never needs compare-and-swap; a server may offer it, but the format must not depend on it.
2. **Remote layout** — keys `vault.json`, `blobs/<sha256 of stored bytes>`, `journals/<deviceId>/<10-digit firstSeq>.json.enc`,
   `snapshots/<deviceId>/<10-digit seq>.json.enc`, `backups/<yyyyMMddTHHmmssZ>/manifest.json.enc`, `devices/<deviceId>.json.enc`,
   `devices/<deviceId>.revoked.json.enc`, `locks/gc-<deviceId>.json.enc`, `locks/gc-state.json.enc`; single-writer rule per key; blobs immutable.
   Moving a vault from Drive to Tephra Cloud = copy every key's bytes unchanged (no decryption, no re-encryption); afterwards each device switches
   `providerId` and keeps its sync DB (cursors stay valid because keys and seqs are identical; the changes cursor is reset).
3. **Journal format** — batch JSON (`v`, `deviceId`, `firstSeq`, `lastSeq`, `createdAt`, `entries`), entry fields (`seq`, `hlc`, `time`, `op` put|delete|move,
   `path`, `fromPath`, `hash`, `size`, `mtime`, `blobKeys`, `parent`, `targetParent`, `mergedParent`), HLC string form and ordering, head/leaf/fork rules,
   snapshots every 500 entries with `covers`.
4. **Crypto header** — `vault.json` fields (`kdf` Argon2id v19 params + salt, `wrappedKeys.password/recovery` AES-256-GCM with AAD
   `tephra-wrap-v1|<vaultId>|<kind>`, recovery KEK = HKDF info `tephra/v1/recovery-kek`), object envelope `TPH1` (version 1, purpose byte, 16-byte salt,
   12-byte nonce, ciphertext, 16-byte tag; AAD = header + vault id; object key = HKDF(master, salt, purpose info)), plaintext mode (`"encryption": "none"`).
   The server only ever stores these bytes; it never sees passwords or keys.
5. **Chunking** — files ≤ 4 MiB one blob; larger: FastCDC gear32 v1 (min 256 KiB, avg 1 MiB, max 4 MiB, gear table from SHA-256 of `tephra-gear-v1-<i>`).
6. **GC and retention** — only one GC at a time via per-device leases compared by server time; two-phase sweep; 7-day grace; history retention
   (all versions 30 days, daily to 365 days); backup retention 48/30/12. A server-side GC in Phase 10 must keep exactly the same live set.
