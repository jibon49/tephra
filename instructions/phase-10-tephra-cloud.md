# Phase 10 — Tephra Cloud: our own online backup & sync → v2.0

> **Duration:** 6 weeks (one full-time developer, ~15% buffer included) + a 7-day staging soak that overlaps the last week.
> **Goal:** a real hosted service so users need no Google account: a Dart server (`server/`) that stores the **already end-to-end-encrypted** Phase 3 remote format,
> accounts with email verification, instant push (a save on one device appears on another within ~1–3 s), quotas, rate limits, daily off-site backups, monitoring, a Docker/Caddy
> deployment on a VPS, a self-host build (Windows `.exe`, Linux binary, Docker image), the `TephraCloudSyncProvider` in the app, sign-up/sign-in/forgot-password screens,
> a storage screen, and **"Move vault from Google Drive to Tephra Cloud"** (copy every object key-for-key, verify, switch, optionally keep Drive as an extra backup).
> The sync engine, planner, crypto and remote format **do not change** (conventions §7.6, `docs/decisions/sync-format-v1.md`): this phase adds a provider and a server.
>
> **Decisions made for you (do not revisit):**
> server = Dart `shelf` (BSD-3) + `sqlite3` (MIT, hand-written SQL, **no drift/codegen on the server**) + blobs on **local disk by default**, S3-compatible via `minio` (MIT, verified) as an option;
> auth = email + password (server-side **Argon2id**, OWASP-minimum parameters), **JWT access tokens (15 min, HS256) + rotating refresh tokens with reuse detection and a 30-second concurrency grace**;
> the server stores **only** the encrypted bytes Phase 3 produces and **never** runs blob garbage collection (it cannot read journals; GC stays client-side exactly as in 03.23);
> deleted objects are kept in a server-side **trash for 30 days** (retention, restorable by the admin CLI); the account password is **not** the vault password (the app says so in every screen that asks for either);
> Tephra Cloud **requires vault encryption to be on** (the app does not offer "encryption off" for it); one SQLite database on one node (no clustering in v2.0);
> TLS is terminated by **Caddy** (automatic certificates); backups use **restic** to an S3-compatible bucket in a different provider; server `PORT` default **8094** (conventions §11; PHASE_PLAN's 8092 is wrong).

Read this whole file once before starting step 10.1. Then do the steps strictly in order. Every step ends with the standard GEMINI.md §3 loop
(format, analyze, tests of touched packages, tick `PROGRESS.md`, commit `phase 10.N: <summary>`).

---

## Before you start

### Prerequisite gate (check each; write the result in `PROGRESS.md`)

1. `PROGRESS.md` shows the Phase 9 exit gate fully checked; `git tag` lists `v1.0.0`; v1.0 is published and **Drive sync has been stable in real use** (no open sync/data-loss issue in `PROGRESS.md`). If any is open, stop and tell the human.
2. You are on `main`, the tree is clean; `git checkout -b phase-10`.
3. `flutter analyze --fatal-infos` = 0; `dart test` passes in every package; `flutter test --exclude-tags golden` passes; `dart run tool/check_licenses.dart` passes; `dart test tool/test` passes.
4. The human has given the decisions in **H1–H3** below **before step 10.19**; H1/H4/H8 have lead time, so ask for them in your first message of the phase. Steps 10.1–10.18 need no hosting.
5. Read `docs/decisions/sync-format-v1.md` and Phase 3 steps 03.2, 03.7, 03.11, 03.15, 03.16, 03.23 again: the client behaviour you must preserve lives there.

### What already exists (from Phases 0–9) and what you rely on

Look at the real code before using any item (Grep tool / `Select-String`).

| Thing | Where | Used for |
|---|---|---|
| `SyncProvider`, `RemoteObject`, `RemoteChanges`, `Quota`, `RemoteLayout` (+ `RemoteKey` parser), `MemorySyncProvider`, `runSyncProviderContract` | `packages/tephra_sync/lib/src/provider/`, `…/remote/`, `test/support/` | the contract the server and `TephraCloudSyncProvider` implement |
| Sync exceptions (`AuthRevokedException`, `NetworkUnavailableException`, `RateLimitedException`, `RemoteServerException`, `RemoteQuotaExceededException`, `RemoteNotFoundException`, `RemoteFormatException`, `RemoteVaultMissingException`, `SyncLockedException`, `DeviceRevokedException`, `DeviceCloneDetectedException`) | `packages/tephra_sync/lib/src/errors/` | error mapping (10.13) |
| `DriveRetry` (full-jitter backoff, 6 retries, `Retry-After`) | `packages/tephra_sync/lib/src/drive/drive_retry.dart` | pattern for `CloudRetry` |
| `AccessTokenSource`, `SecretStore`, `AuthedClient` | `packages/tephra_sync/lib/src/auth/` | `CloudTokenSource`, `CloudAuthedClient` |
| `RemoteVaultManager`, `VaultHeader` (unknown fields preserved), `DeviceRegistry` | `packages/tephra_sync/lib/src/remote/` | migration (10.17) |
| `JournalReader`, `RemoteHistory`, `Planner`, `SyncEngine`, `SyncStateStore` (`meta.providerId`) | `packages/tephra_sync/lib/src/` | migration verification, provider switch |
| `GarbageCollector` (leases compare **server** `RemoteObject.modified`), `BackupService`, `RestoreService` | `packages/tephra_sync/lib/src/gc/`, `…/backup/` | must work unchanged over the cloud provider |
| Simulator `SimWorld`, `fuzz_test.dart`, crash-point drill, `tool/drill_kill_sync.dart`, `DirectorySyncProvider`, `DamagedRemote` | `packages/tephra_sync/test/`, `tool/` | cloud fuzz/drills (10.14) |
| Sync worker isolate, `SyncTriggers`, message protocol, `TokenRequest/TokenReply` | `app/lib/core/sync/` | WS push trigger (10.13) |
| Setup wizard, status panel, devices screen, backups UI | `app/lib/sync_ui/` | provider choice, account UI (10.15–10.16) |
| `SecureSecretStore` (flutter_secure_storage) | `app/lib/core/sync/secure_secret_store.dart` | cloud tokens |
| Updater, About page, `release.dart`, legal templates, `legal_test`, `PLACEHOLDERS.md` | Phase 9 | ship v2.0, legal (10.22) |
| CI `ci.yml`, `nightly.yml`; `.gitignore` (`secrets/*`, `.data/` added in Phase 9) | repo | server jobs (10.21) |

If any item is missing, stop and tell the human (GEMINI.md §5). Do not build it silently.

---

## Human prerequisites

Copy this whole section into your first message to the human. Items marked **now** have lead time.

### H1. Domain, VPS and DNS (**now**; needed before 10.19)

1. Choose a **domain** you control and a sub-domain for the service: production `cloud.<yourdomain>`, staging `staging-cloud.<yourdomain>` (tell Gemini the real names). The DNS must be editable by you.
2. Create a **VPS**: recommended minimum **2 vCPU, 4 GB RAM, 80 GB SSD, Ubuntu 24.04 LTS** in the region closest to most users (for example a Hetzner Cloud CX-class server; any provider works). Enable IPv4 (and IPv6 if offered). Choose **no** managed database and **no** control panel.
3. Create an SSH key on this PC if you have none: PowerShell `ssh-keygen -t ed25519 -C "tephra-vps"` (accept the default path, set a passphrase). Add the **public** key (`$env:USERPROFILE\.ssh\id_ed25519.pub`) in the provider's console when creating the server. **Never** give Gemini the private key.
4. After the server exists, create two DNS records at your DNS host: `A cloud.<yourdomain> → <server IPv4>` and `A staging-cloud.<yourdomain> → <server IPv4>` (and the same two with `AAAA` for IPv6). Check with `Resolve-DnsName cloud.<yourdomain>`.
5. Tell Gemini: server IP, SSH user (default `root` first; Gemini's guide creates a `tephra` user), domain names. Gemini may run **read-only** commands over SSH after you say "go"; every command that changes the server is shown to you first and run only after your OK.

### H2. Outgoing email (SMTP) (**now**; needed before 10.19; dev uses log mode)

1. Pick a transactional email provider with an SMTP option and a free tier (for example Brevo, Resend, Postmark, Amazon SES or your domain's mail host). Create an account.
2. Add your domain in the provider and publish the DNS records it shows: **SPF** (TXT), **DKIM** (TXT or CNAME), and a **DMARC** TXT record `_dmarc.<yourdomain>` with `v=DMARC1; p=none; rua=mailto:<your email>` (tighten later). Wait until the provider shows the domain as verified.
3. Create an SMTP user/password (or API-key-as-password). Sender address: `no-reply@<yourdomain>`.
4. You will type these values into the server's env file **yourself** on the VPS (Gemini prints the file with placeholders): `SMTP_HOST`, `SMTP_PORT` (587 for STARTTLS or 465 for SSL), `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`.

### H3. Product decisions (needed before 10.10 and 10.22)

Answer in one message (defaults in brackets are used if you say "defaults"): free storage per account [**1 GiB**]; max vaults per free account [**3**]; max devices [**5**]; sign-up open to everyone, or invite-code only for the launch [**invite code during staging and the first month, then open**]; trash retention [**30 days**]; whether the self-host server is free to use for individuals [**yes, personal and internal use; no resale**]; legal owner/contact for the Terms (same as Phase 9 H7).

### H4. Off-site backup bucket (**now**; needed before 10.20)

1. Create an account with an S3-compatible storage provider **different from the VPS provider** (for example Backblaze B2, Cloudflare R2 or Wasabi). Create a **private** bucket `tephra-backups-<random>` and an application key limited to that bucket (read + write + list + delete).
2. Copy: endpoint URL (for example `s3.eu-central-003.backblazeb2.com`), bucket name, key id, application key.
3. Choose a **restic repository password** (≥ 20 characters). Store it in your password manager **and** in a second offline place. **If it is lost the backups are unreadable.**
4. You will type these into `/opt/tephra/backup.env` on the VPS yourself (Gemini prints the template).

### H5. Monitoring accounts (needed before 10.20)

Create free accounts at an uptime monitor (UptimeRobot or Better Stack) and at https://healthchecks.io (a dead-man's switch for the backup job). Choose the alert email/phone. Give Gemini the **Healthchecks ping URLs** only when asked (they are secrets-like; they go into `backup.env` by you).

### H6. Dev PC tools (needed before 10.19)

Docker is needed to build and test the container locally. If it is not installed, tell Gemini; **Docker Desktop** is free for personal and small-business use (`winget install -e --id Docker.DockerDesktop`, needs administrator approval, a reboot and WSL 2). If you prefer not to install it, Gemini builds the Docker image in GitHub Actions (job `server-release`, 10.21) and the restore drill runs on the VPS or on a temporary VM instead; say which you choose.

### H7. Real-device test data (needed before 10.17 and 10.24)

A **10,000-note encrypted vault already synced to Google Drive** by the Phase 3 app (use the bench vault: `dart run tool/gen_bench_vault.dart`, open it as a vault on the PC, set up Drive sync with encryption, let it finish; this can take hours — start it early), the Android phone, and a second Windows or Android device for the live push test.

### H8. Legal and launch (needed before 10.22 and the v2.0 tag)

Review the Terms of Service and the privacy-policy update (Gemini writes templates). Decide the **service-status page** and **support email**. Decide whether the public server image is pushed to a public registry (GitHub Container Registry) for self-hosters, or only the Windows/Linux binaries are offered.

---

## What exists when done

- `server/` (Dart package `tephra_server`, depends on `tephra_core`, `tephra_sync` per conventions §3): REST + WebSocket API (spec below), SQLite metadata with migrations, local-disk and S3 blob storage, Argon2id password hashing, JWT + rotating refresh tokens, email verification and password reset, quotas and plans, token-bucket rate limiting, size limits, trash retention and background jobs, admin CLI `tephra-admin`, structured JSON logs, `/health` `/ready` `/metrics`, graceful shutdown, config via env + YAML file, the HTML pages for verify/reset/legal, dev-mode defaults (`PORT` 8094).
- `packages/tephra_sync/lib/src/cloud/` (pure Dart): `TephraCloudSyncProvider`, `CloudAuthApi`, `CloudTokenSource`, `CloudEventsClient` (WebSocket), `CloudRetry`, API DTOs shared with the server, `CloudVaultDirectory`; `RemoteVaultDirectory` interface (Drive + Cloud); `RemoteKeyExistsException`, `AccountActionRequiredException`; `VaultMigrator`, `MigrationVerifier`, `MirrorService`.
- `app/`: provider choice in the setup wizard, sign-up / sign-in / verify-email / forgot-password screens, account and **storage usage** screens, devices screen integration, **Move to Tephra Cloud** wizard, "switch device" flow for other devices, Drive mirror option; save-debounce 1 s for the cloud provider; WS push trigger.
- Hosting: `server/Dockerfile`, `deploy/compose.yml`, `deploy/Caddyfile`, `deploy/compose.selfhost.yml`, `deploy/backup/` (restic scripts), `docs/ops/` (VPS guide, backup, monitoring, restore drill, upgrade, self-hosting incl. Tailscale and Cloudflare Tunnel), CI jobs `server` and `server-release`, artifacts: Windows `.exe` zip, Linux x64/arm64 tarballs, Docker image.
- Tests: server unit/integration tests, the **Phase 3 provider contract suite against a real test server instance**, the **Phase 3 fuzz simulator** and the **Phase 9 crash/kill/corruption drills** against the cloud provider, a load test (100 concurrent devices) and a soak agent.
- `docs/decisions/cloud-api-v1.md` (frozen API), `docs/legal/TERMS_OF_SERVICE.md`, `docs/legal/PRIVACY_POLICY.md` (cloud section), `docs/legal/SELF_HOST_LICENSE.md`, account-deletion flow.
- Release v2.0.0 through the Phase 9 updater.

---

## Dependencies

Server (`dart pub add` inside `server/`), app/package additions where stated. Then `flutter pub get` at the repo root and `dart run tool/check_licenses.dart`.
Licences were verified on pub.dev when this file was written where marked; **re-check each package's page (licence + README + current API) when you add it**.

| Package | Where | Licence | Why |
|---|---|---|---|
| `shelf` | server | BSD-3-Clause | HTTP server framework |
| `shelf_router` | server | BSD-3-Clause | routing (`<key\|.*>` regex parameters for object keys) |
| `shelf_web_socket` (3.0.0) | server | BSD-3-Clause (verified) | WebSocket upgrade |
| `web_socket_channel` | server, tephra_sync | BSD-3-Clause | WS server side + client (`IOWebSocketChannel` with headers) |
| `sqlite3` | server | MIT | metadata DB (hand-written SQL). Follow how `tephra_index` loads SQLite for pure-Dart tests; on Linux the runtime needs `libsqlite3` (Docker image installs it) unless the package version bundles it (read its README) |
| `cryptography` (Apache-2.0, already in tephra_sync) | server | Apache-2.0 | Argon2id password hashing, HMAC |
| `dart_jsonwebtoken` (3.4.1) | server | MIT (verified) | HS256 access tokens |
| `mailer` (7.2.0) | server | MIT (verified) | SMTP |
| `minio` (3.5.8) | server | MIT (verified; pure Dart) | S3-compatible blob storage |
| `yaml` | server | MIT | config file |
| `args` | server | BSD-3-Clause | CLI parsing (`tephra-admin`, server flags) |
| `uuid` | server | MIT | ids |
| `logging`, `path`, `crypto`, `collection`, `http` | server | BSD-3-Clause | as everywhere (`http` also in tests and in `tephra_sync` cloud provider) |
| `markdown` (dev, tool only) | repo root dev | BSD-3-Clause | generate legal HTML pages into Dart constants (`tool/gen_legal_pages.dart`) |
| `tephra_core`, `tephra_sync` | server | internal | `RemoteLayout`, key validation, DTOs (conventions §3: `server ← core, sync`) |
| `web_socket_channel` | `tephra_sync` (cloud events client) | BSD-3-Clause | WS client |
| `app_links` / others | — | — | **not** used in this phase |

External tools (not dependencies, never linked or shipped in the app): Docker, Caddy (Apache-2.0), restic (BSD-2-Clause), `adobe/s3mock` Docker image (Apache-2.0) for S3 tests, Healthchecks/uptime monitors. **Do not use MinIO server (AGPL) anywhere**, not even in tests.
No other new dependencies are allowed in this phase.

---

## The API (frozen by step 10.24 as `docs/decisions/cloud-api-v1.md`)

All paths are under the server origin (`https://cloud.<domain>` or `http://localhost:8094` in dev). JSON bodies are UTF-8, `Content-Type: application/json`; object bodies are
`application/octet-stream`. Times are ISO-8601 UTC with milliseconds (`2026-10-11T09:30:00.123Z`). Every response carries `X-Request-Id` (echoed if the client sent a valid one, else generated).
Authenticated calls send `Authorization: Bearer <accessToken>`. Clients send `User-Agent: Tephra/<version> (<platform>)` and `X-Tephra-Api: 1`.

**Error envelope (every non-2xx):** `{ "error": { "code": "<snake_case>", "message": "<English, technical>", "retryAfterSeconds": 12? } }` plus the `Retry-After` header on 429/503.
`message` is for logs; the app maps `code` to l10n strings.

| HTTP | `code` values | Meaning / client reaction (`tephra_sync` exception) |
|---|---|---|
| 400 | `bad_request`, `invalid_key`, `unknown_key`, `invalid_cursor`, `weak_password`, `invalid_email` | programmer/validation error → `ArgumentError` / `SyncException` (technical) |
| 401 | `unauthorized` (missing/expired access token), `invalid_credentials`, `refresh_invalid`, `refresh_reuse`, `session_revoked` | refresh once, then `AuthRevokedException` |
| 403 | `email_not_verified`, `account_disabled`, `account_pending_deletion`, `device_limit`, `vault_limit`, `signup_closed`, `invite_invalid`, `not_your_vault` | `AccountActionRequiredException(code)` (UI shows the right screen) |
| 404 | `not_found` (object), `vault_not_found` | `RemoteNotFoundException` / `RemoteVaultMissingException` |
| 409 | `email_taken`, `vault_exists`, `immutable_key` | `RemoteKeyExistsException` for `immutable_key` |
| 413 | `too_large` | `SyncException` (object over `MAX_OBJECT_BYTES`) |
| 422 | `checksum_mismatch`, `blob_hash_mismatch` | retry the upload once, then `SyncException` |
| 429 | `rate_limited` | `RateLimitedException(retryAfter)` |
| 500/502/503/504 | `internal`, `unavailable`, `shutting_down` | `RemoteServerException` after retries |
| 507 | `quota_exceeded` | `RemoteQuotaExceededException` |

### Public

| Method + path | Request | Response |
|---|---|---|
| `GET /health` | — | `200 {"status":"ok","version":"2.0.0","uptimeSeconds":4231}` (no DB access; for load balancers) |
| `GET /ready` | — | `200 {"db":"ok","storage":"ok"}` or `503 {"db":"fail","storage":"ok"}` |
| `GET /v1/server-info` | — | `200 {"name":"Tephra Cloud","apiVersion":1,"serverVersion":"2.0.0","signupEnabled":true,"inviteRequired":false,"emailVerificationRequired":true,"limits":{"freeStorageBytes":1073741824,"maxObjectBytes":16777216,"maxVaults":3,"maxDevices":5},"termsVersion":"2026-12-01","termsUrl":"https://…/legal/terms","privacyUrl":"https://…/legal/privacy"}` |
| `GET /verify?token=…` | — | HTML page "Email confirmed" / "Link expired" (also marks the email verified) |
| `GET /reset?token=…`, `POST /reset` (form) | HTML form → posts `token`, `password` | HTML result page (same effect as `reset-password`) |
| `GET /legal/terms`, `GET /legal/privacy`, `GET /` | — | static HTML pages |

### Auth

| Method + path | Request JSON | Success response |
|---|---|---|
| `POST /v1/auth/signup` | `{"email":"a@b.c","password":"…≥10 chars…","deviceId":"<uuid v4>","deviceName":"Pixel 8","platform":"android","acceptedTermsVersion":"2026-12-01","inviteCode":"…"?}` | `201` Session (below) + `"emailVerificationRequired":true` |
| `POST /v1/auth/login` | `{"email","password","deviceId","deviceName","platform"}` | `200` Session |
| `POST /v1/auth/refresh` | `{"refreshToken":"…"}` | `200` Session (new access **and** new refresh token) |
| `POST /v1/auth/logout` (auth) | `{}` | `204` (revokes the current session) |
| `POST /v1/auth/verify-email` | `{"token":"…"}` | `204` |
| `POST /v1/auth/resend-verification` (auth) | `{}` | `204` (max 3 per hour) |
| `POST /v1/auth/forgot-password` | `{"email":"a@b.c"}` | `202` always (never reveals whether the account exists) |
| `POST /v1/auth/reset-password` | `{"token":"…","newPassword":"…"}` | `204` (revokes **all** sessions of the user) |
| `POST /v1/auth/change-password` (auth) | `{"oldPassword","newPassword"}` | `204` (revokes all **other** sessions) |

**Session object:**
```json
{
  "serverTime": "2026-10-11T09:30:00.000Z",
  "accessToken": "<jwt>", "accessExpiresAt": "2026-10-11T09:45:00.000Z",
  "refreshToken": "<opaque 43-char base64url>", "refreshExpiresAt": "2026-11-10T09:30:00.000Z",
  "user": { "id": "<uuid>", "email": "a@b.c", "emailVerified": false, "plan": "free", "createdAt": "…", "deletionScheduledAt": null },
  "device": { "deviceId": "<uuid>", "name": "Pixel 8", "platform": "android" }
}
```
Access token claims: `iss:"tephra-cloud"`, `sub:<userId>`, `sid:<sessionId>`, `did:<deviceId>`, `iat`, `exp` (= iat + 15 min), `jti`, header `typ:"at+jwt"`, `alg:"HS256"`.
Refresh tokens: 32 random bytes, base64url, **stored only as SHA-256** (`refresh_hash`), lifetime 30 days sliding (each rotation extends it).

### Account, devices, quota

| Method + path | Request | Response |
|---|---|---|
| `GET /v1/me` | — | `200` `{"id","email","emailVerified","plan","createdAt","deletionScheduledAt":null}` |
| `DELETE /v1/me` | `{"password":"…"}` | `202 {"deletionScheduledAt":"…"}` (see 10.11; revokes all sessions except this one) |
| `POST /v1/me/cancel-deletion` | `{}` | `204` |
| `GET /v1/me/quota` | — | `200 {"usedBytes":123456,"limitBytes":1073741824,"objectCount":5678,"plan":"free","vaults":[{"id":"<uuid>","name":"My Vault","usedBytes":123456,"objectCount":5678}],"trashBytes":0}` — used by `SyncProvider.quota()` (`usedBytes`, `limitBytes`) |
| `GET /v1/me/devices` | — | `200 {"devices":[{"deviceId","name","platform","createdAt","lastSeenAt","current":true}]}` |
| `PATCH /v1/me/devices/current` | `{"deviceId":"<new uuid>"?,"deviceName":"…"?}` | `200` device (used after a clone-detect device-id renewal, 03.7) |
| `DELETE /v1/me/devices/{deviceId}` | — | `204` (revokes that device's sessions; the **client** also writes the Phase 3 revocation file) |

### Vaults and objects (the SyncProvider mapping)

`{vaultId}` is the **remote vault id** from `vault.json` (lower-case UUID v4); the vault belongs to exactly one account (`403 not_your_vault` / `404 vault_not_found` otherwise).

| Method + path | Request | Response |
|---|---|---|
| `POST /v1/vaults` | `{"id":"<uuid>","name":"My Vault"}` | `201 {"id","name","createdAt"}`; `409 vault_exists` if the id exists (same account: idempotent → `200`); `403 vault_limit` |
| `GET /v1/vaults` | — | `200 {"vaults":[{"id","name","createdAt","usedBytes","objectCount"}]}` |
| `GET /v1/vaults/{vaultId}` | — | `200` one vault (same shape) — `connect()` uses it |
| `DELETE /v1/vaults/{vaultId}` | `{"password":"…"}` | `204` (soft-deletes everything; purged by the retention job) |
| `GET /v1/vaults/{vaultId}/objects/{key}` | — | `200` raw bytes; headers `ETag: "<sha256 hex of the stored bytes>"`, `X-Tephra-Created`, `X-Tephra-Modified`, `Content-Length`; `404 not_found` |
| `HEAD /v1/vaults/{vaultId}/objects/{key}` | — | `200`/`404` with the same headers, no body |
| `PUT /v1/vaults/{vaultId}/objects/{key}` | raw bytes (may be empty); optional header `X-Tephra-Sha256: <hex>` | `200 {"key","size","created","modified","sha256"}` (`201` when newly created). Server rules below |
| `DELETE /v1/vaults/{vaultId}/objects/{key}` | — | `204` always (missing key = no-op, matches `SyncProvider.delete`) |
| `GET /v1/vaults/{vaultId}/objects?prefix=&limit=1000&after=` | — | `200 {"objects":[{"key","size","modified","created"}],"nextAfter":"<last key>"|null}` — ascending by key (byte order), string prefix (not folder-only), `limit` ≤ 5,000; `after` = exclusive lower bound |
| `GET /v1/vaults/{vaultId}/changes?cursor=&limit=5000` | — | `200 {"changedKeys":[…],"removedKeys":[…],"cursor":"<opaque>","cursorWasReset":false,"hasMore":false}` |
| `GET /v1/vaults/{vaultId}/events` (WebSocket upgrade) | `Authorization` header (or `?token=` query for clients that cannot set headers) | server→client JSON text frames below |

**Object key rules (server-enforced, same as the `SyncProvider` contract):** 1–512 chars from `[A-Za-z0-9._/-]`, no leading/trailing `/`, no `//`, no `.`/`..` segment → else `400 invalid_key`. The key must parse as a known `RemoteKey` (03.2: `vault.json`, `blobs/<64 hex>`, `journals/<uuid>/<10 digits>.json.enc`, `snapshots/…`, `backups/<stamp>/manifest.json.enc`, `devices/<uuid>.json.enc`, `devices/<uuid>.revoked.json.enc`, `locks/gc-<uuid>.json.enc`, `locks/gc-state.json.enc`) unless `ALLOW_UNKNOWN_KEYS=true` → else `400 unknown_key` (the server is released together with the format; this stops abuse as free file hosting).
**PUT rules:** (1) `Content-Length` (or streamed bytes) ≤ `MAX_OBJECT_BYTES` (default 16 MiB) → else `413 too_large`; (2) if `X-Tephra-Sha256` is present it must equal the SHA-256 of the received body → else `422 checksum_mismatch`; (3) for `blobs/<hash>` the SHA-256 of the body **must equal `<hash>`** (the hash is of the stored bytes, 03.2) → else `422 blob_hash_mismatch`; an existing blob with the same key is a no-op `200` (immutable, content-addressed); (4) **immutable classes** — journals, snapshots, backup manifests, device revocation files: an existing key with **identical bytes** → `200` (idempotent re-put by `JournalWriter.recover()`); with **different bytes** → `409 immutable_key`; (5) **mutable classes** — `vault.json`, `devices/<id>.json.enc`, `locks/*`: replace; (6) quota: `usedBytes − oldSize + newSize > limit` → `507 quota_exceeded` (checked from `Content-Length` before reading the body, and again after); (7) email must be verified when `EMAIL_VERIFICATION_REQUIRED=true`, else `403 email_not_verified`. `vault.json` replacements keep the previous 10 versions in a server-side `header_versions` table (recovery from a bad password change).
**Changes:** the cursor is opaque to clients (`"v1.<epoch>.<seq>"`, epoch = 8 hex chars that change whenever the server is restored from a backup, see 10.9). `cursor` absent → `{"changedKeys":[],"removedKeys":[],"cursor":"v1.<epoch>.<currentSeq>","cursorWasReset":false,"hasMore":false}` (the start token, `SyncProvider.changesSince(null)`). A cursor that is malformed, has a different epoch, is greater than the current sequence, or older than the retained change log (`CHANGELOG_KEEP_DAYS`, default 30) → `200` with `cursorWasReset:true`, empty lists and a fresh cursor (the client then does a full `list`). A key put then deleted appears in both lists (allowed by the contract). `hasMore:true` → call again with the returned cursor.

**WebSocket events** (server → client; the client sends nothing except WS pong/close; the server pings every 20 s and drops dead peers after 60 s):
```json
{ "type": "hello", "cursor": "v1.3fa9c2d1.1204", "serverTime": "2026-10-11T09:30:00.000Z" }
{ "type": "changed", "cursor": "v1.3fa9c2d1.1210", "keys": ["journals/<deviceId>/0000000042.json.enc"], "removed": [], "overflow": false }
{ "type": "bye", "reason": "session_revoked" | "shutting_down" | "vault_deleted" }
```
`changed` frames are batched (≤ 100 ms or ≤ 200 keys; beyond that the frame has empty `keys`/`removed` and `"overflow":true`, meaning "run `changesSince`"), contain the vault's changes caused by **any** device (the client ignores its own keys), and never contain object content. The server closes with code 4401 on `session_revoked` and 1001 on shutdown. After every (re)connect the client runs `changesSince(storedCursor)` to catch up; the `hello` cursor is only informational.

---

## Steps

Every step has: **Purpose**, **Files**, **Implementation**, **Tests**, **Verify**, **Pitfalls**. "Verify" always also means:

```
dart format --output=none --set-exit-if-changed app/lib app/test packages server tool
flutter analyze --fatal-infos
```

plus `dart test` in every package you touched (run from the package folder, including `server/`) and `flutter test --exclude-tags golden` in `app/` if you touched the app.
(Step 10.1 adds `server` to the format command in `ci.yml`; GEMINI.md itself is not edited — run the extended command by hand in this phase.) Every new Dart file starts with `// © 2026 Tephra. All rights reserved.`; every public type/member in packages and in `server/lib` has a `///` comment.
Logger names: `server.http`, `server.auth`, `server.db`, `server.storage`, `server.ws`, `server.jobs`, `server.mail`, `server.admin`, `sync.cloud`.
**Never log** passwords, tokens (access/refresh/email/reset), recovery data, request bodies, or object contents. Object keys may be logged at `fine` level only. Passwords and tokens never appear in error messages.

---

### 10.1 — `server/` package skeleton, workspace, dependencies, shared key validation

**Purpose.** A compiling server package inside the pub workspace with the dependency rules of conventions §3 (`server ← core, sync`).

**Files.** `server/pubspec.yaml`, `server/README.md`, `server/bin/tephra_server.dart`, `server/bin/tephra_admin.dart`, `server/lib/tephra_server.dart` (library doc + `export` lines only), `server/lib/src/` (folders created by later steps), `server/analysis_options.yaml` (`include: ../analysis_options.yaml`), root `pubspec.yaml` (edit: add `server` to `workspace:`), `.github/workflows/ci.yml` (edit), `deploy/pubspec.docker.yaml` (see 10.19), `packages/tephra_sync/lib/src/remote/remote_key_validation.dart` (+ export), its test.

**Implementation.**
1. `server/pubspec.yaml`: `name: tephra_server`, `description: "Tephra Cloud server: accounts, encrypted object storage and push for Tephra sync."`, `publish_to: none`, `resolution: workspace`, `environment: sdk: ^3.13.0`; dependencies `tephra_core`, `tephra_sync` (workspace deps exactly as other packages reference each other), then `dart pub add shelf shelf_router shelf_web_socket web_socket_channel sqlite3 cryptography dart_jsonwebtoken mailer minio yaml args uuid logging path crypto collection http` (inside `server/`); dev: `test`. `executables:` map `tephra_server: tephra_server` and `tephra_admin: tephra_admin`. Add `server` to the root `workspace:` list. Run `flutter pub get` at the repo root. **Check** the dependency rule: `server/` imports only `tephra_core`, `tephra_sync` and external packages (a unit test in `tool/test/dependency_rules_test.dart` — extend the Phase 0 rules test if present — asserts no other `package:tephra_*` import, and no `package:flutter` anywhere in `server/`).
2. `tephra_sync`: add `bool isValidRemoteKey(String key)` and `void checkRemoteKey(String key)` (throws `ArgumentError`) in `remote_key_validation.dart` implementing the key rules of 03.2 (so provider, memory provider, Drive provider and server share **one** implementation — refactor `MemorySyncProvider` and `DriveSyncProvider` to call it; their tests must still pass). Export from `lib/tephra_sync.dart`. Tests: the 5 invalid examples of 03.2 item 6.10 plus length 512/513, unicode, uppercase, trailing dot segments.
3. `server/README.md` with `## Install` (`flutter pub get` at the repo root) and `## Run` (fenced: `dart run bin/tephra_server.dart` after `cd server`), env table pointer to `docs/ops/`.
4. `ci.yml`: add a job `server` (ubuntu): checkout, `subosito/flutter-action` 3.47.7, `flutter pub get`, `sudo apt-get update && sudo apt-get install -y libsqlite3-dev` (if the sqlite3 package needs it), `cd server && dart test`. Update every `dart format … app/lib app/test packages tool` occurrence in CI and docs to include `server`.
5. `server/bin/tephra_server.dart` and `tephra_admin.dart` start as `void main(List<String> args) { /* wired in 10.2 / 10.12 */ }`.

**Tests.** The key-validation tests; the dependency-rule test; `dart test` in `server/` runs (empty suite passes with a placeholder smoke test `expect(1, 1)` removed in 10.2).

**Verify.** `flutter pub get`, `dart analyze server`, `dart run tool/check_licenses.dart`.

**Pitfalls.** The workspace root lists the Flutter `app`; `dart pub get` inside Docker cannot resolve it — that is why `deploy/pubspec.docker.yaml` exists (10.19). Do not import `package:tephra_vault` in the server (not allowed by §3 and unnecessary).

---

### 10.2 — Configuration, logging, process lifecycle, `/health`, Dev Launcher

**Purpose.** A server process that starts from env/file config, logs structured JSON, shuts down gracefully, and runs from Dev Launcher.

**Files.** `server/lib/src/config/server_config.dart`, `config_loader.dart`, `server/lib/src/logging/json_logger.dart`, `server/lib/src/app/server_app.dart` (builds the shelf pipeline), `server/lib/src/app/lifecycle.dart`, `server/lib/src/api/health_handler.dart`, `server/lib/src/api/server_info_handler.dart`, `server/lib/src/net/local_addresses.dart`, `server/bin/tephra_server.dart`, tests `server/test/config_test.dart`, `lifecycle_test.dart`, `health_test.dart`, `server/test/support/test_server.dart`, `config.example.yaml`.

**Implementation.**
1. **Config sources and precedence:** defaults < YAML file (path from `--config <file>` or env `TEPHRA_CONFIG`; optional) < environment variables. Every key has an env name; the table below is the complete list (type, default, meaning). `ServerConfig` is immutable with `fromMap`, validation (`ConfigException` listing **all** problems at once), and a `redacted()` map for logging (secrets shown as `***`).

   | Env / YAML key | Default | Meaning |
   |---|---|---|
   | `PORT` / `port` | `8094` | listen port |
   | `HOST` / `host` | `0.0.0.0` | bind address |
   | `TEPHRA_ENV` / `env` | `production` | `dev`, `staging`, `production` (dev: auto-generates and persists `JWT_SECRET`, `EMAIL_MODE=log`, `EMAIL_VERIFICATION_REQUIRED=false`, data dir `./.data`) |
   | `PUBLIC_URL` / `publicUrl` | (required in non-dev) | externally visible origin, used in emails and `server-info` |
   | `DATA_DIR` / `dataDir` | `/data` (dev: `./.data`) | SQLite file `tephra.sqlite`, `tmp/`, local blobs `blobs/` |
   | `JWT_SECRET` / `jwtSecret` | (required in non-dev; ≥ 32 bytes, base64 or hex) | HS256 signing key |
   | `JWT_SECRET_PREVIOUS` / `jwtSecretPrevious` | empty | accepted for verification only (rotation) |
   | `ACCESS_TOKEN_MINUTES` | `15` | access token lifetime |
   | `REFRESH_TOKEN_DAYS` | `30` | refresh lifetime (sliding) |
   | `REFRESH_GRACE_SECONDS` | `30` | concurrent-refresh grace (10.5) |
   | `SIGNUP_ENABLED` | `true` | open sign-up |
   | `SIGNUP_INVITE_CODE` | empty | if set, sign-up requires it |
   | `ALLOWED_EMAIL_DOMAINS` | empty | comma list; empty = any |
   | `EMAIL_VERIFICATION_REQUIRED` | `true` (dev `false`) | block uploads until verified |
   | `EMAIL_MODE` | `smtp` (dev `log`) | `smtp`, `log` (prints links to stdout — dev only), `memory` (tests) |
   | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`, `SMTP_SECURITY` (`starttls`\|`ssl`\|`none`) | — / `587` / — / — / — / `starttls` | outgoing mail |
   | `STORAGE_BACKEND` | `local` | `local` or `s3` |
   | `S3_ENDPOINT`, `S3_PORT`, `S3_USE_SSL`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_PATH_STYLE`, `S3_PREFIX` | — | S3 settings (when `s3`) |
   | `PLAN_FREE_STORAGE_BYTES` | `1073741824` | free storage |
   | `PLAN_FREE_MAX_VAULTS`, `PLAN_FREE_MAX_DEVICES` | `3`, `5` | limits |
   | `MAX_OBJECT_BYTES` | `16777216` | max PUT body |
   | `MAX_JSON_BYTES` | `65536` | max JSON body |
   | `MAX_CONCURRENT_UPLOADS` | `32` | semaphore |
   | `ALLOW_UNKNOWN_KEYS` | `false` | accept non-format keys |
   | `TRASH_RETENTION_DAYS` | `30` | soft-delete retention |
   | `CHANGELOG_KEEP_DAYS` | `30` | change-log retention |
   | `ACCOUNT_DELETION_GRACE_DAYS` | `7` | delay before hard deletion |
   | `RATE_LIMITS` | see 10.10 | optional YAML map only |
   | `TRUST_PROXY` | `false` (compose sets `true`) | use `X-Forwarded-For` (last hop appended by Caddy) |
   | `METRICS_TOKEN` | empty | enables `/metrics` with `Authorization: Bearer <token>` |
   | `LOG_LEVEL` | `info` | `fine`..`severe` |
   | `LOG_FILE`, `LOG_KEEP_FILES` | empty, `14` | also write JSON logs to a daily-rotated file (10.21) |
   | `CLIENT_IP_HEADER` | empty | with `TRUST_PROXY=true`: header holding the client IP (for example `CF-Connecting-IP`); otherwise the last `X-Forwarded-For` value (10.10, 10.21) |
   | `SHUTDOWN_GRACE_SECONDS` | `20` | graceful-stop window |
   | `TERMS_VERSION`, `TERMS_URL`, `PRIVACY_URL` | built-in | legal metadata in `server-info` |

   Non-dev startup **refuses** (exit code 2, clear message) if `PUBLIC_URL` or `JWT_SECRET` is missing/weak, `EMAIL_MODE=log`, or `ALLOW_UNKNOWN_KEYS=true` with `TEPHRA_ENV=production` unless `--i-know` is passed.
2. **Logging:** a `Logger.root.onRecord` listener writing **one JSON line per record to stdout**: `{"ts":"…","level":"INFO","logger":"server.http","msg":"…","requestId":"…","userId":"…"?, …fields}`; errors with `error` and `stack` (stack only at `severe`). Request logging middleware (10.8) emits `{"msg":"request","method","route":"/v1/vaults/{id}/objects/{key}","status","ms","bytesIn","bytesOut","userId"?}` — the **route template**, not the raw path with ids. IP addresses are **not** logged except in `audit` entries of auth events (kept 14 days, 10.11).
3. **Startup banner** (printed with `print`-equivalent via the logger **and** plain stdout, since Dev Launcher parses it): `Local: http://localhost:<PORT>/` and `Network: http://<lan-ip>:<PORT>/` (every non-loopback IPv4 from `NetworkInterface.list`), then `Tephra Cloud server <version> started (env=<env>, storage=<backend>)`. In `production` the Network line is still printed (harmless).
4. **Lifecycle:** `ServerApp.start()` opens DB (10.3), storage (10.4), creates the router, binds `HttpServer.bind(host, port, shared: false)`, starts jobs (10.11), registers signal handlers (`ProcessSignal.sigint` always; `sigterm` in a try/catch because Windows does not support it). `stop()`: mark `shuttingDown` (new requests get `503 shutting_down` + `Retry-After: 5`, except `/health`), send `bye(shutting_down)` and close all WebSockets with 1001, `server.close()` (no force), wait up to `SHUTDOWN_GRACE_SECONDS` for in-flight requests, stop jobs, `PRAGMA wal_checkpoint(TRUNCATE)`, close DB, exit 0. A second signal forces exit 1.
5. `GET /health` (no DB) and `GET /v1/server-info` (DB-free; values from config). The binary also accepts `--healthcheck` (performs `GET http://127.0.0.1:$PORT/health`, exits 0 on 200 else 1; used by the Docker `HEALTHCHECK`, 10.19) and `--config <file>`, `--version`.
6. **Dev Launcher (the human's standing rule, conventions §11):** (a) `server/README.md` `## Run` shows `cd server` + `dart run bin/tephra_server.dart` and states `PORT` (default 8094, **not** 8092); the root `README.md` `## Run` gets a second fenced block titled "Tephra Cloud server (Phase 10)" with the same two lines; (b) register it as a **second process of the existing project** "Tephra (Gemini build)": `POST http://127.0.0.1:7799/api/inspect` with `{ "path": "D:\\script\\tephra-gemini" }`, read the proposal; if it does not list the server as a process, **edit the proposal** (add a process: label `server`, folder `server`, command `dart run bin/tephra_server.dart`, port `8094`, port env var `PORT`) following the exact shape of the other process in the response; then update the project through the launcher's API for projects (look at `D:\script\dev-launcher` routes with `Grep "api/projects"`; use the update/replace route, **never edit `projects.json`**) with `autoStart: false`; start the server process with `POST /api/projects/<id>/start` (and the process label if the API takes one) and read `GET /api/logs/<id>/server` — the log must show the `Local:`/`Network:` lines. Record the commands and responses in `PROGRESS.md`. Ports to avoid: 3000, 4000, 5432, 5433, 8000, 8765, 8800, 7799, 7800, 8091, 8092, 8093 (the app preview).
7. `TestServer` (test support): `static Future<TestServer> start({Clock? clock, Map<String,String> env = const {}})` builds a `ServerApp` with an **in-memory SQLite** (or a temp file), a temp-dir `LocalBlobStorage`, `EMAIL_MODE=memory` (exposes `sentEmails`), `HOST=127.0.0.1`, `PORT=0`, `TEPHRA_ENV=dev` overrides; exposes `Uri baseUrl`, `Future<void> stop()`, `Clock` injection (a `FakeClock` the tests advance; **every** server time source uses the injected `Clock`).

**Tests.** Config: precedence (default < file < env), every validation error aggregated, `redacted()` hides secrets, dev defaults, production refusals. Lifecycle: start/stop on port 0; `/health` 200 during shutdown but other routes 503; in-flight request completes within grace; WebSocket closed with 1001. Banner lines match the regex Dev Launcher uses (`Local: http://localhost:\d+/`). Health/server-info bodies.

**Verify.** `cd server; dart test`. Manual: start via Dev Launcher, `curl http://localhost:8094/health`, stop from the panel (graceful exit 0 in the log).

**Pitfalls.** Never print secrets in the config log. Never read env at call sites — only `ServerConfig` does. `HttpServer.bind` with `shared: false` avoids two instances silently sharing a port.

---

### 10.3 — Database: schema, migrations, data access layer

**Purpose.** All metadata in one SQLite database with versioned migrations and a small typed DAO layer (no ORM).

**Files.** `server/lib/src/db/database.dart` (open, pragmas, migrations), `server/lib/src/db/migrations/m001_initial.dart`, `server/lib/src/db/dao/users_dao.dart`, `sessions_dao.dart`, `email_tokens_dao.dart`, `vaults_dao.dart`, `objects_dao.dart`, `changes_dao.dart`, `audit_dao.dart`, `meta_dao.dart`, `server/lib/src/db/models.dart`, tests `server/test/db/*_test.dart`.

**Implementation.**
1. Open `<DATA_DIR>/tephra.sqlite` with `sqlite3.open`; pragmas on every connection: `journal_mode=WAL`, `synchronous=FULL` (durability beats speed here), `foreign_keys=ON`, `busy_timeout=5000`, `wal_autocheckpoint=1000`. **One writer connection** guarded by an async mutex (a `Lock` class, FIFO) + a small pool (default 4) of read-only connections for GETs (`open(…, mode: OpenMode.readOnly)`); the admin CLI opens its own connection (WAL allows it). All SQL is parameterised (`?`), never string-concatenated with input.
2. **Migrations:** `meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)` holds `schema_version`. `Migration { int version; List<String> statements }`; the runner applies pending ones in a transaction each, records the version, and **refuses to start** if the DB's version is higher than the code's. Back up before migrating (copy the file to `<DATA_DIR>/backups/pre-migrate-<ts>.sqlite` via `VACUUM INTO`) when pending migrations exist on a non-empty DB.
3. **Schema v1 (`m001_initial`)** — exact tables (times are INTEGER milliseconds since epoch UTC; ids are lower-case UUID text; `email_lc` is the lower-cased trimmed email):

   | Table | Columns | Indexes / notes |
   |---|---|---|
   | `users` | `id TEXT PK`, `email TEXT NOT NULL`, `email_lc TEXT NOT NULL UNIQUE`, `password_hash TEXT NOT NULL` (PHC string), `email_verified_at INTEGER NULL`, `plan TEXT NOT NULL DEFAULT 'free'`, `quota_override_bytes INTEGER NULL`, `created_at INTEGER NOT NULL`, `last_login_at INTEGER NULL`, `disabled_at INTEGER NULL`, `deletion_requested_at INTEGER NULL`, `terms_version TEXT NOT NULL`, `terms_accepted_at INTEGER NOT NULL` | |
   | `sessions` | `id TEXT PK`, `user_id TEXT NOT NULL → users ON DELETE CASCADE`, `device_id TEXT NOT NULL`, `device_name TEXT NOT NULL`, `platform TEXT NOT NULL`, `created_at`, `last_seen_at`, `refresh_hash TEXT NOT NULL` (current), `prev_refresh_hash TEXT NULL`, `rotated_at INTEGER NOT NULL`, `refresh_expires_at INTEGER NOT NULL`, `revoked_at INTEGER NULL`, `revoke_reason TEXT NULL` | unique `refresh_hash`; index `(user_id, device_id)`; index `prev_refresh_hash` |
   | `email_tokens` | `id TEXT PK`, `user_id → users CASCADE`, `kind TEXT` (`verify`\|`reset`), `token_hash TEXT NOT NULL UNIQUE`, `expires_at`, `used_at NULL`, `created_at` | |
   | `vaults` | `id TEXT PK`, `user_id → users CASCADE`, `name TEXT NOT NULL`, `created_at`, `deleted_at INTEGER NULL`, `used_bytes INTEGER NOT NULL DEFAULT 0`, `object_count INTEGER NOT NULL DEFAULT 0`, `min_change_seq INTEGER NOT NULL DEFAULT 0` | index `user_id` |
   | `objects` | `vault_id → vaults CASCADE`, `key TEXT NOT NULL`, `size INTEGER NOT NULL`, `sha256 TEXT NOT NULL`, `storage_ref TEXT NOT NULL`, `created_at`, `modified_at`, `deleted_at INTEGER NULL`, PK `(vault_id, key)` | `WITHOUT ROWID`; index `(vault_id, deleted_at)`; key compared with BINARY collation (the default) so `ORDER BY key` equals Dart string order for the ASCII charset |
   | `header_versions` | `vault_id`, `version INTEGER`, `size`, `sha256`, `storage_ref`, `created_at`, PK `(vault_id, version)` | last 10 per vault |
   | `changes` | `seq INTEGER PRIMARY KEY AUTOINCREMENT`, `vault_id TEXT NOT NULL`, `key TEXT NOT NULL`, `removed INTEGER NOT NULL`, `at INTEGER NOT NULL` | index `(vault_id, seq)` |
   | `audit` | `id INTEGER PK AUTOINCREMENT`, `at`, `user_id NULL`, `event TEXT`, `detail TEXT NULL` (small JSON, no secrets), `ip TEXT NULL` | `ip` set to NULL after 14 days (10.11); rows deleted after 180 days |
   | `meta` | `key`, `value` | `schema_version`, `server_id` (random uuid on first start) |

4. **DAO contracts** (each method is `async`, throws `StateError` only for programmer errors; every write returns the new row): `UsersDao.create/findByEmail/findById/setVerified/setPasswordHash/setPlan/setQuotaOverride/disable/requestDeletion/cancelDeletion/touchLogin/delete`; `SessionsDao.create/findById/findByRefreshHash/rotate/revoke/revokeAllForUser/revokeAllExcept/listForUser/countDevices/touch/deleteExpired`; `EmailTokensDao.create/consume/purgeExpired`; `VaultsDao.create/find/listForUser/rename/softDelete/adjustUsage(vaultId, deltaBytes, deltaCount)`; `ObjectsDao.get(vaultId,key,{includeDeleted})/upsert/softDelete/list(vaultId,prefix,after,limit)/sumLiveBytes(userId)/purgeDeletedBefore(ts)/listDeleted`; `ChangesDao.append(vaultId,key,removed)/since(vaultId,seq,limit)/currentSeq()/trimBefore(ts, perVault)`; `AuditDao.record/purge`. **Atomicity rule:** a PUT/DELETE commit performs `objects` upsert + `vaults` usage update + `changes` append in **one transaction** (`ObjectsRepository.commitPut/commitDelete` helpers) so counters never drift; `verify-storage` (10.12) recomputes counters and the admin `repair-counters` fixes them.
5. `list` SQL: `SELECT key,size,modified_at,created_at FROM objects WHERE vault_id=? AND deleted_at IS NULL AND key >= ? AND key < ? AND key > ? ORDER BY key LIMIT ?` using the prefix range `[prefix, prefix + '\u{10FFFF}')` (prefix `''` = everything) and `after` (exclusive; use `''` when absent and skip the clause).

**Tests.** Fresh DB creates all tables and `schema_version=1`; migration runner idempotent; a higher version refuses to start; each DAO round trip; uniqueness (`email_lc`, refresh hash); cascade delete removes sessions/vaults/objects/tokens; transaction rollback leaves counters unchanged; `list` ordering/prefix/after/limit property test against an in-Dart reference (500 random ASCII keys, 200 random queries); concurrent writes (50 parallel `commitPut`) keep `used_bytes`/`object_count` equal to the real sums; pre-migrate backup file created.

**Verify.** `dart test test/db`.

**Pitfalls.** SQLite does not enforce foreign keys unless the pragma is set **per connection**. A read-only pooled connection must not be used inside a write transaction. Never use `AUTOINCREMENT` ids from clients. Keep `key` BINARY collation — do not add `COLLATE NOCASE`.

---

### 10.4 — Blob storage backends (local disk and S3-compatible)

**Purpose.** Store object bytes outside SQLite behind one interface; crash-safe; verified.

**Files.** `server/lib/src/storage/blob_storage.dart` (interface), `local_blob_storage.dart`, `s3_blob_storage.dart`, `storage_factory.dart`, `server/lib/src/storage/upload_spool.dart`, tests `server/test/storage/*_test.dart` (shared contract `blob_storage_contract.dart`), `server/test/storage/s3_blob_storage_test.dart` (tag `s3`).

**Implementation.**
1. Interface:
   ```dart
   abstract interface class BlobStorage {
     String get kind;                                                   // 'local' | 's3'
     Future<String> put(String vaultId, File source, int size);         // returns an opaque storageRef; durable when it returns
     Stream<List<int>> open(String storageRef, {int? start, int? end});
     Future<void> delete(String storageRef);                            // missing = no-op
     Future<bool> exists(String storageRef);
     Future<void> checkReady();                                         // used by /ready; throws on failure
     Stream<String> listRefs(String vaultId);                           // for verify-storage / orphan sweep
   }
   ```
   `storageRef` is `<vaultId>/<aa>/<uuid>` where `uuid` is a **new random UUID per stored version** (never derived from the key; no user-controlled string ever becomes a path), `aa` = first two hex chars of the uuid.
2. **`LocalBlobStorage(Directory root)`:** `put`: create `<root>/<vaultId>/<aa>/` if needed; move (or copy) the spooled temp file to `<ref>.tmp` on the **same filesystem**, `RandomAccessFile.flush`+`flushSync` of the file, `rename` to `<ref>` (atomic), then fsync the directory where the platform allows (Linux: open the directory read-only and call `fsync` via `RandomAccessFile.flush` on it is not possible in Dart — acceptable: document; rename atomicity + WAL DB ordering is the safety argument, see Pitfalls). `open` streams the file with `openRead`. `delete` ignores `PathNotFoundException`. A start-up sweep removes `*.tmp` files older than 1 hour. `checkReady` writes and deletes a probe file.
3. **`S3BlobStorage` (package `minio`):** `Minio(endPoint, port, useSSL, accessKey, secretKey, region, pathStyle?)`; object name `<prefix><storageRef>`; `put` uses `minio.putObject(bucket, name, stream, size: size)` from the spooled file; `open` uses `getObject`/`getPartialObject`; `delete` `removeObject`; `listRefs` `listObjectsV2`; `checkReady` → `bucketExists`. Re-read the package README for the current API (named parameters change between versions). Server-side encryption is not requested (the data is already end-to-end encrypted). Retries: 3 attempts with 200 ms/400 ms/800 ms backoff for 5xx/network errors.
4. **`UploadSpool`:** the PUT handler streams the request body into `<DATA_DIR>/tmp/<uuid>.upload` while computing SHA-256 incrementally and counting bytes; aborts (and deletes the file) as soon as the count exceeds `MAX_OBJECT_BYTES` or the client disconnects. The spool is the only place request bodies touch the disk; `tmp/` is swept on start-up (files older than 10 minutes).
5. **Selection** by `STORAGE_BACKEND`. v2.0 production uses `local` (decision); `s3` is supported and tested but not required for the gate.

**Tests.** One shared contract run against both backends: put/open round trip (0 B, 1 B, 5 MiB), ranged open, delete idempotent, exists, `listRefs`, concurrent puts; local-only: no `*.tmp` left after an injected failure between write and rename, start-up sweep, path-traversal impossible (a `vaultId` containing `..` is rejected by `checkUuid` before it reaches the filesystem), disk-full simulated with a failing spool/storage (the PUT returns `503 unavailable` with message "storage full", **and the DB is unchanged**; the user quota code `507` is only for quota); S3 tests run only when `TEPHRA_S3_TEST_ENDPOINT`, `TEPHRA_S3_TEST_PORT`, `TEPHRA_S3_TEST_USE_SSL` are set (CI job `server-s3` runs `docker run -d -p 9090:9090 adobe/s3mock` and sets them; **no MinIO server**).

**Verify.** `dart test test/storage`; optionally `docker run --rm -d -p 9090:9090 -e initialBuckets=tephra-test adobe/s3mock` then `$env:TEPHRA_S3_TEST_ENDPOINT='localhost'; $env:TEPHRA_S3_TEST_PORT='9090'; $env:TEPHRA_S3_TEST_USE_SSL='false'; dart test -t s3`.

**Pitfalls.** DB commit **after** the blob is durable, and delete the old blob **after** the DB commit: a crash then leaves at worst an orphan file (collected by the orphan sweep, 10.11), never a DB row pointing at nothing. Never build a filesystem path from a key or a user-provided id; only from validated UUIDs.

---

### 10.5 — Passwords, access tokens, sessions, refresh rotation

**Purpose.** The security core of the server, with exact parameters.

**Files.** `server/lib/src/auth/password_hasher.dart`, `password_policy.dart`, `jwt_service.dart`, `session_service.dart`, `auth_context.dart`, `token_codec.dart`, `server/lib/src/auth/hash_pool.dart`, tests `server/test/auth/*_test.dart`.

**Implementation.**
1. **Password hashing — Argon2id** via `package:cryptography` (`Argon2id(parallelism: 1, memory: 19456, iterations: 2, hashLength: 32)`; memory is in KiB = **19 MiB**, the OWASP minimum recommendation; configurable only upward in code constants). PHC string stored: `$argon2id$v=19$m=19456,t=2,p=1$<salt b64 no padding>$<hash b64 no padding>`, salt = 16 random bytes (`Random.secure()`). Verification parses the PHC string, recomputes with its own parameters, compares in **constant time** (XOR-accumulate over bytes). `needsRehash(phc)` is true when parameters are below the current constants → `login` rehashes and stores the new PHC after a successful verify.
   **Execution:** hashing runs off the main isolate: `HashPool` with 4 worker `Isolate.run` slots (semaphore); if all slots are busy, requests wait up to 5 s then get `503 unavailable` (back-pressure instead of a memory spike). **Measure** one hash on the dev PC and record it in `docs/ops/capacity.md` (expect 0.1–0.6 s in pure Dart; if > 1.0 s, stop and report to the human: options are lowering to `m=12288,t=3` (still OWASP-acceptable) or an FFI implementation — **do not decide alone**).
   **Unknown-user timing:** `login` with an unknown email verifies the password against a fixed dummy PHC (same cost) so response time does not reveal account existence.
2. **Password policy:** length 10–256 characters (Unicode code points), must not equal the email or its local part (case-insensitive), must not be in a built-in list of the 100 most common passwords (`password_policy.dart` constant list: write the 100 yourself from general knowledge, lower-cased, ≥ 10 chars only matter) → `400 weak_password` with a machine-readable `reason` (`too_short`, `too_long`, `common`, `same_as_email`). No composition rules (length matters; NIST 800-63B). Passwords are used exactly as typed (no trimming/normalisation), same as vault passwords (03.4).
3. **Access token** (`JwtService`, `dart_jsonwebtoken`): HS256, claims exactly as in the API section, `exp = now + ACCESS_TOKEN_MINUTES`. Verification accepts `JWT_SECRET` or `JWT_SECRET_PREVIOUS`, requires `iss == 'tephra-cloud'`, `typ == 'at+jwt'`, a non-expired `exp` (clock from the injected `Clock`, leeway 30 s), and **rejects `alg: none`** and any other `alg`. After the signature check, `SessionService.authenticate(claims)` loads the session (in-memory LRU cache of 1,000 entries, TTL **5 s**) and rejects if `revoked_at != null`, if the user is `disabled_at != null`, or if `refresh_expires_at` passed → `401 session_revoked`. Authentication failure responses never say which check failed beyond the code.
4. **Sessions and refresh rotation** (`SessionService`):
   - `login/signup` creates a session row: `refresh = base64url(32 random bytes)`, `refresh_hash = sha256Hex(refresh)`, `rotated_at = now`, `refresh_expires_at = now + 30 d`. Max **active devices** per user = plan `maxDevices` counted as distinct `device_id` among non-revoked sessions; logging in again from the **same** `device_id` **replaces** that device's older session (revokes it, reason `replaced`) instead of adding a device; exceeding the limit → `403 device_limit` (the app tells the user to remove a device from another device or the web page).
   - `refresh(token)`: `h = sha256Hex(token)`. Find the session by `refresh_hash == h` (**current**): rotate — generate a new token, `prev_refresh_hash = h`, `refresh_hash = newHash`, `rotated_at = now`, `refresh_expires_at = now + 30 d`, return a new Session (new access token too).
     Else find a session by `prev_refresh_hash == h`: if `now − rotated_at ≤ REFRESH_GRACE_SECONDS` (30 s): treat as a **concurrent refresh** by a second isolate/process of the same device (foreground app + Android background task): rotate **again** from the current state (new token; `prev_refresh_hash` becomes the token the first caller got — i.e. the old `refresh_hash`); both callers hold a valid token for the next 30 s. Else (older than the grace): **reuse detected** → revoke the **whole session** (`revoked_at`, reason `refresh_reuse`), record an `audit` event `refresh_reuse`, return `401 refresh_reuse`. The user must sign in again on that device.
     Unknown hash → `401 refresh_invalid`. Expired → `401 refresh_invalid` and revoke.
   - `logout` revokes the current session; `change-password`/`reset-password` revoke other/all sessions (WS connections of revoked sessions get `bye(session_revoked)` within 60 s, 10.9).
   - Session `last_seen_at` is updated at most once per minute per session (avoid write amplification).
5. **Brute-force protection hooks** (the limiter itself is 10.10): `login` records failures in `audit` (`login_fail`, ip) and the per-(email,ip) counters; success resets them.
6. **Email normalisation:** `trim` + lower-case (ASCII lower-case only; do not attempt Unicode folding); validation: length ≤ 254, contains exactly one `@`, local part 1–64, domain has a dot and no spaces (a small regex; do not over-validate), reject control characters → `400 invalid_email`.

**Tests.** Hasher: PHC format regex; verify true/false; constant-time compare function tested on equal/unequal/different length; parameter upgrade → `needsRehash`; a **known-answer** check: Argon2id with the RFC 9106 vector is already in Phase 3 KATs — add one server-side KAT using the package with fixed salt and your parameters, assert the golden hex (record on first run, then freeze). Policy: each rejection reason; 10-char accepted; emoji passwords counted by code point. JWT: round trip; expired (advance fake clock); wrong secret; previous secret accepted; `alg: none` rejected; wrong issuer/typ rejected; tampered payload rejected. Sessions: login creates; same device replaces; device limit; refresh rotates and the old token fails after the grace; **grace window**: two refreshes with the same token within 30 s both succeed and both resulting tokens refresh successfully; reuse after the grace revokes the session and subsequent access tokens of it fail within the 5 s cache TTL (advance clock); logout; expiry; password change revokes others; revoked session cache eviction.

**Verify.** `dart test test/auth`; record the single-hash time in `docs/ops/capacity.md`.

**Pitfalls.** Never log a password, token or hash. Never compare hashes with `==`. A refresh token is **never** a JWT and is only ever stored as SHA-256. Do not extend the refresh lifetime on the grace path beyond one rotation.

---

### 10.6 — Email: sender, templates, verification and reset tokens, HTML pages

**Purpose.** Reliable transactional email with single-use, expiring tokens, and the small web pages that complete the flows without the app.

**Files.** `server/lib/src/mail/mail_sender.dart` (interface), `smtp_mail_sender.dart`, `log_mail_sender.dart`, `memory_mail_sender.dart`, `mail_templates.dart`, `server/lib/src/auth/email_token_service.dart`, `server/lib/src/web/pages.dart` (HTML builders), `server/lib/src/web/legal_pages.g.dart` (generated), `tool/gen_legal_pages.dart`, tests `server/test/mail/*_test.dart`, `server/test/web/pages_test.dart`.

**Implementation.**
1. `MailSender.send(MailMessage m)` (`to`, `subject`, `text`, `html`) with three implementations: **SMTP** (`mailer`: `SmtpServer(host, port: port, username, password, ssl: security == ssl, allowInsecure: false)`; STARTTLS for 587; timeout 20 s; 2 retries with 1 s/3 s delay on transient errors; failures are logged at `warning` **without** the recipient address in full — log `a***@domain`), **log** (dev: prints subject + links to stdout, clearly marked `DEV MAIL`), **memory** (tests: list of sent messages).
2. **Outbox:** sending never blocks the HTTP response: the request enqueues the message in an in-process queue (max 1,000; drop oldest with `warning` beyond that) processed by one worker; a failed send is retried up to 3 times over 10 minutes and then dropped with an `audit` event `mail_failed`. (No DB outbox in v2.0; tokens can always be re-requested.)
3. **Tokens (`EmailTokenService`)**: `token = base64url(32 random bytes)`, stored as `sha256Hex`; `verify` tokens valid **24 h**, `reset` tokens **1 h**; single use (`used_at`); creating a new token of a kind invalidates earlier unused ones of that kind for the user. `consume(token, kind)` is a single UPDATE returning the user id so two simultaneous consumes cannot both succeed. Resend limits: verification mail ≤ 3 per hour per user; reset mail ≤ 3 per hour per email (silently skipped beyond, still `202`).
4. **Templates** (English, plain; text + simple HTML; no tracking pixels, no external images): *verify* (subject `Confirm your Tephra email`, link `PUBLIC_URL/verify?token=…`), *reset* (`Reset your Tephra password`, link `PUBLIC_URL/reset?token=…`, sentence: "This does not change your vault password. Your notes stay encrypted with the password and recovery key you chose in the app; nobody, including us, can recover them."), *password changed* (`Your Tephra password was changed`, with "if this was not you reset your password now" and the sign-in time/device name), *deletion scheduled* (`Your Tephra Cloud account will be deleted on <date>`; "sign in to cancel"), *deletion completed*. The subject/body never contain note content, vault names or tokens other than the single link.
5. **HTML pages** (`pages.dart`): self-contained, inline CSS, no JS, `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; form-action 'self'`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Cache-Control: no-store`: `GET /verify?token=` (consumes; shows "Email confirmed. You can close this tab and return to Tephra." or "This link has expired. Open Tephra and request a new one."), `GET /reset?token=` (shows a form with new password + confirm, hidden token; **does not consume** on GET) and `POST /reset` (validates policy, consumes, sets the hash, revokes all sessions, shows success), `GET /legal/terms` / `GET /legal/privacy` (generated constants from `docs/legal/*.md` by `tool/gen_legal_pages.dart` using `package:markdown`; the generated file is committed and a test asserts it is up to date), `GET /` (landing: name, "Sync service for the Tephra app", links). The pages escape every interpolated value (`HtmlEscape`).
6. The `forgot-password` endpoint always answers `202` after the same amount of work (queue the mail only if the user exists) to avoid account enumeration by timing or content.

**Tests.** SMTP sender against a tiny fake SMTP server in the test (a `ServerSocket` speaking the minimal SMTP dialogue: EHLO, AUTH PLAIN, MAIL, RCPT, DATA) — message arrives; retry on a 451 response; address masking in logs; token lifecycle (valid, expired by fake clock, used twice → second fails, new token invalidates old, concurrent consume → exactly one success); resend limits; template snapshots (golden strings); pages: escaping (`<script>` in token param is inert), CSP header present, GET /reset does not consume, POST /reset enforces the password policy and revokes sessions; legal constants up to date.

**Verify.** `dart test test/mail test/web`; dev mode: sign up via `curl` and see the `DEV MAIL` link in the log, open it.

**Pitfalls.** The reset link opens a **browser** page, not the app — no deep links needed (works for self-hosters too). Never reveal whether an email exists. Never put the token in a log line (the log sender prints it only in `dev`).

---

### 10.7 — Auth API endpoints and middleware pipeline

**Purpose.** Wire the auth services into the HTTP API with validation, error envelope and the middleware order used by all later endpoints.

**Files.** `server/lib/src/api/errors.dart` (`ApiException(status, code, message, {retryAfter})` + error-envelope middleware), `server/lib/src/api/middleware/` (`request_id.dart`, `request_log.dart`, `security_headers.dart`, `body_limit.dart`, `auth_required.dart`, `shutting_down.dart`), `server/lib/src/api/auth_routes.dart`, `me_routes.dart`, `json_body.dart`, tests `server/test/api/auth_routes_test.dart`, `me_routes_test.dart`.

**Implementation.**
1. **Middleware order** (outermost first): `requestId` → `requestLog` → `securityHeaders` (`X-Content-Type-Options: nosniff`, `Cache-Control: no-store` on JSON, `Strict-Transport-Security` only when `PUBLIC_URL` is https) → `shuttingDown` → `errors` (turns `ApiException` and any uncaught error into the envelope; uncaught errors become `500 internal` with **no** detail and are logged at `severe` with the request id) → router. Per-route: `bodyLimit(MAX_JSON_BYTES)` for JSON routes, `authRequired` for protected routes (puts `AuthContext` in `request.context`), the rate limiter (10.10) before `authRequired`.
2. **JSON body helper:** `readJson(request)` enforces `Content-Type: application/json`, UTF-8, size limit, rejects duplicate/unknown-type fields by explicit `fromJson` validators (hand-written, strict types, trimmed strings, lengths: `deviceName` 1–64, `platform` ∈ `android|windows|linux|macos|ios|other`, `deviceId` UUID v4 lower-case).
3. **Endpoints exactly as in the API section**, with these behaviours:
   - `signup`: checks `SIGNUP_ENABLED` (`403 signup_closed`), invite code (constant-time compare; `403 invite_invalid`), allowed email domain, `acceptedTermsVersion == TERMS_VERSION` (else `400 bad_request` with message "terms version"), password policy, email uniqueness (`409 email_taken` — documented trade-off: sign-up reveals existing emails; mitigated by rate limits), hashes the password in the pool, creates user + session, enqueues the verification mail, audits `signup`, returns `201` Session. `emailVerified:false` unless `EMAIL_VERIFICATION_REQUIRED=false` (then the user is created verified).
   - `login`: normalises email, loads user (or the dummy path), verifies, rejects disabled users (`403 account_disabled`), applies the device rules (10.5), updates `last_login_at`, returns Session; deletion-pending users **can** log in (so they can cancel), and their Session `user.deletionScheduledAt` is set.
   - `refresh`, `logout`, `verify-email`, `resend-verification`, `forgot-password`, `reset-password`, `change-password` per the table (`change-password` verifies the old password, enforces policy, sends the "password changed" mail, revokes other sessions).
   - `GET /v1/me`, `DELETE /v1/me` (verifies the password, sets `deletion_requested_at`, revokes all other sessions, sends the "deletion scheduled" mail, audits; `202`), `POST /v1/me/cancel-deletion`, `GET/PATCH/DELETE /v1/me/devices…` (10.5; `PATCH current` validates the new `deviceId` is not used by another active session of this user), `GET /v1/me/quota` (10.10).
   - While `deletion_requested_at` is set, every `/v1/vaults/**` call returns `403 account_pending_deletion`.
4. **Email verification gate:** helper `requireVerified(ctx)` used by write endpoints (10.8) when `EMAIL_VERIFICATION_REQUIRED`.
5. All time stamps come from the injected `Clock`.

**Tests.** `TestServer`-based integration tests for every endpoint: happy paths; each error code in the table that applies; signup → mail in `sentEmails` → verify via `GET /verify` → `GET /v1/me` shows verified; login wrong password (same status and similar timing as unknown email — assert response bodies are identical); refresh rotation through HTTP (including the 30-s grace, then reuse → 401 `refresh_reuse`); logout then `GET /v1/me` → 401; change-password revokes the other session; reset-password via `POST /v1/auth/reset-password` and via the HTML form; device limit; deletion pending blocks vault calls and cancel restores; malformed JSON, wrong content type, oversized body (413), unknown route (404 envelope), method not allowed (405 envelope); every response has `X-Request-Id`; 500 path hides details.

**Verify.** `dart test test/api`.

**Pitfalls.** Do not put business logic in route handlers (services only). The error envelope must be produced for **all** failures including router 404/405 — add a catch-all route.

---

### 10.8 — Vault and object endpoints (the `SyncProvider` over HTTP)

**Purpose.** The data plane: vaults, objects, listing, with every rule of the API section enforced.

**Files.** `server/lib/src/api/vault_routes.dart`, `object_routes.dart`, `server/lib/src/services/vault_service.dart`, `object_service.dart`, `upload_limiter.dart`, `server/lib/src/model/key_class.dart`, tests `server/test/api/vault_routes_test.dart`, `object_routes_test.dart`, `immutability_test.dart`.

**Implementation.**
1. **Routing:** `shelf_router` with `Route('/v1/vaults/<vaultId>/objects/<key|.+>')` for GET/HEAD/PUT/DELETE (the `|.+` regex lets `key` contain `/`); register the list route `GET /v1/vaults/<vaultId>/objects` **before** it. `vaultId` must match the UUID regex else `404 vault_not_found` (never reaches SQL/filesystem). The `key` path parameter is URL-decoded once, then `checkRemoteKey` (10.1) and `RemoteLayout.parse`; `UnknownKey` → `400 unknown_key` unless `ALLOW_UNKNOWN_KEYS`.
2. **Ownership:** `VaultService.requireOwned(ctx, vaultId)` → vault row with `user_id == ctx.userId` and `deleted_at IS NULL`; otherwise `404 vault_not_found` (do not reveal other users' vault ids; `403 not_your_vault` is reserved for create conflicts — use 404 in all read/write paths).
3. **`POST /v1/vaults`:** validates id (UUID v4 lower-case) and name (1–128 chars, no control characters); plan `maxVaults` (live vaults of the user) → `403 vault_limit`; id already exists: same user → `200` (idempotent, returns the row); other user → `409 vault_exists`.
4. **`PUT` flow (exact order):** (a) auth + verified-email + owned vault; (b) key class from `RemoteLayout.parse`; (c) check `Content-Length` ≤ `MAX_OBJECT_BYTES` (missing length → streaming limit; `Transfer-Encoding: chunked` allowed but counted); (d) quota pre-check using `Content-Length`; (e) acquire the upload semaphore (`MAX_CONCURRENT_UPLOADS`, wait ≤ 30 s else `503 unavailable` + `Retry-After: 5`); (f) spool the body (10.4) computing SHA-256; (g) verify `X-Tephra-Sha256` and, for blobs, the hash in the key; (h) **immutable-class rule** (key exists live: compare stored `sha256` — equal → respond `200` without touching storage; different → delete spool, `409 immutable_key`; blobs: equal hash by construction → `200`); (i) quota re-check with the real size; (j) `storage.put` (durable); (k) one DB transaction: upsert `objects` (keep `created_at` on replace of a live row; a row that was soft-deleted is **reset**: new `created_at`, `deleted_at = NULL`), adjust vault usage, append `changes`, and for `vault.json` insert a `header_versions` row (keep 10); (l) after commit delete the replaced `storage_ref` (if any) and, for a re-created soft-deleted row, its trashed ref; (m) publish a `ChangeEvent` to the hub (10.9) **after** the commit; (n) respond with the JSON body of the API section (`201` if new).
5. **`GET`:** owned vault; row live → stream from storage with `Content-Length`, `ETag: "<sha256>"`, `X-Tephra-Created/Modified`, `Content-Type: application/octet-stream`; honour `If-None-Match` (→ `304`); a missing storage ref for a live row is a **server integrity error**: respond `500 internal`, log `severe` with vault id + key (alert-worthy), and count `integrity_errors_total` (10.10 metrics). `HEAD` same without body.
6. **`DELETE`:** soft-delete: set `deleted_at = now` (keep `storage_ref` for the trash), subtract from vault usage (trash does not count toward the quota, 10.10), append `changes(removed=1)`; missing or already deleted → `204`.
7. **List:** query params `prefix` (default `''`, validated as a prefix of the allowed charset, length ≤ 512), `limit` (1–5,000, default 1,000), `after` (a key or `''`); `nextAfter` = last key when the page was full, else `null`.
8. **`GET /v1/vaults`, `GET /v1/vaults/<id>`, `DELETE /v1/vaults/<id>`** (verifies the password; soft-deletes all objects (single UPDATE), sets `vaults.deleted_at`, publishes `bye(vault_deleted)`; `204`).
9. **Server clocks:** `created`/`modified` returned to clients are server time from the injected `Clock` (the GC lease rule 03.23 depends on it).

**Tests.** Integration with `TestServer` and real bytes: PUT/GET/HEAD/DELETE round trips (0 B, 1 B, 4 MiB+50, 16 MiB, 16 MiB+1 → 413); every key rule and class rule (`unknown_key`, bad charset, `..`); blob hash mismatch → 422; `X-Tephra-Sha256` mismatch → 422; **immutability**: journal put twice with identical bytes → 200 twice, with different bytes → 409; snapshot, manifest, revocation the same; blob same key twice → 200; mutable classes replace (vault.json, device file, lock) and `header_versions` keeps the last 10; re-put after delete resets `created`; delete missing → 204; list ordering/prefix/after/limit/`nextAfter`; ownership (user B gets 404 for user A's vault id and object); quota pre-check and post-check; concurrency (50 parallel PUTs of different keys, 20 parallel PUTs of the same journal key with identical bytes → all 200, DB consistent; 20 parallel PUTs of the same key with different bytes → exactly one winner for immutable classes); upload aborted mid-body leaves no spool file, no DB row; storage failure (inject a throwing `BlobStorage`) → 503 and DB unchanged; missing storage ref → 500 + `integrity_errors_total`; `DELETE` vault flow; vault limit; idempotent create.

**Verify.** `dart test test/api`.

**Pitfalls.** Do **not** read the request body before the cheap checks (length, quota, key rules) — reject early. Never trust the client's `Content-Length` alone (count bytes). Keep `created` semantics: GC grace uses it. Never delete the old storage ref before the DB commit.

---
### 10.9 — Change feed with epoch, and the WebSocket event hub

**Purpose.** `changesSince` semantics identical to the contract, plus instant push.

**Files.** `server/lib/src/realtime/change_hub.dart`, `ws_handler.dart`, `ws_registry.dart`, `server/lib/src/api/changes_routes.dart`, `server/lib/src/services/epoch_service.dart`, tests `server/test/realtime/*_test.dart`, `server/test/api/changes_routes_test.dart`.

**Implementation.**
1. **Cursor = `v1.<epoch>.<seq>`** where `<epoch>` is an 8-hex-character random id stored in `meta.epoch` and `<seq>` is `changes.seq`. `EpochService.ensure()` creates the epoch on first start. **Why an epoch:** after the server is restored from a backup, new changes reuse sequence numbers that clients may already have passed (a client with cursor 1210 would silently miss new changes 1201–1210). A cursor with a different epoch is treated as unknown → `cursorWasReset:true` → the client does a full `list` (always safe). The epoch changes when (a) the admin runs `tephra-admin bump-epoch` (**mandatory step of the restore procedure**, 10.20), (b) the server starts and `max(changes.seq)` is **lower** than the value in the side-car file `<DATA_DIR>/epoch.state` (`{"epoch","maxSeq"}`, rewritten every minute by a job — detects an in-place rollback), (c) the change-log is trimmed past a client's cursor (then only that client resets, by rule below).
2. `GET /v1/vaults/{id}/changes?cursor=&limit=` per the API section: no cursor → start token (`v1.<epoch>.<currentSeq>`); malformed cursor, wrong epoch, `seq > currentSeq`, or `seq < vaults.min_change_seq` → `cursorWasReset:true` with a fresh start token. Otherwise `ChangesDao.since(vaultId, seq, limit + 1)`: `hasMore = rows.length > limit`; the returned cursor = `seq` of the last **processed** row (or the original seq when no rows); `changedKeys` = keys with any `removed=0` row in the page, `removedKeys` = keys whose **last** row in the page has `removed=1` (so put-then-delete is in both lists, as the contract allows; delete-then-put only in `changedKeys`); keys sorted, de-duplicated.
3. **`ChangeHub`** (in-process, single node): `publish(ChangeEvent(vaultId, seq, keys, removed))` called by the object service **after** the DB commit; per vault a batcher flushes every **100 ms** or at **200 keys**, whichever first, sending one `changed` frame to every subscribed socket with `cursor = v1.<epoch>.<highest seq in batch>`. If more than 200 distinct keys accumulated inside one window the frame carries `"keys":[],"removed":[],"overflow":true` (client must call `changesSince`). Frames never contain object bytes.
4. **WebSocket endpoint** `GET /v1/vaults/{vaultId}/events`: the handler first authenticates (`Authorization: Bearer …`, or `?token=` query if no header — the query token is the normal 15-min access token; the access log never prints query strings) and verifies vault ownership **before** upgrading (so failures are normal JSON errors with the envelope, status 401/404), then upgrades with `webSocketHandler(…, pingInterval: Duration(seconds: 20))` from `shelf_web_socket`. On connect send `hello`. Limits: ≤ 10 sockets per user (`429 rate_limited` beyond), ≤ 5,000 total (`503 unavailable`). A registry timer every **60 s** re-checks each socket's session (revoked/disabled/expired refresh) and the vault (`deleted_at`) → sends `bye` with the reason and closes with code **4401** (session) / **4404** (vault deleted); shutdown sends `bye(shutting_down)` and closes with 1001. Incoming frames from clients are ignored (text frames larger than 1 KiB close the socket with 1009). A send error removes the socket silently.
5. `CloudEvent` JSON frames exactly as in the API section (plus `overflow`). The `changed` frame includes keys from **all** devices including the sender; the client filters its own.
6. Metrics: `tephra_ws_connections` gauge, `tephra_ws_events_total`.

**Tests.** `changes_routes_test.dart`: start token; put → changed; delete → removed; put-then-delete in both lists; delete-then-put only in changed; pagination with `hasMore` over 12,000 changes (limit 5,000) loses nothing and duplicates nothing; wrong epoch/garbage/greater-than-current/older-than-`min_change_seq` → reset; **epoch bump** (admin call) → previously valid cursor resets; rollback detection from the side-car; cursor of vault A never returns vault B's keys. `realtime` tests with a real `HttpServer` + `IOWebSocketChannel`: hello then changed within 300 ms of a PUT; batching (50 PUTs in 50 ms → ≤ 3 frames, all keys present); overflow frame; two sockets both receive; other user's socket receives nothing; revoked session → `bye` + close 4401 within 61 s (advance the fake clock/timer); vault delete → 4404; shutdown → 1001; 11th socket refused; auth via header and via query; no upgrade for a foreign vault (404 JSON, not a socket); an oversize incoming frame closes the socket.

**Verify.** `dart test test/realtime test/api/changes_routes_test.dart`.

**Pitfalls.** Publish only **after** commit (a client must be able to read what an event announces). Never put the access token in a log line (strip `token` from logged URLs). Timers in tests use the injected clock/`FakeAsync` — do not `sleep` 60 s in tests.

---

### 10.10 — Quotas and plans, rate limiting, size and time limits, metrics

**Purpose.** Protect the service and enforce the free tier.

**Files.** `server/lib/src/limits/plans.dart`, `quota_service.dart`, `token_bucket.dart`, `rate_limiter.dart`, `client_ip.dart`, `server/lib/src/api/middleware/rate_limit.dart`, `server/lib/src/metrics/metrics.dart`, `server/lib/src/api/metrics_handler.dart`, `server/lib/src/db/migrations/m002_trash_bytes.dart`, tests `server/test/limits/*_test.dart`, `server/test/api/metrics_test.dart`.

**Implementation.**
1. **Migration `m002`:** `ALTER TABLE vaults ADD COLUMN trash_bytes INTEGER NOT NULL DEFAULT 0;` (adjusted by delete/purge/re-create in the same transactions as `used_bytes`; this is why the schema number is 2 — update 10.3's tests to expect version 2 after all migrations).
2. **Plans** (`plans.dart`, values from config, constants in one place): `free` = `{storageBytes: PLAN_FREE_STORAGE_BYTES, maxVaults, maxDevices}`; `pro` = `{storageBytes: PLAN_PRO_STORAGE_BYTES (default 53687091200 = 50 GiB), maxVaults: 20, maxDevices: 20}` (placeholder for a future paid plan; there is **no payment integration** in v2.0 — the human assigns `pro` by hand with the admin CLI); `users.quota_override_bytes` beats the plan's storage. `QuotaService.limitFor(user)`, `usedBytes(userId)` = sum of `vaults.used_bytes` of the user's non-deleted vaults, `trashBytes(userId)`.
3. **Enforcement (used by 10.8):** `checkPut(user, deltaBytes)`: reject `507 quota_exceeded` when `used + delta > limit`; **trash hard cap:** reject when `used + trash + delta > 2 × limit` with message "trash full" (prevents hiding storage in soft-deleted data; frees as the retention job purges). `GET /v1/me/quota` returns the API-section shape. Also disk protection: when the local-storage volume has < 5% free, new PUTs return `503 unavailable` (`storage full`) and `tephra_disk_free_bytes` is exported.
4. **Token buckets** (`TokenBucket(capacity, refillPerSecond, now)`, deterministic with the injected clock; `RateLimiter` holds named bucket families in LRU maps (max 50,000 keys each, oldest evicted; an evicted key simply starts full) — memory bounded). Families and defaults (overridable with the YAML map `rate_limits:`; env is not used for these):

   | Family | Key | Capacity | Refill | Applies to |
   |---|---|---|---|---|
   | `auth_ip` | client IP | 20 | 1 per 3 s (20/min) | all `/v1/auth/*`, `/verify`, `/reset` |
   | `login_account` | email_lc + IP | 5 | 1 per 180 s (5 per 15 min) | `login` (failures only consume; success refills the bucket) |
   | `signup_ip` | IP | 5 | 1 per 720 s (5/h) | `signup` |
   | `forgot_ip` | IP | 5 | 1 per 720 s | `forgot-password` |
   | `forgot_email` | email_lc | 3 | 1 per 1,200 s (3/h) | `forgot-password` (over limit: still 202, no mail) |
   | `api_user` | user id | 120 | 10/s (600/min) | every authenticated `/v1/**` call |
   | `put_user` | user id | 60 | 5/s | object `PUT` |
   | `ws_user` | user id | 10 | 1 per 6 s | WebSocket upgrades |

   Rejection = `429 rate_limited` with `Retry-After: <ceil seconds until one token>` and `retryAfterSeconds`. The limiter runs **before** body reads and before password hashing (so abuse is cheap to reject). `client_ip.dart`: if `TRUST_PROXY=true` use the **last** value of `X-Forwarded-For` (Caddy appends the real client address; earlier values are client-supplied and ignored), else the socket's remote address; IPv6 addresses are bucketed by their /64 prefix.
5. **Size/time limits** (in addition to 10.7/10.8): JSON ≤ `MAX_JSON_BYTES`; object ≤ `MAX_OBJECT_BYTES`; header size limit left at the Dart default (8 KiB); `HttpServer.idleTimeout = 60 s`; JSON request overall timeout 15 s; object upload overall timeout 5 min (slow-loris protection: a body that delivers < 1 KiB/s for 30 s is aborted); download streams have no total timeout but stop when the peer stops reading (Dart `HttpResponse` back-pressure).
6. **Metrics** (`/metrics`, enabled only when `METRICS_TOKEN` is set; `Authorization: Bearer <token>`; Prometheus text exposition 0.0.4, hand-written): `tephra_http_requests_total{route,status}`, `tephra_http_request_duration_seconds_sum{route}` and `_count`, `tephra_upload_bytes_total`, `tephra_download_bytes_total`, `tephra_ws_connections`, `tephra_ws_events_total`, `tephra_rate_limited_total{family}`, `tephra_integrity_errors_total`, `tephra_mail_sent_total`, `tephra_mail_failed_total`, `tephra_process_rss_bytes` (`ProcessInfo.currentRss`), `tephra_uptime_seconds`, `tephra_db_queue_depth`, and (computed at most every 60 s) `tephra_users_total`, `tephra_vaults_total`, `tephra_storage_live_bytes`, `tephra_storage_trash_bytes`, `tephra_disk_free_bytes`. `route` is the **template** (never raw ids/keys). Label cardinality is bounded (fixed route list).

**Tests.** Token bucket maths with a fake clock (burst, refill, retry-after rounding, eviction); each family with the exact defaults through HTTP (21st login-page call in a minute → 429; 6th failed login for one email+IP → 429; 4th forgot-password mail request for one email silently skipped but 202); success refills `login_account`; `Retry-After` header correct; IPv6 /64 bucketing; `X-Forwarded-For` honoured only with `TRUST_PROXY` and only the last value; quota edge cases (exactly at limit allowed, +1 byte rejected, replace smaller/larger, trash cap 2×, override beats plan, pro plan); disk-low gate (inject a fake free-space provider); metrics endpoint requires the token (401 otherwise), output parses with a small Prometheus-format checker in the test, route labels contain no ids.

**Verify.** `dart test test/limits test/api/metrics_test.dart`.

**Pitfalls.** Never key a bucket on something an attacker can vary freely without also bounding the map. The `login_account` bucket is keyed by email **and** IP on purpose (an attacker must not be able to lock a victim out by guessing their email from elsewhere; the per-IP family still limits the attacker).

---

### 10.11 — Retention, background jobs, account deletion

**Purpose.** Trash and log retention, cleanups, hard deletion of accounts, consistency self-checks.

**Files.** `server/lib/src/jobs/job_runner.dart`, `trash_purge_job.dart`, `changelog_trim_job.dart`, `housekeeping_job.dart`, `account_deletion_job.dart`, `orphan_sweep_job.dart`, `counter_check_job.dart`, `epoch_state_job.dart`, tests `server/test/jobs/*_test.dart`.

**Implementation.** `JobRunner` runs named jobs on `Timer.periodic` with an initial random delay (0–60 s), never overlapping itself, catching and logging every exception at `severe`, recording `tephra_job_last_success_seconds{job}`; jobs take the injected `Clock`; `tephra-admin run-job <name>` runs one on demand.

| Job | Period | Behaviour |
|---|---|---|
| `trash_purge` | 1 h | objects with `deleted_at < now − TRASH_RETENTION_DAYS`: delete their `storage_ref` first, then the rows (subtract `trash_bytes`); vaults soft-deleted longer than the retention: purge all their objects and the vault row; max 5,000 objects per run (loop on next tick) |
| `changelog_trim` | 24 h | delete `changes` older than `CHANGELOG_KEEP_DAYS` (per vault keep at least the newest 10,000 rows); set `vaults.min_change_seq` to the smallest remaining seq − 1 for vaults that lost rows |
| `housekeeping` | 24 h | delete sessions revoked/expired > 30 days ago; purge expired `email_tokens` (> 7 days past expiry/use); `audit`: set `ip = NULL` where older than **14 days**, delete rows older than **180 days**; delete unverified accounts older than **14 days** with no vaults (reason: sign-up spam) after mailing nothing; `PRAGMA wal_checkpoint(TRUNCATE)`; `PRAGMA optimize` |
| `account_deletion` | 1 h | users with `deletion_requested_at + ACCOUNT_DELETION_GRACE_DAYS ≤ now`: (1) send the "deletion completed" mail first (address needed), (2) for each of the user's vaults delete every object's storage ref (live and trash) in batches, (3) delete the `users` row (cascades to sessions, tokens, vaults, objects, header_versions), (4) write an `audit` row `account_deleted` with **no** email (user id only), (5) close sockets. Idempotent and restartable (a crash after step 2 leaves rows pointing at missing refs for a deleted-pending user; step 2 treats missing refs as done) |
| `orphan_sweep` | 7 d | `storage.listRefs(vaultId)` for every vault; refs not present in `objects` or `header_versions` **and** older than 1 day (file mtime / S3 `lastModified`) → delete; log counts; also deletes spool files in `tmp/` older than 10 minutes |
| `counter_check` | 7 d | recompute `used_bytes`, `trash_bytes`, `object_count` per vault from `objects`; if different, log `warning` with both values and correct them |
| `epoch_state` | 1 min | rewrite `<DATA_DIR>/epoch.state` atomically (temp + rename) with `{epoch,maxSeq}` |
| `disk_check` | 1 min | refresh free-space gauge (local backend) |

**Server-side "history retention" — what it is and is not (written into the ops guide):** deleting an object (the client's GC deleting a blob, or removing a lease) moves it to a **30-day server trash**; the admin can restore it (`tephra-admin restore-object`, 10.12). The server cannot decrypt journals, so it **never decides what is garbage**: blob garbage collection stays the client's two-phase, lease-based algorithm of 03.23, unchanged (this resolves the Phase 3 hand-off note "a server-side GC must keep exactly the same live set": the server performs **no** GC; its trash is only a safety net behind the client's GC). Users get per-note history from the Phase 3 version history; there is no server-side history UI in v2.0.

**Tests.** Each job with a fake clock and `TestServer`: trash purge removes only objects past retention (and their storage refs), never live ones; vault purge; changelog trim keeps the minimum and sets `min_change_seq` so an old cursor resets; housekeeping thresholds (13-day vs 15-day unverified account), audit IP nulling at 14 days; **account deletion** full path (mail first, then storage refs gone — assert the local blob directory is empty —, user row gone, sessions invalid, WS closed, idempotent after an injected crash in the middle); orphan sweep deletes an unreferenced old file but not a young one nor a referenced one; counter check repairs a deliberately corrupted counter; epoch state written atomically; jobs never overlap and survive exceptions.

**Verify.** `dart test test/jobs`.

**Pitfalls.** Delete storage first, then rows, in the deletion job (crash-restartable); delete **DB-row last** in the purge of trash only after the storage delete succeeded. Do not purge anything when `now` looks wrong (system clock jump back > 1 h → skip the run and log) to avoid mass deletion after a clock fault.

---

### 10.12 — Admin CLI `tephra-admin`

**Purpose.** Operate the server without SQL: users, quotas, health checks, restore helpers.

**Files.** `server/bin/tephra_admin.dart`, `server/lib/src/admin/` (`admin_runner.dart`, `commands/*.dart`, `output.dart`, `prompt.dart`), tests `server/test/admin/*_test.dart`.

**Implementation.** Uses `package:args` `CommandRunner`; opens the same `DATA_DIR` and config as the server (`--config`, env); global flags `--json` (machine output), `--data-dir`. Exit codes: `0` ok, `1` operation failed, `2` usage/config error. Output: aligned plain-text tables; never prints password hashes or tokens (except the one-time reset link in `reset-link`, and only to the console). Commands:

| Command | Behaviour |
|---|---|
| `config-check` | loads and validates config, prints the redacted config, tests DB open, storage `checkReady`, SMTP login (`--smtp`) |
| `migrate` | runs pending migrations (with the pre-migrate backup) |
| `create-user --email E [--plan free\|pro] [--verified] [--password-stdin]` | prompts for the password twice (no echo: `stdin.echoMode = false`) or reads one line from stdin; applies the password policy; creates a verified account when `--verified` |
| `list-users [--limit N] [--query text]` | id, email, plan, verified, created, last login, used bytes |
| `show-user --email E` | full record + vaults + sessions (device names, last seen) |
| `set-plan --email E --plan P`, `set-quota --email E --bytes N` / `--clear` | change plan / override |
| `verify-email --email E`, `disable-user`, `enable-user`, `revoke-sessions --email E` | self-explanatory (disabled users' sessions stop within 5 s) |
| `reset-link --email E` | creates a reset token and **prints the link** (for support when mail fails); audited |
| `delete-user --email E --yes` | immediate hard deletion (same code path as the deletion job) |
| `stats` | users (total/verified/pending deletion), vaults, objects, live bytes, trash bytes, active sessions, DB size, blob dir size, disk free, oldest/newest change seq, epoch |
| `list-trash --vault V [--prefix P]`, `restore-object --vault V --key K`, `purge-trash --older-than-days N` | trash handling; `restore-object` clears `deleted_at` (if the storage ref still exists) and appends a `changes` row so clients see it; refuses if a live object with that key exists |
| `verify-storage [--deep] [--fix-orphans] [--vault V]` | every **live** object has an existing storage ref whose size equals `size`; `--deep` also re-hashes the bytes and compares `sha256` (and for `blobs/<hash>` that the key equals the hash); recomputes counters; prints a summary and exits `1` if any problem; `--fix-orphans` runs the orphan sweep |
| `repair-counters` | same recomputation as the weekly job, applied immediately |
| `db-check` | `PRAGMA integrity_check` and `foreign_key_check`; exit `1` on any output other than `ok` |
| `backup --to DIR` | `VACUUM INTO '<DIR>/tephra-<yyyyMMddTHHmmssZ>.sqlite'`, then writes `<file>.sha256`; refuses a non-empty path collision; prints the path (used by the backup job, 10.20) |
| `bump-epoch` | sets a new random `meta.epoch` and removes `epoch.state` (**run after every restore**) |
| `gen-secret` | prints 48 random bytes as base64url (for `JWT_SECRET`, `METRICS_TOKEN`); touches nothing else |
| `export-user --email E [--out file]` | JSON export of the account's data for access requests (10.22); contains no password hash, tokens, object keys or content |
| `run-job NAME` | runs a background job once |

The Docker image contains both binaries (`/app/tephra-server`, `/app/tephra-admin`); usage on the VPS: `docker compose exec tephra /app/tephra-admin stats`.

**Tests.** Every command against a temp data dir: `create-user` (stdin password; policy enforced), `stats` numbers, `set-quota` visible in `GET /v1/me/quota` through `TestServer` sharing the DB file, `reset-link` token works at `POST /reset`, `delete-user` removes storage and rows, trash list/restore (and the restore refusal when a live object exists), `verify-storage` detects a deleted blob file, a truncated blob, a flipped byte (`--deep`), an orphan, a wrong counter; `db-check` on a corrupted DB file returns 1; `backup` produces a file that opens, passes `integrity_check` and matches its checksum; `bump-epoch` invalidates cursors; exit codes and `--json` output shape.

**Verify.** `dart test test/admin`; `dart compile exe bin/tephra_admin.dart -o ../dist/tephra-admin.exe` succeeds.

**Pitfalls.** The CLI shares the DB with a running server (WAL permits it); keep CLI write transactions short. Never print secrets from the config.

---

### 10.13 — Client: `TephraCloudSyncProvider`, auth client, token source, events client

**Purpose.** The provider that implements the **unchanged** `SyncProvider` contract against the API, and the supporting pure-Dart client pieces.

**Files (all in `packages/tephra_sync/lib/src/cloud/`, pure Dart).** `cloud_api_models.dart`, `cloud_http.dart`, `cloud_retry.dart`, `cloud_auth_api.dart`, `cloud_token_source.dart`, `cloud_authed_client.dart`, `tephra_cloud_sync_provider.dart`, `cloud_events_client.dart`, `cloud_vault_directory.dart`, and `lib/src/remote/remote_vault_directory.dart` (interface), `lib/src/errors/sync_exceptions.dart` (edit: add two classes), tests `packages/tephra_sync/test/cloud/*_test.dart`. Export from `lib/tephra_sync.dart` (provider, auth API, token source, DTOs, directory, events client).

**Implementation.**
1. **DTOs** (`cloud_api_models.dart`): immutable classes with hand-written `fromJson`/`toJson` for **every** JSON shape of the API section (`CloudSession`, `CloudUser`, `CloudDevice`, `CloudObjectInfo`, `CloudObjectList`, `CloudChanges`, `CloudQuotaInfo`, `CloudVaultInfo`, `CloudServerInfo`, `CloudEvent` sealed: `CloudHello`, `CloudChanged`, `CloudBye`, `CloudApiError`). **The server's handlers serialise responses through these same classes** (refactor 10.7/10.8 handlers to use `toJson` — a test asserts byte-equality of the produced JSON with the fixtures in `docs/decisions/cloud-api-v1.md`, so the two sides cannot drift).
2. **New exceptions** (`sync_exceptions.dart`, additive, each with a test): `RemoteKeyExistsException(String key)` (HTTP 409 `immutable_key`; `JournalWriter.commit` catches it for keys under `journals/<myDeviceId>/` and throws `DeviceCloneDetectedException`, any other key → `RemoteFormatException`); `AccountActionRequiredException(String code)` (`email_not_verified`, `account_disabled`, `account_pending_deletion`, `device_limit`, `vault_limit`; the engine maps it to status `needsAttention` with `errorKind = code`).
3. **`CloudHttp`**: wraps `http.Client`; adds headers (`User-Agent`, `X-Tephra-Api: 1`, `Authorization` via `AccessTokenSource`); maps every non-2xx with the error-envelope `code` to the exception of the table in the API section; `Retry-After` parsed (seconds). **`CloudRetry`** (same algorithm as `DriveRetry`: full jitter `[0, min(64 s, 1 s × 2^attempt)]`, honour `Retry-After`, **max 6 retries**) retries 429, 500, 502, 503, 504, `SocketException`, `TimeoutException`, `http.ClientException`, and `422` **once**; never retries 400, 401 (handled by the authed client), 403, 404, 409, 413, 507. After the last retry: 429 → `RateLimitedException`, 5xx → `RemoteServerException`, network → `NetworkUnavailableException`. Timeouts: 30 s for JSON calls; for object transfers `max(60 s, size / (50 KiB/s))`.
4. **`CloudAuthedClient`** = Phase 3 `AuthedClient` behaviour: on `401 unauthorized`, `accessToken(forceRefresh: true)` once and retry once (buffer replayable bodies; object bodies are byte lists so replay is fine); a second 401 → `AuthRevokedException`.
5. **`CloudAuthApi`** (unauthenticated + authenticated calls): `signUp`, `logIn`, `refresh`, `logOut`, `verifyEmail` (not used by the app; the link opens in the browser), `resendVerification`, `forgotPassword`, `changePassword`, `me`, `quota`, `devices`, `renameCurrentDevice`, `removeDevice`, `deleteAccount`, `cancelDeletion`, `serverInfo`, `createVault`, `listVaults`, `getVault`, `deleteVault`. Errors → `CloudApiException(code, status, message, retryAfter)` (extends `SyncException`) so the UI can switch on `code`; auth-flow errors (`invalid_credentials`, `email_taken`, `weak_password`, …) are **not** retried.
6. **`CloudTokenSource implements AccessTokenSource`** (`SecretStore` keys, exact strings): `tephra.cloud.serverUrl`, `tephra.cloud.refreshToken`, `tephra.cloud.accessToken`, `tephra.cloud.accessTokenExpiry` (local ISO UTC), `tephra.cloud.accountEmail`, `tephra.cloud.deviceId`. `accessToken()`: return the cached token if it expires in more than 2 minutes; else refresh with **single-flight** (one in-flight `Future` per isolate; concurrent callers await it). **Clock skew:** `CloudSession.serverTime` (added to the Session object: `"serverTime":"…"`) is compared with the local clock when a session is received; the stored expiry = `localNow + (accessExpiresAt − serverTime)`. Refresh failures: `refresh_invalid` / `refresh_reuse` / `session_revoked` → delete stored tokens, throw `AuthRevokedException`; network → `NetworkUnavailableException`; `account_*` → `AccountActionRequiredException`. `signOut()` → best-effort `POST /v1/auth/logout`, delete keys. **Concurrent refreshers in two processes/isolates** (foreground app and the Android background task) are safe because of the server's 30-second grace (10.5); after any refresh the new refresh token is written to the `SecretStore` **before** the access token is returned.
7. **`TephraCloudSyncProvider(CloudHttp http, String vaultId, {Clock clock})` implements `SyncProvider`** (`id == 'tephra-cloud'`), semantics of 03.2 exactly:
   - `connect()` → `GET /v1/vaults/{id}`; 404 → `RemoteVaultMissingException`; auth/network errors as mapped. Idempotent.
   - `list(prefix)` → loop `GET …/objects?prefix=&limit=1000&after=` following `nextAfter`; returns `RemoteObject(key,size,modified,created)` sorted ascending, no duplicates (de-duplicate defensively).
   - `get(key)` → `GET …/objects/<key>`; 404 → `RemoteNotFoundException(key)`. **Integrity:** compute SHA-256 of the received bytes; if it differs from the `ETag` header → retry once, then `TamperedDataException(key)` (transport or at-rest corruption becomes a typed, reportable error that Phase 9's `DamagedRemote` plumbing already handles).
   - `put(key, bytes)` → `PUT` with `X-Tephra-Sha256: <hex>`; `checkRemoteKey` first (no network on invalid keys → `ArgumentError`); zero-length allowed; `409 immutable_key` → `RemoteKeyExistsException`; `507` → `RemoteQuotaExceededException`; `413` → `SyncException('object too large')`.
   - `delete(key)` → `DELETE`; always success for 204.
   - `changesSince(cursor)` → `GET …/changes` (no `cursor` param when null); loop while `hasMore` (max 50 pages, accumulating and de-duplicating; if the cap is hit return `cursorWasReset: true` with the last cursor so the caller re-lists); map `cursorWasReset`.
   - `quota()` → `GET /v1/me/quota` → `Quota(usedBytes, limitBytes)`.
   - Pre-flight like Drive's (03.15 item 6): the engine's "Drive full" check generalises — `SyncEngine` already calls `quota()` before the upload phase; for Tephra Cloud the warning text differs (`syncWarningCloudAlmostFull`, `syncErrorCloudFull`); map by `provider.id`.
8. **`CloudEventsClient(Uri baseUrl, String vaultId, AccessTokenSource tokens, {Clock, Random})`** exposes `Stream<CloudEventsState>` (`connecting`, `connected`, `disconnected(reason)`) and `Stream<CloudEvent>`; connects with `IOWebSocketChannel.connect(uri(ws/wss), headers: {'Authorization': 'Bearer …'}, pingInterval: 20 s)`; reconnect backoff 1, 2, 4, 8, 16, 30 s (full jitter, reset after 60 s of stable connection); on an upgrade failure with 401 refresh the token once; `bye(session_revoked)` → emit `disconnected(authRevoked)` and **stop** (no reconnect; the engine surfaces "Reconnect"); `bye(shutting_down)` or close 1001 → reconnect after 5 s; dispose cancels everything (lint-enforced). After every `connected` the consumer must run a catch-up `changesSince`; the client emits a synthetic `CloudChanged(overflow: true)` right after each reconnect to trigger it.
9. **`RemoteVaultDirectory`** interface (new, in `remote/`), implemented by `DriveVaultFinder` (adapt the Phase 3 class; keep its tests) and `CloudVaultDirectory`: `Future<List<RemoteVaultInfo>> listRemoteVaults()`, `Future<void> createRemoteVault({required String vaultId, required String vaultName})` (Drive: `createVaultFolders`; Cloud: `POST /v1/vaults`, idempotent), `Future<SyncProvider> providerFor(String vaultId)`. `RemoteVaultInfo` gets an optional `usedBytes`. The wizard's `SyncSetupService` depends on this interface (10.15).
10. **Engine integration (small, additive):** (a) `SyncTriggers` accepts a `Stream<CloudEvent>`; on `CloudChanged` with `overflow` or any key that does **not** start with `journals/<myDeviceId>/` (own batches are ignored) or on `CloudHello`/reconnect → immediate `SyncNow(remotePoll)` (coalesced with the existing "run again" flag; **no** debounce); (b) polling interval: **120 s while the socket is connected**, 30 s otherwise (Phase 3 item 5 default); (c) **save debounce** per provider: `gdrive` keeps **5 s**, `tephra-cloud` uses **1 s**; (d) `SyncEngine` status mapping gains `AccountActionRequiredException` → `needsAttention`; (e) `JournalWriter.commit` handles `RemoteKeyExistsException` as above; (f) `provider.id == 'tephra-cloud'` → `ThrottledSyncProvider` wrapper stays; (g) the worker's `TokenRequest` proxy works for any `AccessTokenSource`.

**Tests.** Unit tests with a fake `http.Client` or a local `HttpServer`: every error code → exception type; retry counts (429 ×3 then success; 503 ×7 → `RemoteServerException` after exactly 6 retries; 422 retried once; 409/507/413 never retried); `Retry-After` honoured; 401 → refresh → success; second 401 → `AuthRevokedException`; `get` ETag mismatch → one retry → `TamperedDataException`; `changesSince` paging and the 50-page cap; invalid keys never hit the network; DTO round trips against the JSON fixtures; token source single-flight (10 concurrent callers → 1 refresh), skew compensation (local clock 10 min fast/slow), failure mapping, keys written in the right order; events client with a fake WS server: reconnect backoff sequence, 401 upgrade → refresh → reconnect, `bye(session_revoked)` stops, `shutting_down` reconnects after 5 s, synthetic overflow after reconnect, dispose closes; triggers: own-device journal keys ignored, foreign keys trigger an immediate cycle, 120/30 s polling switch, 1 s vs 5 s debounce (fake clock).

**Verify.** `cd packages/tephra_sync; dart test test/cloud`.

**Pitfalls.** No Flutter imports in `tephra_sync` (use `web_socket_channel/io.dart`, which is pure Dart). Do **not** add methods to `SyncProvider`. Never log tokens, `Authorization`, or full URLs with `?token=`.

---

### 10.14 — Contract suite, fuzz simulator and data-safety drills against a real test server

**Purpose.** Gate item: "the same fuzz and data-safety tests as Phase 3 pass with the Tephra Cloud provider". Server ← sync (conventions §3), so these tests live in `server/test/` and import the Phase 3/9 test support by relative path.

**Files.** `server/test/cloud/cloud_provider_contract_test.dart`, `cloud_provider_extra_test.dart`, `cloud_sync_engine_test.dart`, `cloud_fuzz_test.dart`, `cloud_crash_drill_test.dart`, `cloud_corruption_test.dart`, `cloud_server_crash_test.dart`, `server/test/support/cloud_world.dart`; edits: `packages/tephra_sync/test/simulator/sim_world.dart` (accept a provider factory), `tool/drill_kill_sync.dart` (add `--provider cloud`), `server/dart_test.yaml` (tags `fuzz`, `slow`, `s3`, `load`).

**Implementation.**
1. **Cross-package test support.** `import '../../packages/tephra_sync/test/support/sync_provider_contract.dart';` (and the simulator files) — a relative import out of the package's `test/` folder is allowed by Dart; add a comment on each such import: `// Relative import on purpose: shared test support lives in tephra_sync/test (server ← sync, conventions §3).` Do not copy the files. If the analyzer rejects it, move the shared test support to `packages/tephra_sync/lib/src/testing/` exported as `package:tephra_sync/testing.dart` (a separate library; it may import `package:test`, which is then a normal dependency of `tephra_sync`) and update Phase 3 imports — ask the human first, because it changes a package's public surface.
2. **Contract suite:** `runSyncProviderContract('TephraCloudSyncProvider (live test server)', () async => world.newProvider())` where `CloudWorld` starts a `TestServer`, signs up a verified user, creates a vault and returns a `TephraCloudSyncProvider` with a `CloudTokenSource` over an in-memory `SecretStore`. All 10 contract tests of 03.2 pass unchanged (test 6's "retry up to 10 s" is not needed but harmless; test 8: `modified` within 10 minutes of the local clock).
3. **Extra cloud tests** (`cloud_provider_extra_test.dart`): 12,000 keys list pagination; `changesSince` reset after `bump-epoch`; reset on garbage cursor; access token expiry mid-run (advance the **server** `FakeClock` by 16 min → 401 → silent refresh → the operation succeeds); refresh-token reuse → `AuthRevokedException`; revoked device session → next call `AuthRevokedException` within 6 s; quota exceeded (set quota via admin DAO) → `RemoteQuotaExceededException` and no partial object; immutable journal conflict → `RemoteKeyExistsException`; email not verified → `AccountActionRequiredException('email_not_verified')`; vault missing → `RemoteVaultMissingException`; **two users** cannot see each other's vaults; 20 concurrent puts; 6 MiB put/get; ETag integrity detection when a stored file is corrupted on disk (flip a byte directly in the blob directory) → `TamperedDataException`.
4. **Engine tests with the cloud provider:** run `sync_engine_test.dart` scenarios (two engines, one provider: create/edit/delete/rename round trips, quota exceeded mid-upload, cancel) against the live server by parameterising that test file with a provider factory (add the parameter in Phase 3's test file in a backward-compatible way, default = `MemorySyncProvider`) — or duplicate the five most important scenarios in `cloud_sync_engine_test.dart` if parameterising is awkward.
5. **Fuzz:** `SimWorld(seed, providerFactory: …)` — the factory yields one **shared** `TephraCloudSyncProvider`-per-device (each device has its own `CloudTokenSource` and its own session/device id on the same account/vault, exactly like real devices); the existing `OfflineSwitch` wraps each. `cloud_fuzz_test.dart` (`@Tags(['fuzz'])`): `TEPHRA_FUZZ_OPS` default **1,500** (loopback HTTP is slower than memory), seeds 1, 2, 3; nightly 20,000 ops × 3 seeds (set in 10.21's workflow; if a run exceeds 90 minutes profile the server, do not cut ops below 10,000). Same invariants as 03.12 (no loss, convergence, no forks, integrity, determinism **of client state given the same server responses** — determinism across runs is checked with the memory provider only; for the cloud run the check is "no unexpected exception type"). Failure output prints `FUZZ FAILURE seed=… op=…` and the last 50 ops.
6. **Phase 9 drills against the cloud provider:** (a) `cloud_crash_drill_test.dart`: the 1,000-seed crash-point drill with `TEPHRA_DRILL_SEEDS` default 100 in CI (1,000 locally/nightly); (b) `tool/drill_kill_sync.dart --provider cloud --iterations 200 --seed 1`: the parent starts a `TestServer`-equivalent **real server process** (`dart run server/bin/tephra_server.dart` with `PORT=0`-style free port, temp data dir, dev env), creates the user/vault, hands each child the server URL and its own refresh token via command-line environment (`TEPHRA_DRILL_REFRESH`), kills children with `SIGKILL` as before; pass = 0 failures; (c) `cloud_corruption_test.dart`: the Phase 9 D5 injectors performed **on the server's storage files** (flip a byte in a journal batch file, truncate a blob, replace a batch with another vault's batch, delete a middle batch's storage file and its DB row) → client reports `DamagedRemote` variants exactly as in 09.9 (the ETag check turns at-rest corruption into `TamperedDataException`, which the reader already maps), other devices continue, "skip" and "republish" repair paths work.
7. **Server crash safety** (`cloud_server_crash_test.dart`, tag `slow`): run the server as a child process; a client performs 300 PUTs of random objects while the test kills the server with SIGKILL at random moments (20 kills) and restarts it on the same data dir; after each restart: `db-check` ok; `verify-storage --deep` finds **no live object missing its blob** (orphans allowed, swept later); every PUT that **returned 200** is readable with the right bytes; every PUT that did not return is either absent or complete (never partial); the client's own retry logic completes the interrupted uploads; counters equal the recomputed sums after `repair-counters` is **not** needed (assert equality without repair). Also: disk-full on the server data dir (inject through a failing `BlobStorage`, plus a real small tmpfs/VHD only in the manual procedure of 10.20) → 503 and **no** DB change.
8. `docs/ops/data-safety-cloud.md`: results log (date, seeds, durations, counts) for 3–7.

**Tests / Verify.** `cd server; dart test test/cloud` (defaults); `$env:TEPHRA_FUZZ_OPS='20000'; dart test -t fuzz test/cloud/cloud_fuzz_test.dart` once locally (record duration); `dart run tool/drill_kill_sync.dart --provider cloud --iterations 200 --seed 1`; `$env:TEPHRA_DRILL_SEEDS='1000'; dart test test/cloud/cloud_crash_drill_test.dart`. All results in `docs/ops/data-safety-cloud.md` and `PROGRESS.md`.

**Pitfalls.** A failure is a real bug in the server, the provider or the engine integration: fix it, add the failing seed as a fixed regression test, never loosen an invariant. Keep device clocks (fake) separate from the server clock (injected in `TestServer`); the contract's "server time" rules must hold with both.

---

### 10.15 — App: provider factory, wizard provider choice, sign-up / sign-in / verify / forgot-password

**Purpose.** Let the user pick Tephra Cloud, create or use an account, and continue with the existing Phase 3 wizard pages (password, recovery key, first sync).

**Files.** `app/lib/core/sync/sync_provider_factory.dart`, `app/lib/core/sync/cloud_account_service.dart` (+ `cloud_account_service_impl.dart`), `app/lib/core/sync/cloud_config.dart`, `app/lib/sync_ui/setup/pages/choose_provider_page.dart`, `app/lib/sync_ui/cloud/` (`cloud_sign_up_page.dart`, `cloud_sign_in_page.dart`, `cloud_verify_email_page.dart`, `cloud_forgot_password_page.dart`, `cloud_server_field.dart`, `cloud_error_texts.dart`, `cloud_account_controller.dart`), edits in `app/lib/sync_ui/setup/*` and `app/lib/core/sync/sync_worker*.dart`, `app/lib/l10n/app_en.arb`, tests `app/test/sync_ui/cloud/*_test.dart`, `app/test/core/sync/sync_provider_factory_test.dart`.

**Implementation.**
1. `cloud_config.dart`: `const cloudServerUrlDefault = String.fromEnvironment('TEPHRA_CLOUD_URL');` (add `TEPHRA_CLOUD_URL` to `secrets/release.json` and its example; dev default `http://localhost:8094` **only** when `kDebugMode`, and debug builds may use cleartext to LAN addresses via the debug manifest of 09.6). If the default is empty and no server address was entered, the Tephra Cloud card is shown with "Enter a server address".
2. **`SyncProviderFactory.create(SyncMeta meta, {required AccessTokenSource tokens, …})`** returns the right provider for `meta.providerId` (`gdrive` → Drive, `tephra-cloud` → `TephraCloudSyncProvider`, `memory` for tests); the **worker** receives `providerId` and `serverUrl` in `SyncWorkerArgs` (Phase 3 03.16 item 1) and builds the provider through this factory; the main isolate's token service for `tephra-cloud` is `CloudTokenSource` over `SecureSecretStore` (the worker keeps using the `TokenRequest` proxy; the Android WorkManager task builds its own `CloudTokenSource`, safe thanks to the server grace). `meta` gains keys `cloudServerUrl`, `mirrorProviderId`, `migrationState` (10.17–10.18).
3. **`CloudAccountService`** (app interface): `Future<CloudServerInfo> serverInfo(Uri url)`, `signUp({email, password, deviceName, inviteCode, acceptedTermsVersion})`, `signIn({email, password})`, `signOut()`, `currentAccount()`, `resendVerification()`, `forgotPassword(email)`, `refreshMe()`; the implementation uses `CloudAuthApi` + `CloudTokenSource`; device id = the app-level/vault device id (conventions §6.6, 03.3 item 4); device name from settings.
4. **Wizard changes (Phase 3 03.18):** a new **first page "Choose where to sync"** with two cards — **Tephra Cloud** ("Your notes sync through our server, encrypted on your device first. No Google account needed.") and **Google Drive** ("Your own Drive. Nothing passes through us.") — plus the existing "Back up only" option on the next page as before. Choosing Tephra Cloud routes through: **Account page** (sign in or sign up, below) → **Choose** page (list from `CloudVaultDirectory` or "Create a new remote vault") → password / recovery-key / confirm / unlock pages **unchanged**, except that the "Encrypt (recommended)" toggle is **not shown** for Tephra Cloud (encryption is required; helper text "Tephra Cloud always encrypts your notes on your device.") → first-sync choice → progress → done. `SyncSetupService` is generalised to use `RemoteVaultDirectory` (10.13 item 9) and a `ProviderKind` enum; existing Drive widget tests keep passing.
5. **Account pages** (phone full-screen / desktop 560-dp dialog like the wizard; every page has Back/Cancel):
   - **Sign up:** email, password, confirm password, a **plain-language box** (always visible, `cloudTwoPasswordsExplain`): "Your Tephra account password lets you sign in to our server. Your **vault password** (chosen later) encrypts your notes on this device. We can reset the account password; **nobody can recover the vault password or recovery key**." Terms checkbox "I agree to the Terms of Service and Privacy Policy" with both as links (open `serverInfo.termsUrl/privacyUrl` in the browser; required; sends `acceptedTermsVersion`), invite-code field **only if** `serverInfo.inviteRequired`, collapsed "Advanced: server address" (`CloudServerField`: URL text field, default from config, **Check** button calls `GET /v1/server-info` and shows server name + version + "supports sign-up"; requires `https://` except for `localhost`/`127.0.0.1`/`10.x`/`192.168.x`/`*.local` **in debug builds only**; release builds refuse `http://` with `cloudErrorHttpsRequired` and a hint about Tailscale/Cloudflare Tunnel HTTPS). Password rules shown live (≥ 10 characters, not your email). Button "Create account".
   - **Verify email page** (shown when `emailVerified == false` and the server requires it): "We sent a link to a***@x.com. Open it, then come back." Buttons "Resend email" (60 s cooldown, uses `resendVerification`) and "Use a different account" (sign out); polls `refreshMe()` every 5 s while visible and **continues automatically** when verified; the user can also leave and later return (a `needsAttention` banner `syncEmailNotVerifiedBanner` with the same actions).
   - **Sign in:** email, password, "Forgot password?", "Create account", server field (same collapsed section). Error texts via `cloudErrorText(code, {retryAfter})`: `invalid_credentials` "Email or password is wrong.", `rate_limited` "Too many attempts. Try again in {minutes} minutes.", `email_not_verified` → goes to the verify page, `account_disabled`, `device_limit` "This account is signed in on the maximum number of devices ({n}). Remove one in Tephra on another device, then try again.", `signup_closed`, `invite_invalid`, `email_taken` "An account with this email exists. Sign in instead.", `weak_password` (with the `reason` mapped to `too_short`/`common`/`same_as_email` texts), network errors, server errors, `account_pending_deletion` (shows the cancel-deletion offer: "Your account is scheduled for deletion on {date}. Cancel the deletion?").
   - **Forgot password:** email → always shows "If an account exists for that email, we sent a link. It opens in your browser. Resetting the account password does **not** change your vault password." Link "Back to sign in".
   - Passwords are cleared from controllers/state after use (03.18 Pitfall); fields use autofill hints (`AutofillHints.email`, `password`, `newPassword`) and `obscureText` with a show/hide toggle; 48-dp touch targets on phone.
6. l10n keys (all in `app_en.arb`, with `@` descriptions for placeholders): `syncChooseProviderTitle`, `syncProviderCloudTitle`, `syncProviderCloudBody`, `syncProviderDriveTitle`, `syncProviderDriveBody`, `cloudSignUpTitle`, `cloudSignInTitle`, `cloudEmail`, `cloudPassword`, `cloudPasswordConfirm`, `cloudTwoPasswordsExplain`, `cloudAcceptTerms`, `cloudTermsLink`, `cloudPrivacyLink`, `cloudInviteCode`, `cloudServerAdvanced`, `cloudServerCheck`, `cloudServerOk` (`{name}`, `{version}`), `cloudErrorHttpsRequired`, `cloudCreateAccount`, `cloudSignInButton`, `cloudForgotPassword`, `cloudForgotSent`, `cloudVerifyTitle`, `cloudVerifyBody` (`{email}`), `cloudResend`, `cloudResendIn` (`{seconds}`), `cloudUseOtherAccount`, `cloudErrorInvalidCredentials`, `cloudErrorRateLimited` (`{minutes}`), `cloudErrorEmailTaken`, `cloudErrorWeakTooShort`, `cloudErrorWeakCommon`, `cloudErrorWeakSameAsEmail`, `cloudErrorDeviceLimit` (`{count}`), `cloudErrorSignupClosed`, `cloudErrorInviteInvalid`, `cloudErrorDisabled`, `cloudErrorNetwork`, `cloudErrorServer`, `cloudDeletionScheduled` (`{date}`), `cloudCancelDeletion`, `syncEmailNotVerifiedBanner`, `syncErrorCloudFull`, `syncWarningCloudAlmostFull`, `syncSetupEncryptionRequiredCloud`.

**Tests.** Widget tests with a fake `CloudAccountService` at 400 dp and 1200 dp: provider cards route correctly; sign-up validation (mismatch, short, terms unchecked blocks, invite field only when required, https rule in release mode via an injected `isDebug` flag), success → verify page (auto-continue when the fake reports verified; resend cooldown with a fake clock), every error code shows the right text, forgot-password neutral message, sign-in flow, server field check success/failure, no encryption toggle for Cloud, password fields cleared after submit, wizard continues into the unchanged password/recovery pages. Factory test: each `providerId` returns the right type; unknown id throws. Existing Drive wizard tests still pass.

**Verify.** `flutter test test/sync_ui test/core/sync`. Manual (Windows, dev server from Dev Launcher): choose Tephra Cloud → sign up (dev server prints the verification link in its log, `EMAIL_MODE=log`) → open the link → the app continues → create an encrypted vault → first sync completes → check the server `stats`.

**Pitfalls.** The account password and the vault password are different **and look different in the UI** (different pages, different icons, the explainer box). Never store the account password. Do not let `http://` servers be used in release builds. Never show the invite code or tokens in logs.

---

### 10.16 — App: account, storage usage and devices screens

**Purpose.** Everything a user needs to manage the account after setup.

**Files.** `app/lib/sync_ui/cloud/cloud_account_screen.dart`, `cloud_storage_screen.dart`, `cloud_devices_section.dart`, `cloud_change_password_dialog.dart`, `cloud_delete_account_flow.dart`, `app/lib/sync_ui/providers.dart` (edit), `app/lib/commands/…` registrations (`sync.open-account`, `sync.open-storage`), worker messages `RunGc`, `QueryCloudQuota` in `sync_messages.dart`, l10n keys `cloudAccount*`, `cloudStorage*`, `cloudDevices*`, `cloudDelete*`, tests `app/test/sync_ui/cloud/*`.

**Implementation.**
1. **Settings → Sync & backup** shows, when the provider is Tephra Cloud: an **Account** row (email, server host, verified badge), **Storage** (usage bar + text "412 MB of 1 GB"), **Devices**, **Sign out**, **Delete account**, **Move/Mirror** entries (10.18). Commands `sync.open-account`, `sync.open-storage` (palette).
2. **Storage screen:** data from `GET /v1/me/quota` (worker message, refreshed on open and every 5 minutes while visible; cached value shown with "as of …" when offline): bar (green < 80%, amber 80–95%, red ≥ 95%), "Used / limit", plan name, per-vault list (name, used bytes, objects), "Trash on the server: X (cleared automatically after 30 days)". Buttons: **Clean up now** (sends `RunGc`: runs the 03.23 garbage collection immediately if the lease can be obtained, shows the result `gcDone`), **Back up now**, link to the Backups screen ("Backups use space on your plan too"). Thresholds: ≥ 80% → a non-blocking banner `syncWarningCloudAlmostFull` in the sync panel; 100% → sync status `error` with `syncErrorCloudFull` and the uploads pause (downloads continue — Phase 3 behaviour for `RemoteQuotaExceededException`).
3. **Devices section** (extends 03.19 devices screen): when the provider is Cloud, merge the Phase 3 remote device list with `GET /v1/me/devices` by `deviceId`; show last seen from the server; "Remove" performs, in order: Phase 3 `DeviceRegistry.revoke(targetId, lastAcceptedSeq)` (writes the revocation file), then `DELETE /v1/me/devices/{deviceId}` (kills the token); removing **this** device = sign out. A removed device shows the Phase 3 `DeviceRevokedException` banner and the Cloud sign-in is refused (`session_revoked`).
4. **Change password dialog:** old password, new password, confirm; explainer "This changes your Tephra **account** password only." On success all other devices must sign in again (the server revoked their sessions): show that text; this device's tokens are replaced with the new session returned by a follow-up `login` (the server keeps the current session; no re-login needed — implement per the server: `change-password` revokes **other** sessions, the current stays valid).
5. **Delete account flow:** page 1 explains exactly: "This permanently deletes your Tephra Cloud account and all synced data stored on our server after a 7-day grace period. Your notes **on your devices are not touched.** Backups on our side are removed within 30 days after that. You can cancel by signing in during the 7 days." Requires typing the account password and ticking "I understand". Calls `DELETE /v1/me`, then: stop sync (`mode = off`), delete cloud tokens, keep the local vault and the master key entry (user can still choose Drive or another account later), show confirmation with the deletion date. Signing in again during the grace shows the "cancel deletion" offer (10.15).
6. **Sign out:** stops the worker, deletes tokens (not the master key), sets status `needsAttention` "Sign in to Tephra Cloud to resume sync" with a **Sign in** button running the account pages only (no vault password needed, like Drive reconnect 03.18 item 4); a different account than before → error `cloudErrorDifferentAccount` ("This vault belongs to another account"), detected because `GET /v1/vaults/{id}` returns 404.
7. Status-panel integration: `SyncUiState.needsAttention` reasons for Cloud: `emailNotVerified`, `signedOut`, `deviceLimit`, `accountDeletion`, `vaultMissing`; each has its own banner text and action.

**Tests.** Widget tests (both widths) with fake services: storage thresholds and colours; offline cached value; Clean up now message; device merge and removal order (revocation file first, then server); change-password flows and error texts; delete flow requires password + checkbox, calls the API once, disables sync, keeps local files; sign-out/sign-in with the same and with a different account; banners per reason.

**Verify.** `flutter test test/sync_ui`. Manual: with the dev server, set a 5 MB quota (`tephra-admin set-quota`), sync a 10 MB vault → "Tephra Cloud is full", downloads continue; raise the quota → resumes; remove a second device → it is signed out within ~60 s.

**Pitfalls.** The server trash is not user-visible; do not promise "restore from server". Never offer an "export" that implies the server holds readable data.

---

### 10.17 — Migration engine: copy key-for-key, verify, switch (pure Dart)

**Purpose.** Move an existing Drive vault to Tephra Cloud **without decrypting or re-encrypting anything**, with proof of zero differences. This is the Phase 3 hand-off item 2 made concrete.

**Files.** `packages/tephra_sync/lib/src/migration/vault_migrator.dart`, `migration_models.dart` (`MigrationPhase`, `MigrationProgress`, `MigrationReport`, `MigrationFailure`), `migration_verifier.dart`, `migration_switch.dart`, `remote_copier.dart` (shared with the mirror, 10.18), `moved_to.dart`; edits `remote_vault_manager.dart` (`setMovedTo`), `vault_header.dart` (`MovedTo? movedTo` accessor over the preserved unknown fields); tests `packages/tephra_sync/test/migration/*_test.dart`.

**Implementation.**
1. **`MovedTo`** (public marker stored in the **source** `vault.json` as the unknown field `"movedTo"`, preserved by every reader/writer per 03.6): `{ "state": "migrating" | "moved", "provider": "tephra-cloud", "serverUrl": "https://…", "vaultId": "<same remote vault id>", "at": "<ISO>" }`. `RemoteVaultManager.setMovedTo(VaultHeader h, MovedTo? m)` rewrites `vault.json` **preserving all other fields byte-for-byte semantics** (parse → set/remove the one key → re-serialise with 2-space indent) and updates `updatedAt`; `null` removes the key (cancel).
2. **`RemoteCopier`** (reusable): `copy({required SyncProvider from, required SyncProvider to, required Set<String> skipPrefixes, required CopyMode mode, concurrency = 4, cancel})` where `CopyMode.fullMigration` / `CopyMode.incrementalMirror`; returns `CopyResult { copied, skipped, bytes, failures, Map<String,String> sha256ByKey }`. **Key rules:**
   - Source listing: `from.list('')`; **skip `locks/`** entirely (GC leases and GC state are transient; the destination starts with none; document that the next GC run recreates them).
   - Order: `blobs/` → `snapshots/` → `backups/` → `devices/` → `journals/` → any other keys → **`vault.json` last** (a half-copied vault has no header and is therefore invisible to listings, exactly like a half-created vault in 03.6). The header copied to the destination is the source header **with `movedTo` removed**; every other byte of content is unchanged.
   - For each key: `blobs/<hash>`: skip if the destination already has the key with the same size (the Cloud server **verifies blob hash = key on every PUT**, so an existing same-size blob is valid by construction); every other key: `put` unconditionally (idempotent: for immutable classes the server answers `200` for identical bytes and `409` for different bytes — a `409 immutable_key` means the destination vault already contains **different** data under that key: stop with `MigrationFailure.destinationNotEmpty` and change nothing further).
   - Download from the source with the source provider's `get` (already hash-verified for blobs by `BlobStore`? no — the copier verifies `contentHash(bytes) == hash in the blob key` itself before putting; a mismatch is a source-corruption finding recorded in the report and **that key is not copied** — migration continues, the final report is "completed with N damaged source objects" and the human is told; Phase 9's repair tools apply).
   - Record `sha256ByKey[key] = contentHash(bytes)` for every copied key (used by verification).
   - Concurrency via a semaphore (4 by default, 8 maximum); progress events at most every 200 ms; cancellation checked between keys; per-key failures after the providers' own retries are collected (`failures`) and the copy continues; a final `retryFailed()` pass runs automatically once.
3. **`VaultMigrator.run()` phases** (each emits `MigrationProgress{phase, filesDone, filesTotal, bytesDone, bytesTotal, currentKey?, failures}`):
   1. **preflight:** source header must be `encryption != none` (else `MigrationFailure.plaintextVault` — "Tephra Cloud requires an encrypted vault"; offer in the UI to create a new encrypted Cloud vault from the local files instead); `target.connect()` (the vault exists — created by the UI via `CloudVaultDirectory.createRemoteVault(sameVaultId)`); quota: `sum(sizes)` (blobs not yet at the destination) vs `target.quota()` → `MigrationFailure.notEnoughSpace(required, free)`; no **live GC lease** in the source (`list('locks/')` with `modified` < 30 minutes old → `MigrationFailure.gcInProgress`); the caller guarantees this device has just run a successful `syncOnce` and then **paused** its engine.
   2. **announce:** `setMovedTo(state: migrating)` on the source header (other devices pause, 10.18). If this fails, abort before copying.
   3. **copy** (full migration pass).
   4. **settle:** wait `settleDelay` (45 s; tests inject zero), re-list the source, copy anything new or changed (non-blob keys whose size or `modified` differs from the first listing; new blobs); repeat up to **3** passes until a pass copies nothing.
   5. **verify (structural):** list the destination; every copied key exists with the **same size**; every **non-blob** key (journals, snapshots, backups, devices, `vault.json`) is downloaded from the destination and its SHA-256 equals `sha256ByKey`; for blobs: existence + size for all, and a **random 5% sample (min 20, max 500)** is re-downloaded and hash-checked against its key. Any difference → `MigrationFailure.verificationFailed(keys)` and **no switch**.
   6. **verify (semantic):** `MigrationVerifier.verify(...)` (item 4) must report **zero differences**.
   7. **finalise:** `setMovedTo(state: moved)` on the source header; write `migration-report.json` (counts, bytes, duration per phase, skipped, damaged, pass count, verification sample size) to the app support dir; return `MigrationReport`. **The caller then applies `MigrationSwitch`** (item 5).
   Any failure after step 2 calls `setMovedTo(null)` (best-effort) so other devices resume; a crash leaves `migrating` in place and the next launch offers **Resume** (`meta.migrationState` records `{state, sourceProviderId, targetUrl, vaultId, startedAt}`) or **Cancel** (removes the marker).
4. **`MigrationVerifier`** (pure, uses the Phase 3 classes): inputs: `source`, `target`, `cipher` (the vault's `EncryptingObjectCipher`), the device's `VaultFileSystem` + `SyncStateStore` (read-only). (a) **History equality:** two scratch in-memory `SyncStateStore`s; run `JournalReader.refresh` (and snapshot bootstrap) against the source and against the target; build `RemoteHistory` for each; compare `heads()` (path → entry id + hash + is_fork) and the set of all entry ids; **any difference is reported**. (b) **Plan equality:** scan the local vault (`LocalScanner`) and run `Planner.plan` twice with the device's real base — once with the source history, once with the target history; the two plans (`actions`, `baseUpdates`, `heldDeletes`) must be **equal**; additionally, if the device was fully synced before the migration, both plans must contain **no actions** (report as "pending local changes: N" otherwise — informative, not a failure). (c) **Content sample:** download and decrypt 100 random head blobs (all of them if fewer) **from the target**, verify `contentHash(plain) == entry.hash`. Output `VerificationReport{differences: List<Difference>, sampled: n}`; gate = `differences.isEmpty`.
5. **`MigrationSwitch.apply(SyncStateStore, {serverUrl, keepDriveAsMirror})`** — one transaction: `meta.providerId = 'tephra-cloud'`, `meta.cloudServerUrl`, `meta.changesCursor = null`, delete all `remote_file_ids` rows (Drive file ids are meaningless now), `meta.mirrorProviderId = keepDriveAsMirror ? 'gdrive' : ''`, `meta.migrationState = ''`; **keep** `synced_files`, `bases`, `remote_entries`, `remote_heads`, `journal_cursors`, `blob_index` and `nextSeq` (identical keys and seqs on both remotes ⇒ the device continues exactly where it was; `blob_index.seen_at` is reset to 0 so reuse is re-confirmed against the new remote). The master key entry (`tephra.sync.<remoteVaultId>.masterKey`) is unchanged because the remote vault id is unchanged. The worker is restarted afterwards and the first cycle (`SyncTrigger.setup`) must produce **no actions**.
6. Memory/time: objects are processed one at a time per slot (`List<int>` per object ≤ a few MiB; manifests/snapshots up to tens of MiB); with concurrency 4 the peak is bounded (< 150 MB for the 10k-note vault); run in the sync worker isolate.

**Tests.** Memory-to-memory with the simulator: build a 3-device history (2,000 random ops) on `MemorySyncProvider` A, migrate to `MemorySyncProvider` B → `list('')` of B equals A's minus `locks/` (keys, sizes, bytes), header has no `movedTo`, verifier reports zero differences, plan equality holds, a **fresh device** bootstrapping from B reaches identical heads; resume after a crash injected at 20 random points (state machine restarts and finishes; final B identical); second run on a complete B copies nothing (blobs skipped; non-blobs re-put idempotently); destination containing a **different** journal under the same key → `destinationNotEmpty`; corrupted source blob (flipped byte) → not copied, reported, run completes; settle pass picks up a journal written by another device during the copy; GC lease present → `gcInProgress`; plaintext vault → refused; quota too small → `notEnoughSpace`; cancel mid-copy → `movedTo` removed; `setMovedTo` preserves unknown header fields; switch keeps cursors and the planner's first cycle on B produces no actions; against the **real test server** (`server/test/cloud/migration_test.dart`): Drive-fake-server (Phase 3 `FakeDriveServer`, i.e. `DriveSyncProvider`) → Cloud for a 1,500-note vault with 3 devices, run verifier → zero differences; time and memory recorded.

**Verify.** `dart test test/migration` in `tephra_sync`; `dart test test/cloud/migration_test.dart` in `server`.

**Pitfalls.** **Never decrypt for the copy** (the copier moves opaque bytes; only the verifier decrypts, read-only, with the vault's own cipher). `vault.json` must be last. Do not copy `locks/`. Do not delete anything on the Drive side, ever (the Drive copy is the user's fallback). Do not run migration while this device's engine is syncing (the UI pauses and awaits the current cycle).

---

### 10.18 — Migration UI, other devices, Drive mirror, emergency return

**Purpose.** The user-facing "Move vault from Google Drive to Tephra Cloud", what other devices do, and "keep Drive as an extra off-site backup".

**Files.** `app/lib/sync_ui/migrate/move_to_cloud_wizard.dart` (+ `pages/`), `move_to_cloud_controller.dart`, `app/lib/sync_ui/migrate/switch_device_flow.dart`, `app/lib/sync_ui/migrate/mirror_settings.dart`, `packages/tephra_sync/lib/src/migration/mirror_service.dart`, `…/engine/remote_header_watcher.dart`, worker messages `StartMigration`, `CancelMigration`, `ResumeMigration`, `ApplyMovedTo`, `RunMirrorNow`, `SwitchToCloud`, l10n keys `moveCloud*`, `mirror*`, tests mirror.

**Implementation.**
1. **Entry:** Settings → Sync & backup → **"Move to Tephra Cloud"** (visible when `providerId == 'gdrive'` and the vault is encrypted) and the command `sync.move-to-cloud`.
2. **Wizard pages:** (1) *What will happen* — plain language: "Your vault will be copied to Tephra Cloud exactly as it is (still encrypted; nothing is decrypted or changed). Your Google Drive copy is **not** touched. Other devices will ask you to switch. Needs about {size} of Cloud storage and roughly {minutes} minutes." (the estimate = bytes ÷ the throughput measured in the last sync, default 2 MB/s); a checklist: "Sync is up to date on this device" (the wizard runs `syncOnce` and shows the result), "Your other devices are online or you will switch them later". (2) *Account* — the Phase 10.15 account pages (sign in/up). (3) *Space check* — required vs free from `GET /v1/me/quota`; if not enough → shows both numbers and stops (link to Storage). (4) *Options* — switch "Keep Google Drive as an extra off-site backup (recommended)" default **on** (explains: a daily copy of the encrypted data is written to Drive; it uses your Drive space; you can stop any time). (5) *Progress* — phases from `MigrationProgress` (Preparing → Copying 1,234 of 5,678 files · 120 MB of 900 MB → Checking → Verifying → Switching), cancel button (confirms; cancelling removes the marker and leaves Drive as the active provider), "Run in background" (the status indicator shows it). (6) *Done* — the report: "Copied N files (X MB). Verified: 0 differences." plus "On your other devices, open Tephra and tap **Switch to Tephra Cloud**; sign in with the same account `<email>`." and, if mirror is on, "Drive stays updated daily."
3. **Execution order** (controller, in the worker): pause engine after a final successful `syncOnce` → `CloudVaultDirectory.createRemoteVault(vaultId = remote vault id, name)` → `VaultMigrator.run` → `MigrationSwitch.apply` → restart the worker with the Cloud provider → first cycle must report zero actions (assert; if not, show "Check completed with {n} pending changes", informational) → register a Cloud device heartbeat (`DeviceRegistry.heartbeat`).
4. **Other devices** (`RemoteHeaderWatcher` in the worker, runs when `vault.json` appears in `changesSince`, at app start and on resume): `state = migrating` → engine paused with reason `vaultMigrating` (status `paused`, banner "This vault is being moved to Tephra Cloud. Sync is paused."); the pause lifts automatically when the marker disappears (cancelled) or becomes `moved`; `state = moved` → status `needsAttention` with the **Switch to Tephra Cloud** action. **Switch flow** (`SwitchDeviceFlow`): explanation → Cloud sign-in (must be the **same account**; if `GET /v1/vaults/{id}` returns 404 → `cloudErrorDifferentAccount`: "This vault belongs to a different account. Sign in with the account you used on the device that moved it." — the marker deliberately contains no email address) → verify the remote header (`vaultId` equal, `format` ok) → `CloudVaultDirectory.providerFor` → `connect()` → `MigrationSwitch.apply` → restart worker → first cycle, expected **no actions** (any local-only changes simply upload as normal edits). No password is asked (master key stays).
5. **Mirror** (`MirrorService`, package): `run(SyncProvider primary, SyncProvider mirror)` uses `RemoteCopier(mode: incrementalMirror, skipPrefixes: {'locks/'})` primary → Drive daily (the worker's schedule check, only on an unmetered network, Windows or Android-charging, same conditions as GC 03.23 item 1), **never deletes anything on the mirror**, writes `vault.json` to the mirror **with `movedTo.state = "moved"` kept** (so a device still pointed at Drive keeps seeing the marker and does not resume writing there), records `meta.lastMirrorAt` and a result line in the sync log (`mirror: N objects, X MB`). A mirror failure never affects primary sync (status shows a small warning). Settings → Sync & backup → **Drive backup** page: on/off, last run, "Run now", "Stop and forget Drive" (disconnects the Drive provider; Drive files stay).
6. **Emergency return** ("Use the Drive copy instead", in the same page, behind a confirmation that says the Drive copy may be missing the most recent changes by up to a day): removes `movedTo` from the Drive header, `MigrationSwitch.apply`-like switch of `providerId` back to `gdrive` (cursors kept; the first cycle reconciles — Phase 3 guarantees no loss; any missing newer journals from Cloud are re-uploaded because the local base is ahead, as normal), and signs the vault out of Cloud sync (account untouched). Documented as the supported "undo".
7. **Failure notes for users** (`moveCloudErrorPlaintext`, `moveCloudErrorNoSpace`, `moveCloudErrorGcRunning`, `moveCloudErrorDamaged` (`{count}`), `moveCloudErrorVerify`, `moveCloudErrorNetwork` with **Resume**): every error keeps Drive active and untouched.

**Tests.** Widget tests (both widths) with fakes: wizard happy path; each failure page; cancel restores the marker removal call; resume offered after a simulated app restart; other-device flows (`migrating` pauses, `moved` offers Switch, same-account success, different-account error, cancel un-pauses); mirror schedule conditions with a fake clock; mirror never calls `delete`; emergency return switches back and removes the marker. Package tests for `MirrorService` (incremental runs copy only new keys; header keeps `moved`) and `RemoteHeaderWatcher` (marker parsing from the preserved unknown field; absent marker; malformed marker ignored).

**Verify.** `flutter test test/sync_ui/migrate`; `dart test` in `tephra_sync`. Manual (PC + phone, small test vault first): move, switch the phone, edit on both, see it sync via Cloud; confirm Drive unchanged except the marker/mirror; try cancel at 50%; try emergency return.

**Pitfalls.** The marker is advisory: a device on an old app version ignores unknown header fields and keeps writing to Drive — the final verification pass runs after the `settle` delay, but a late old-version write is possible; the report therefore shows "Drive changed after the copy: N objects" if the **last** listing before `moved` differs from the final one, and the migrator makes one more incremental pass when it sees that (max 3). Old app versions cannot be forced to switch; the FAQ says "update all devices before moving". Never delete Drive data.

---
### 10.19 — Container image, docker-compose with Caddy (automatic HTTPS), staging beside production

**Purpose.** Reproducible deployment: one multi-stage image, a Caddy front door with automatic certificates, production and staging on one VPS. Needs **H1**, **H2** (SMTP) and **H6** (Docker, or CI builds).

**Files.** `server/Dockerfile`, `.dockerignore`, `deploy/pubspec.docker.yaml`, `deploy/compose.yml`, `deploy/Caddyfile`, `deploy/server.env.example`, `deploy/server.staging.env.example`, `deploy/compose.selfhost.yml` (10.21), `server/bin/tephra_server.dart` (edit: `--healthcheck` flag), `server/tool/soak_agent.dart` (10.23), `docs/ops/deploy.md`, tests `server/test/healthcheck_flag_test.dart`.

**Implementation.**
1. **Why a separate pubspec:** the repository root `pubspec.yaml` is a workspace that also lists the Flutter `app`; `dart pub get` inside a Dart-only image cannot resolve it. `deploy/pubspec.docker.yaml` is a **trimmed workspace root** (`name: tephra_docker_workspace`, `publish_to: none`, `environment: sdk: ^3.13.0`, `workspace:` = `packages/tephra_core`, `packages/tephra_vault`, `packages/tephra_sync`, `server`). The image build copies it over the root `pubspec.yaml`. A test in `tool/test/` asserts that every `package:tephra_*` and external dependency reachable from `server/pubspec.yaml` is satisfiable by that member list (parse the pubspecs; fail if `server` or `tephra_sync` ever depends on a workspace member missing from it, or on Flutter).
2. **`server/Dockerfile`** (build context = **repository root**: `docker build -f server/Dockerfile -t tephra-server:2.0.0 .`):
   ```dockerfile
   # syntax=docker/dockerfile:1
   FROM dart:3.13.5 AS build          # verify this tag exists on Docker Hub; otherwise use the nearest dart:3.13.x tag
   WORKDIR /src
   COPY deploy/pubspec.docker.yaml pubspec.yaml
   COPY analysis_options.yaml ./
   COPY packages/tephra_core packages/tephra_core
   COPY packages/tephra_vault packages/tephra_vault
   COPY packages/tephra_sync packages/tephra_sync
   COPY server server
   RUN dart pub get
   RUN mkdir -p /out \
    && dart compile exe server/bin/tephra_server.dart -o /out/tephra-server \
    && dart compile exe server/bin/tephra_admin.dart  -o /out/tephra-admin \
    && dart compile exe server/tool/soak_agent.dart   -o /out/tephra-soak

   FROM debian:bookworm-slim
   RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libsqlite3-0 tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --home-dir /data --shell /usr/sbin/nologin tephra \
    && mkdir -p /data && chown 10001:10001 /data
   COPY --from=build /out/ /app/
   USER 10001:10001
   ENV PORT=8094 HOST=0.0.0.0 DATA_DIR=/data TEPHRA_ENV=production TRUST_PROXY=true
   EXPOSE 8094
   VOLUME ["/data"]
   HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD ["/app/tephra-server", "--healthcheck"]
   ENTRYPOINT ["/usr/bin/tini", "--", "/app/tephra-server"]
   ```
   Drop the `libsqlite3-0` line only if the installed `sqlite3` package version bundles SQLite (its README says how; test the image either way). `--healthcheck` makes the **same binary** perform `GET http://127.0.0.1:$PORT/health` (no curl in the image), exit 0 on `200`, 1 otherwise. `.dockerignore` excludes `.git`, `app/`, `build/`, `**/.dart_tool/`, `secrets/`, `test_vaults/`, `.data/`, `dist/`, `docs/`. Expected image size < 150 MB; run a scan note in `deploy.md` (`docker scout quickview` if available — optional).
3. **`deploy/compose.yml`** (Compose v2; production and staging as **two services behind one Caddy**):
   ```yaml
   name: tephra
   services:
     tephra:
       image: tephra-server:${TEPHRA_VERSION:-2.0.0}
       restart: unless-stopped
       env_file: ./server.env
       volumes: ["/srv/tephra/data:/data"]
       read_only: true
       tmpfs: ["/tmp"]
       cap_drop: ["ALL"]
       security_opt: ["no-new-privileges:true"]
       stop_grace_period: 30s
       mem_limit: 1500m
       logging: { driver: json-file, options: { max-size: "10m", max-file: "5" } }
       networks: [web]
     tephra-staging:
       image: tephra-server:${TEPHRA_STAGING_VERSION:-2.0.0}
       restart: unless-stopped
       env_file: ./server.staging.env
       volumes: ["/srv/tephra-staging/data:/data"]
       read_only: true
       tmpfs: ["/tmp"]
       cap_drop: ["ALL"]
       security_opt: ["no-new-privileges:true"]
       stop_grace_period: 30s
       mem_limit: 1g
       logging: { driver: json-file, options: { max-size: "10m", max-file: "5" } }
       networks: [web]
     soak:
       image: tephra-server:${TEPHRA_STAGING_VERSION:-2.0.0}
       profiles: ["soak"]
       restart: unless-stopped
       entrypoint: ["/usr/bin/tini", "--", "/app/tephra-soak"]
       env_file: ./soak.env
       networks: [web]
     caddy:
       image: caddy:2
       restart: unless-stopped
       ports: ["80:80", "443:443", "443:443/udp"]
       environment: { TEPHRA_DOMAIN: "${TEPHRA_DOMAIN}", STAGING_DOMAIN: "${STAGING_DOMAIN}", ACME_EMAIL: "${ACME_EMAIL}" }
       volumes: ["./Caddyfile:/etc/caddy/Caddyfile:ro", "caddy-data:/data", "caddy-config:/config"]
       logging: { driver: json-file, options: { max-size: "10m", max-file: "5" } }
       depends_on: { tephra: { condition: service_healthy } }
       networks: [web]
   volumes: { caddy-data: {}, caddy-config: {} }
   networks: { web: {} }
   ```
   The image's `HEALTHCHECK` makes `service_healthy` work. No application port is published to the host: only Caddy (80/443) is reachable. Data directories are **bind mounts** (`/srv/tephra/data`, `/srv/tephra-staging/data`, owned by uid 10001) so backups and the restore drill work on plain files.
4. **`deploy/Caddyfile`:**
   ```
   {
       email {$ACME_EMAIL}
   }

   {$TEPHRA_DOMAIN} {
       @compressible header Content-Type application/json*
       encode @compressible zstd gzip
       request_body {
           max_size 17MB
       }
       reverse_proxy tephra:8094 {
           flush_interval -1
           transport http {
               response_header_timeout 5m
               read_timeout 10m
               write_timeout 10m
           }
       }
       header {
           Strict-Transport-Security "max-age=31536000; includeSubDomains"
           X-Content-Type-Options "nosniff"
           -Server
       }
       log {
           output stdout
           format json
       }
   }

   {$STAGING_DOMAIN} {
       request_body {
           max_size 17MB
       }
       reverse_proxy tephra-staging:8094 {
           flush_interval -1
       }
       header {
           X-Robots-Tag "noindex"
           -Server
       }
       log {
           output stdout
           format json
       }
   }
   ```
   WebSockets pass through `reverse_proxy` automatically; `flush_interval -1` disables response buffering. Caddy appends the real client IP to `X-Forwarded-For` (it does not trust client-supplied values by default), which is why the server takes the **last** value (10.10). Caddy logs contain client IPs: Docker log rotation (5 × 10 MB) bounds the retention, and the privacy policy says so (10.22). Re-read Caddy's current docs for the exact `request_body`/`transport` directive names before relying on them.
5. **Env templates** `deploy/server.env.example` (copied to `/opt/tephra/server.env`, `chmod 600`, edited **by the human**):
   ```
   TEPHRA_ENV=production
   PUBLIC_URL=https://cloud.example.com
   JWT_SECRET=REPLACE_WITH_OUTPUT_OF__tephra-admin gen-secret
   SIGNUP_ENABLED=true
   SIGNUP_INVITE_CODE=REPLACE_OR_EMPTY
   EMAIL_VERIFICATION_REQUIRED=true
   EMAIL_MODE=smtp
   SMTP_HOST=REPLACE
   SMTP_PORT=587
   SMTP_SECURITY=starttls
   SMTP_USER=REPLACE
   SMTP_PASSWORD=REPLACE
   SMTP_FROM=Tephra <no-reply@example.com>
   METRICS_TOKEN=REPLACE_WITH_RANDOM_32_CHARS
   TRUST_PROXY=true
   PLAN_FREE_STORAGE_BYTES=1073741824
   ```
   The staging file differs by `PUBLIC_URL`, a **different** `JWT_SECRET`, `SIGNUP_INVITE_CODE` always set, `ACCOUNT_DELETION_GRACE_DAYS=0` (so the deletion path can be tested end-to-end), and `TEPHRA_ENV=staging`. `soak.env.example`: `SOAK_SERVER_URL`, `SOAK_EMAIL`, `SOAK_PASSWORD`, `SOAK_INVITE_CODE`.
6. `docs/ops/deploy.md`: build and ship the image — **Option 1 (default):** `docker build …` on the dev PC (needs Docker, H6) or in CI (10.21), then `docker save tephra-server:2.0.0 | gzip > dist/tephra-server-2.0.0.tar.gz`, copy with `scp`, on the VPS `gunzip -c tephra-server-2.0.0.tar.gz | docker load`; **Option 2:** push to GitHub Container Registry (private; the VPS logs in with a read-only token) if the human prefers. Upgrade procedure: (1) take a backup now (10.20); (2) load the new image; (3) set `TEPHRA_VERSION`; (4) `docker compose up -d tephra` (the server runs migrations at start with the pre-migrate backup of 10.3); (5) `curl -fsS https://cloud.<domain>/ready`; (6) watch `docker compose logs -f --since 5m tephra` for `severe`; **rollback:** set the previous `TEPHRA_VERSION`, `docker compose up -d tephra`; if the new version migrated the DB, first restore `<DATA_DIR>/backups/pre-migrate-*.sqlite` over `tephra.sqlite` (stop the container, copy, `tephra-admin bump-epoch`, start). A restart takes ~5 s; clients reconnect automatically (10.13).

**Tests.** `healthcheck_flag_test.dart`: the flag exits 0 against a running `TestServer` and 1 against a closed port; the pubspec-closure test above; `docker build` succeeds locally (if Docker is available; otherwise in CI) and `docker run --rm -e TEPHRA_ENV=dev -p 8094:8094 tephra-server:2.0.0` answers `/health`; `docker run --read-only` works; the container runs as uid 10001 (`docker run --rm --entrypoint id tephra-server:2.0.0`).

**Verify.** Build the image; `docker compose -f deploy/compose.yml config` validates (with the env files copied from the examples into a temp folder); local smoke: run the image with a temp volume, sign up with `curl` (dev env), PUT/GET an object.

**Pitfalls.** The image must never contain secrets or `app/`. Do not publish 8094 on the host in production. `read_only: true` requires the data volume and `/tmp` tmpfs to be the only writable paths (verified by the smoke test). Keep `stop_grace_period` ≥ `SHUTDOWN_GRACE_SECONDS` + 10.

---

### 10.20 — VPS runbook, hardening, off-site backups, monitoring, **restore drill**

**Purpose.** A server a stranger could rebuild from the docs, with proven backups. Needs **H1, H2, H4, H5**.

**Files.** `docs/ops/vps-setup.md`, `docs/ops/hardening.md`, `docs/ops/backup.md`, `docs/ops/monitoring.md`, `docs/ops/restore-drill.md` (procedure) and `docs/ops/restore-drill-<date>.md` (the **recorded result**), `docs/ops/capacity.md`, `docs/ops/runbook.md`, `deploy/backup/run-backup.sh`, `deploy/backup/check-host.sh`, `deploy/backup/tephra-backup.service`, `deploy/backup/tephra-backup.timer`, `deploy/backup/tephra-hostcheck.service`, `deploy/backup/tephra-hostcheck.timer`, `deploy/backup.env.example`, `server/tool/restore_check.dart`.

**Implementation.**
1. **`vps-setup.md`** (commands for Ubuntu 24.04; Gemini writes them, the human runs them or says "go" for read-only checks over SSH): (a) `ssh root@<ip>`; `apt update && apt -y upgrade`; create the operator user `adduser tephra` + `usermod -aG sudo tephra`; copy the SSH key (`install -d -m 700 -o tephra -g tephra /home/tephra/.ssh` + the authorized_keys); (b) **hardening** (`hardening.md`): `/etc/ssh/sshd_config.d/10-tephra.conf` with `PasswordAuthentication no`, `PermitRootLogin no`, `MaxAuthTries 3`; `systemctl reload ssh`; test a **second** SSH session before closing the first; firewall `ufw default deny incoming; ufw default allow outgoing; ufw limit OpenSSH; ufw allow 80/tcp; ufw allow 443/tcp; ufw allow 443/udp; ufw enable`; `apt install unattended-upgrades` and enable security updates; time sync `timedatectl set-ntp true` and verify `timedatectl status` says "System clock synchronized: yes" (**JWT expiry and GC leases depend on correct server time**); a 2 GB swap file; `docker` from Docker's official apt repository (`docker-ce`, `docker-compose-plugin`), `usermod -aG docker tephra`; `/etc/docker/daemon.json` with `{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"5"},"live-restore":true}`; **no** public Docker API; **do not** install fail2ban or other tools beyond `restic` and `curl` (keep the surface small; `ufw limit` covers SSH brute force). (c) directories: `install -d -o 10001 -g 10001 -m 750 /srv/tephra/data /srv/tephra-staging/data`; `install -d -m 750 -o tephra /opt/tephra`; copy `compose.yml`, `Caddyfile`, env files; `chmod 600 /opt/tephra/*.env`. (d) `docker load` the image; `docker compose up -d`; check Caddy obtained certificates (`docker compose logs caddy | grep -i certificate`), then `curl -fsS https://cloud.<domain>/ready`. (e) create the first admin-owned account: `docker compose exec tephra /app/tephra-admin create-user --email <you> --verified --plan pro` (password prompt). (f) `docs/ops/capacity.md`: sizing table (users × quota vs disk; e.g. 80 GB disk ≈ 60 full free accounts; when to attach a volume or move blobs to S3: `STORAGE_BACKEND=s3`), the Argon2id single-hash time (10.5), the measured load-test numbers (10.23).
2. **Backups (`backup.md` + scripts).** Decision: **restic** (BSD-2-Clause, encrypted, deduplicated) to the S3-compatible bucket from **H4**; data = a consistent DB snapshot + the blob directory; **RPO 24 h, target RTO 2 h**. `deploy/backup.env.example`: `RESTIC_REPOSITORY=s3:https://<endpoint>/<bucket>/prod`, `RESTIC_PASSWORD=REPLACE`, `AWS_ACCESS_KEY_ID=REPLACE`, `AWS_SECRET_ACCESS_KEY=REPLACE`, `HC_BACKUP_URL=REPLACE`, `HC_HOST_URL=REPLACE`. `run-backup.sh` (bash, `set -euo pipefail`, shellcheck-clean; written with the file tool, **not** a heredoc):
   1. `trap` → on any error ping `$HC_BACKUP_URL/fail` and exit non-zero; at start ping `$HC_BACKUP_URL/start`.
   2. `docker compose -f /opt/tephra/compose.yml exec -T tephra /app/tephra-admin backup --to /data/backup-staging` (a `VACUUM INTO` snapshot + `.sha256`; the live DB files are **never** copied directly).
   3. `restic backup /srv/tephra/data/blobs /srv/tephra/data/backup-staging --tag daily --host tephra-prod` (`tmp/`, `*.sqlite-wal`, `*.sqlite-shm`, `epoch.state` are **not** included).
   4. Delete staged snapshots older than 2 days; **weekly (Sunday)** `restic forget --keep-daily 7 --keep-weekly 4 --prune` (retention ≈ 4 weeks, which is what the privacy policy says: "removed from backups within 35 days") and `restic check --read-data-subset=5%`.
   5. Ping `$HC_BACKUP_URL` on success. Staging is backed up the same way with `--tag staging` into the `staging` prefix, weekly only.
   `tephra-backup.timer`: `OnCalendar=*-*-* 03:15:00 UTC`, `Persistent=true`, `RandomizedDelaySec=300`; `.service`: `Type=oneshot`, `EnvironmentFile=/opt/tephra/backup.env`, `ExecStart=/opt/tephra/backup/run-backup.sh`, `User=tephra`. Install with `systemctl enable --now tephra-backup.timer`; test once by hand (`systemctl start tephra-backup.service`) and show `restic snapshots`.
3. **Monitoring (`monitoring.md`).** (a) External uptime monitor (H5) checks `https://cloud.<domain>/ready` every 5 minutes (alert after 2 failures; keyword `"db":"ok"`) and `/ready` of staging; (b) Healthchecks.io **dead-man's switch** for the backup job (expected daily; grace 3 hours) and for `check-host.sh`; (c) `check-host.sh` (every 15 minutes via `tephra-hostcheck.timer`) pings `$HC_HOST_URL` on success and `…/fail` with the reason if: disk usage of `/srv` > 80%; free memory < 150 MB; a Tephra container's `RestartCount` increased since the last run; the TLS certificate expires in < 14 days (`echo | openssl s_client -connect cloud.<domain>:443 -servername cloud.<domain> 2>/dev/null | openssl x509 -noout -enddate`); `/metrics` unreachable; `tephra_integrity_errors_total` > 0; (d) log review command in the runbook: `docker compose logs --since 24h tephra | grep '"level":"SEVERE"'` (expected: none); (e) alert contacts and what each alert means with first-response steps in `runbook.md` (service down, backup missed, disk high, certificate, integrity error → `tephra-admin verify-storage --deep`, suspected abuse → `tephra-admin disable-user`, compromised JWT secret → rotate: set new `JWT_SECRET`, old into `JWT_SECRET_PREVIOUS`, restart, remove the old one after 20 minutes (all access tokens expire in 15 minutes)).
4. **The restore drill (mandatory; `docs/ops/restore-drill.md`, run it and record the result in `restore-drill-<date>.md` with timings).** Run it on a **scratch location** (a temporary second VPS, or the staging directory on the VPS, or Docker Desktop on the dev PC — H6):
   1. Record `T0`. Pick the newest `restic snapshots` entry; `restic restore latest --tag daily --host tephra-prod --target /srv/restore-test`.
   2. Verify the DB snapshot checksum (`sha256sum -c`), then place it as `<restore>/data/tephra.sqlite` and `blobs/` as `<restore>/data/blobs`.
   3. Start a **separate** server container on another port (`docker run --rm -p 9094:8094 -v /srv/restore-test/data:/data -e TEPHRA_ENV=staging -e PUBLIC_URL=http://127.0.0.1:9094 -e JWT_SECRET=<a throw-away secret> -e EMAIL_MODE=log … tephra-server:2.0.0`), run `tephra-admin db-check` and **`tephra-admin bump-epoch`** (**mandatory**: invalidates every client cursor so clients do a full re-list instead of missing changes, 10.9).
   4. `tephra-admin verify-storage --deep` → exit 0 (every live object present, sizes and hashes right; blobs' keys equal their hashes).
   5. **Client-level proof:** `dart run server/tool/restore_check.dart --server http://127.0.0.1:9094 --email <test user> --password <…> --vault <vaultId> --vault-dir <copy of the real test vault folder> --master-key-file <file>`: logs in (the throw-away `JWT_SECRET` does not matter because sessions are issued fresh; refresh tokens survive because they live in the DB — also test that an **old refresh token still works** and its access token is signed with the new secret), runs a `JournalReader` refresh + `Planner` dry run against the restored remote with the local vault, and prints: number of entries, heads, **planned actions (expected 0)** and a 50-blob sample download+decrypt check. Exit 0 only if zero differences.
   6. Record `T1` (RTO = `T1 − T0`; target ≤ 2 h) and the snapshot age (RPO ≤ 24 h). Delete the scratch data. Write down anything that surprised you and fix the docs.
   Repeat the drill after any change to the backup scripts and **every quarter** (calendar reminder in `runbook.md`).
5. **Data-safety on the real VPS** (also recorded): fill the data volume to 95% in staging (`fallocate -l …`) → PUTs get `503`, reads still work, no corruption, recovery after freeing; `docker kill -s KILL` of the staging container during the soak (10.23) → clean recovery; `docker compose restart` → clients reconnect.

**Tests.** `server/tool/restore_check.dart` has a unit test that runs it against a `TestServer` with a freshly created vault (exit 0) and against a server whose journal file was deleted (exit 1). Shell scripts: `shellcheck` clean (`docker run --rm -v "$PWD:/mnt" koalaman/shellcheck deploy/backup/*.sh`, optional) and a dry-run mode `DRY_RUN=1` that prints the commands (tested locally).

**Verify.** Backup job ran once on the VPS and `restic snapshots` lists it; Healthchecks shows green; the restore drill record exists and passes.

**Pitfalls.** The restic password and the bucket key are the **only** way to read backups: confirm the human stored them twice (H4). Never copy the live SQLite file with `cp`. Never restore over production for a drill. Never skip `bump-epoch` after a real restore.

---

### 10.21 — Self-hosting: Windows `.exe`, Linux binaries, Docker image, Tailscale / Cloudflare Tunnel guide, CI

**Purpose.** The same server for users who run their own, with a guide for reaching it from a phone.

**Files.** `deploy/compose.selfhost.yml`, `deploy/config.selfhost.example.yaml`, `docs/ops/selfhost.md` (also shipped in the artifacts as `README-SELFHOST.md`), `docs/legal/SELF_HOST_LICENSE.md` (10.22), `.github/workflows/ci.yml` (edit), `.github/workflows/server-release.yml`, `.github/workflows/nightly.yml` (edit: cloud fuzz, S3 tests), `tool/release/server_build.dart` + `tool/release.dart` command `server`, server edits (`gen-secret`, `LOG_FILE`, `CLIENT_IP_HEADER`), tests.

**Implementation.**
1. **Server additions:** config keys `LOG_FILE` (path; when set, JSON logs also go to a file rotated daily, keeping `LOG_KEEP_FILES` default 14 — needed because a Windows Task Scheduler task has no stdout capture) and `CLIENT_IP_HEADER` (e.g. `CF-Connecting-IP`; when set **and** `TRUST_PROXY=true`, that header's value is the client IP, otherwise the last `X-Forwarded-For` value); admin command `gen-secret` (prints 48 random bytes base64url; used for `JWT_SECRET`/`METRICS_TOKEN`). Unit tests for both.
2. **Artifacts** (built by `server-release.yml` on tags `server-v*` and by `dart run tool/release.dart server` locally for Windows):
   - Windows x64: `tephra-server-<ver>-windows-x64.zip` containing `tephra-server.exe`, `tephra-admin.exe`, `config.example.yaml`, `README-SELFHOST.md`, `LICENSE.txt` (self-host licence), `THIRD_PARTY_NOTICES.md`, and **`sqlite3.dll`** if the `sqlite3` package version needs it (read its README: how `dart compile exe` finds/bundles SQLite on Windows; if it needs the DLL, download the official `sqlite-dll-win-x64-*.zip` from https://www.sqlite.org/download.html — SQLite is public domain — verify its SHA3 hash shown on that page, record the version in the notices); compiled with `dart compile exe server\bin\tephra_server.dart -o dist\server\tephra-server.exe` (same for admin).
   - Linux x64 and arm64: `tephra-server-<ver>-linux-x64.tar.gz`, `…-linux-arm64.tar.gz` built on the ubuntu runner with `dart compile exe --target-os linux --target-arch x64|arm64 …` (cross-compilation is supported from a Linux host; verify with `dart compile exe --help` on Dart 3.13); contents as above (no DLL; requirement note "install libsqlite3 (`apt install libsqlite3-0`)" unless bundled).
   - Docker image `tephra-server:<ver>` (10.19), saved as `tephra-server-<ver>-docker.tar.gz`; if the human chose a public registry (H8): pushed to `ghcr.io/<owner>/tephra-server:<ver>` and `:latest` using `docker/login-action` with the workflow `GITHUB_TOKEN` (job permission `packages: write`).
   - `SHA256SUMS.txt` for all of the above; published on the **releases-only** repository from Phase 9 (09.17), same manifest/hosting rules, **no source**.
3. **Test every artifact on a clean environment:** Windows zip in Windows Sandbox (or a clean VM): unzip, run `tephra-server.exe` with `PORT=8094 TEPHRA_ENV=dev`, reach `/health`; Linux x64 tarball in `docker run --rm -it ubuntu:24.04` (mount the file, `apt install libsqlite3-0` if needed), arm64 only checked with `file` + `qemu` if available (otherwise "not run-tested" in the notes). Record in `docs/ops/selfhost-test.md`.
4. **`docs/ops/selfhost.md`** (written for non-experts, step by step, with screenshots left as TODO for the human): *What you need*; *Pick a setup*: **A. Windows PC at home** (download the zip, copy `config.selfhost.example.yaml` to `config.yaml`, edit `publicUrl`/`dataDir`/`jwtSecret` (generate with `tephra-admin.exe gen-secret`), `signupEnabled: false`, `emailVerificationRequired: false`, `emailMode: log`; create your account with `tephra-admin.exe create-user --email you@example.com --verified`; run at startup with a scheduled task: `schtasks /Create /TN "Tephra Server" /TR "\"C:\Tephra\tephra-server.exe\" --config C:\Tephra\config.yaml" /SC ONSTART /RU SYSTEM /RL HIGHEST /F`; with `logFile` set); **B. Linux box / NAS with Docker** (`compose.selfhost.yml`: the image, a bind-mounted data dir, `127.0.0.1:8094:8094`, `restart: unless-stopped`); **C. VPS with Caddy** (link to `vps-setup.md`). *Reaching it from your phone over HTTPS* (release builds of the app **require https**): **Tailscale** (free personal plan): install Tailscale on the server machine and the phone, sign in to the same account, enable **MagicDNS** and **HTTPS Certificates** in the admin console (https://login.tailscale.com/admin/dns), then on the server run the current form of `tailscale serve` for a local port (**check https://tailscale.com/kb/1242/tailscale-serve for the exact syntax of the installed version**; for example `tailscale serve --bg --https=443 http://127.0.0.1:8094`) → the server is reachable at `https://<machine>.<tailnet>.ts.net` **only inside your tailnet**; set `publicUrl` to that URL; enter it in Tephra → Sign up → Advanced → Server address → Check. **Cloudflare Tunnel** (free; needs a domain on Cloudflare DNS): install `cloudflared`, `cloudflared tunnel login`, `cloudflared tunnel create tephra`, route a hostname `cloudflared tunnel route dns tephra tephra.<yourdomain>`, `config.yml` ingress `service: http://localhost:8094`, run as a service (`cloudflared service install`); set `TRUST_PROXY=true` and `CLIENT_IP_HEADER=CF-Connecting-IP` so rate limiting sees real clients (**without this every user shares one rate-limit bucket**); Cloudflare terminates TLS and can see ciphertext only; its per-request body limit (100 MB on the free plan) is above ours. *Security checklist for self-hosters* (strong `jwtSecret`, signup off after creating accounts, keep `dataDir` backed up, updates). *Backups* (stop the server or use `tephra-admin backup --to <dir>` then copy `<dir>` and `blobs/`; restore + `tephra-admin bump-epoch`). *Upgrading*. *Troubleshooting* (clock, ports, TLS, "https required").
5. **CI:** `ci.yml` job `server` runs `dart test` (default tags only); a job `server-s3` runs the S3 tests against `adobe/s3mock` as a service container; `nightly.yml` gains: cloud fuzz (`TEPHRA_FUZZ_OPS=20000`, 3 seeds, seed printed first), cloud crash drill (`TEPHRA_DRILL_SEEDS=1000`), server crash test, load smoke (`--devices 20 --duration 3m`). `server-release.yml` builds Linux binaries + image on `server-v*` tags and uploads artifacts (never signs anything, never publishes without the human).
6. `tool/release.dart server`: builds the Windows zip locally, runs `dart test` for the server, writes `dist/server-<ver>/` with checksums; versions: the server's `version` constant = the app's semver (`2.0.0`), defined once in `server/lib/src/version.dart` and checked equal to `app/pubspec.yaml` by a test.

**Tests.** `gen-secret`, `LOG_FILE` rotation with a fake clock, `CLIENT_IP_HEADER` handling (honoured only with `TRUST_PROXY`), the version-equality test, a test that `config.selfhost.example.yaml` parses into a valid `ServerConfig` (with placeholders replaced), and that the README mentions every required key.

**Verify.** Build locally: `dart compile exe server\bin\tephra_server.dart -o dist\tephra-server.exe` and run the exe from a clean folder with only the DLL (if needed) beside it; run the Linux tarball in the Ubuntu container; follow the Tailscale section yourself on the dev PC + phone if the human agrees, otherwise mark "not tested on device".

**Pitfalls.** Never ship `tephra-soak`. Never ship a default `JWT_SECRET`. Self-hosters running behind a tunnel without `TRUST_PROXY`/`CLIENT_IP_HEADER` will rate-limit **everyone** as one client — the guide says so in bold. The Android release app refuses `http://` — tell self-hosters to use HTTPS (Tailscale/Cloudflare give it for free).

---

### 10.22 — Legal: Terms of Service, privacy update, self-host licence, account deletion and data requests

**Purpose.** Documents that match what the server really does. Needs **H8** and Phase 9's placeholder mechanism.

**Files.** `docs/legal/TERMS_OF_SERVICE.md`, `docs/legal/PRIVACY_POLICY.md` (append section 13), `docs/legal/SELF_HOST_LICENSE.md`, `docs/legal/PLACEHOLDERS.md` (edit), `server/lib/src/web/legal_pages.g.dart` (regenerated), `tool/gen_legal_pages.dart`, `app/lib/settings/about/about_page.dart` (links), admin command `export-user`, tests `tool/test/legal_test.dart`, `server/test/admin/export_user_test.dart`.

**Implementation.** Same banner "TEMPLATE — not legal advice" and `{{PLACEHOLDER}}` rules as 09.18 (`release.dart` refuses to publish v2.0.0 while any `{{` remains).
1. **Terms of Service (Tephra Cloud)** sections: the service and who runs it; accounts (accurate email, one person, keep credentials safe, minimum age `{{MIN_AGE}}`); **your content is encrypted before it reaches us** — you alone hold the vault password and recovery key, and **we cannot recover them or your data if you lose them**; acceptable use (no unlawful use, no attacking the service, no storing data you have no right to store, no sharing accounts to evade limits; because we cannot see content, takedown requests are handled by account-level action on valid legal process only); plans and limits (free tier numbers come from `server-info`, may change with 30 days' notice; paid plans later); availability (best effort, maintenance, no uptime guarantee); backups on our side are a safety net, not a service you can rely on (keep your own copy: your devices hold the full vault); suspension and termination (abuse → disable; you can delete your account any time: 7-day grace, then deletion; data in our backups disappears within 35 days); disclaimers and limitation of liability (human/lawyer to adapt); changes to the terms (version `TERMS_VERSION`, notice in the app); governing law `{{JURISDICTION}}`; contact. `TERMS_VERSION` (server constant + `server-info`) = the effective date string; a test asserts the constant equals the date in the document header.
2. **Privacy policy — section 13 "Tephra Cloud"** (appended; a short pointer at the top "If you use Tephra Cloud, section 13 applies"): *Data we hold* (table): email address; password **hash** (Argon2id; we never see your password after hashing); device names and platforms you give us; session timestamps; IP addresses (in authentication audit records **14 days**, in web-server and application logs only as long as log rotation keeps them, at most **14 days**); **encrypted** vault data (we hold ciphertext only) and the **metadata** that is visible to us despite encryption: object key names (`blobs/<hash>`, `journals/<deviceId>/<seq>`, … — which reveal approximate **number and size of files, sync activity times and device identifiers**, but **not** note names, paths or contents), object sizes and timestamps, the **vault name you choose** (plaintext; pick a neutral name), per-account storage totals. *What we do not hold*: vault password, recovery key, master key, note content, note/file names, folder structure. *Purposes*: operate the service, security and abuse prevention, support. *Processors*: VPS provider `{{VPS_PROVIDER}}` (hosting), email provider `{{SMTP_PROVIDER}}` (verification/reset emails), backup storage provider `{{BACKUP_PROVIDER}}` (encrypted backups of our server data). *Retention* (table): account data until deletion; soft-deleted objects 30 days; change log 30 days; audit records 180 days (IPs 14 days); server backups ≈ 4 weeks (**deleted data leaves backups within 35 days**); logs ≤ 14 days. *Account deletion* (how: in the app, Settings → Sync & backup → Delete account, or email `{{CONTACT_EMAIL}}`; 7-day grace; what is deleted). *Your rights* (access: `export-user` produces a JSON of your account data within 30 days of a request by email; correction; deletion; portability — your notes are already on your devices and in Tephra's open Markdown format). *Security* (TLS, encryption at rest only through end-to-end encryption; Argon2id; rate limits; breach notification promise `{{BREACH_POLICY}}`). *Transfers* (location of the VPS `{{VPS_REGION}}`).
3. **`export-user --email E [--out file]`** (admin CLI): writes JSON `{ "exportedAt", "user": {id,email,createdAt,plan,verifiedAt,termsVersion,termsAcceptedAt}, "devices": [...], "vaults": [{id,name,createdAt,usedBytes,objectCount}], "quota": {...}, "auditSummary": {"events": n} }` — **no** password hash, tokens or object keys/content; test asserts those are absent.
4. **`docs/legal/SELF_HOST_LICENSE.md`** (template; terms per **H3** answer): free for personal and internal business use; no resale and no offering Tephra Cloud-compatible hosting to third parties as a service; no warranty; no reverse engineering; third-party notices apply; the self-hoster is the data controller for their users.
5. In the app: Settings → About lists "Tephra Cloud terms" and "Privacy policy" (URLs from `server-info` when signed in, else from the defaults); the sign-up page links them (10.15). Regenerate `legal_pages.g.dart` (10.6) and commit; the `legal_test` checks (a) every placeholder is listed in `PLACEHOLDERS.md`; (b) the generated pages are up to date; (c) the privacy policy mentions every table row of the "data we hold" list and every retention number used by the code constants (`14`, `30`, `180`, `35`, `7`) — constants live in `server/lib/src/retention_constants.dart` and the test imports them.

**Tests / Verify.** As listed; open `https://cloud.<domain>/legal/terms` and `/legal/privacy` on staging.

**Pitfalls.** The policy must not claim "we cannot see anything" — metadata is visible and listed. Do not promise a backup restore to users. Retention numbers in text and code must match (the test enforces it).

---

### 10.23 — Load test (100 concurrent devices), soak agent, staging deployment

**Purpose.** Evidence for capacity and stability. Needs the VPS (staging) from 10.19–10.20.

**Files.** `server/tool/load_test.dart`, `server/tool/soak_agent.dart`, `server/tool/latency_report.dart`, `docs/ops/load-test-<date>.md`, `docs/ops/soak-staging.md` (+ `soak-staging.csv`), tests `server/test/tool/load_test_smoke_test.dart`.

**Implementation.**
1. **Load test** — `dart run server/tool/load_test.dart --server <url> --users 20 --devices-per-user 5 --duration 10m --seed 1 [--invite <code>] [--simulate-ips]` (20 × 5 = **100 concurrent devices**, the free-tier maximum devices per user):
   - Setup: signs up (or logs in) 20 users with generated emails, creates one vault per user, logs in 5 devices per user (distinct device ids), connects 100 WebSockets. `--simulate-ips` adds `X-Forwarded-For: 10.<u>.<d>.1` per user for staging/test servers started with `TRUST_PROXY=true` so the per-IP auth limits are not hit by 100 clients sharing one address (the real production limits stay on; the tool paces logins at ≤ 15 per minute otherwise).
   - Per device (async loop, seeded `Random`): every `5 s ± 3 s` simulate an edit: PUT 1 blob (size log-normal, median 20 KiB, 5% between 1 and 4 MiB; key `blobs/<sha256>` of random bytes so the server's hash check passes) + PUT the next journal batch (`journals/<deviceId>/<seq>` ~2 KiB random bytes with a monotonically increasing seq) ; on every WS event from another device of the same vault: `GET` the announced journal key and one blob; every 30 s a `changesSince` and a `list('journals/')`; every 2 minutes `GET /v1/me/quota`; every 5 minutes one token refresh.
   - Measures (HDR-style buckets, p50/p95/p99/max): latency per operation (PUT blob, PUT journal, GET blob, GET journal, list, changes, quota, login, refresh); **push latency** = time from device A's journal `PUT` response to device B's WS `changed` frame carrying that key (clocks are in the same process → exact); **delivery completeness**: every journal key PUT by one device is observed by the 4 other devices of the vault within 5 s (WS or poll), else counted as lost; error counts by code (`429`, `5xx`, timeouts, resets); server RSS and `tephra_*` gauges scraped from `/metrics` every 10 s (needs `--metrics-token`).
   - Output: Markdown report + CSV to `docs/ops/`, and a JSON summary on stdout.
   - **Targets** (**gate**): error rate (5xx + timeouts + resets) **< 0.1%**; PUT p95 **< 500 ms** (blobs ≤ 1 MiB), GET p95 **< 300 ms**, changes/list p95 **< 200 ms** when run from the same region as the VPS; push latency p95 **< 1 s**, p99 **< 3 s**; **0** undelivered journal keys; server RSS growth during the last 5 minutes **< 20 MB**; no `severe` log lines; CPU on the VPS < 70% average (`docker stats --no-stream` sampled every 10 s in the report). Run it **three times**: (1) locally against a dev server (finds bugs fast), (2) against staging from the dev PC, (3) against staging while the soak agent runs. Fix and re-run until green; record each run.
2. **Soak agent** — `tephra-soak` (compiled into the image, profile `soak` in compose): runs **3 devices** with real `SyncEngine`s, `MemoryVaultFileSystem`s and `TephraCloudSyncProvider`s (encrypted with a fixed test key) on one account/vault, performing the Phase 3 simulator operations (`sim_ops`) at **wall-clock pace** (one op every 20–60 s random, a `syncOnce` on a random device every 15–45 s, random short offline periods, random crash points); every hour it runs the invariants (no loss, convergence, no forks) after a quiet round and logs one JSON line `{"ts","ops","syncs","invariants":"ok"|"FAIL: …","rssServer":…}`; exits non-zero on a failed invariant (compose restarts it, the failure is logged and the Healthchecks "soak" check goes red). Server metrics (RSS, storage, connections) are scraped by `check-host.sh` every 15 minutes into `soak-staging.csv`.
3. **Staging soak plan (7 days):** deploy the release candidate to **staging**; day 0 start the soak (`docker compose --profile soak up -d soak`); **day 1** record the warm-up RSS; **day 3** planned `docker compose restart tephra-staging` during activity → soak and any phone/PC test devices reconnect automatically; **day 5** unplanned `docker kill -s KILL` of the staging container → clean recovery (DB `integrity_check` ok, `verify-storage --deep` ok, clients continue); **day 6** run the staging restore drill (10.20) from the previous night's backup; **day 7** final measurements. Meanwhile the human keeps **two real devices** (phone + PC) syncing a real vault on staging.
   **Pass criteria:** zero `"level":"SEVERE"` lines other than the two induced restarts; 0 invariant failures; Docker `RestartCount` equals 1 (only the induced SIGKILL is restarted automatically by the restart policy; the planned `docker compose restart` does not increment it); RSS on day 7 within **+10%** of day 1; disk growth consistent with the data (`stats` before/after); backups ran 7/7 (Healthchecks); no unexplained 5xx in `tephra_http_requests_total{status=~"5.."}`; certificates valid; the uptime monitor shows ≥ 99.9% for the week excluding the induced restarts.
4. `docs/ops/soak-staging.md` records: dates, commands, per-day RSS/storage table, incidents, conclusions.

**Tests.** `load_test_smoke_test.dart`: the tool against a `TestServer` for 20 devices × 20 s completes, produces a report, exits 0 and the delivery check detects a deliberately dropped event (inject a `ChangeHub` that drops one frame). Soak agent unit-tested with a fake clock (invariant check path) and a 30-second integration run in CI (`--smoke`).

**Verify.** The three load runs and the soak record exist and meet the targets.

**Pitfalls.** Do not run the load test against production. 100 simulated devices on one machine are CPU-heavy on the client side — if the **client** is the bottleneck (client CPU > 80%), the numbers are invalid: split the run across two processes (`--users 10` twice) and say so in the report. Soak failures are real bugs.

---

### 10.24 — Real-device checks, frozen API document, v2.0 release

**Purpose.** Prove the exit gate on real devices and ship.

**Files.** `docs/decisions/cloud-api-v1.md`, `docs/testing/cloud-real-device.md`, `tool/latency_report.dart`, `app/lib/core/sync/latency_marks.dart`, `CHANGELOG.md`, `app/assets/guide/` (new pages), `docs/ops/README.md` (index), `PROGRESS.md`, release artifacts.

**Implementation.**
1. **Freeze the API:** `docs/decisions/cloud-api-v1.md` = the "The API" section of this file copied **verbatim** (plus the DTO JSON fixtures used by the tests, the server rules of 10.8, the epoch/cursor rules of 10.9, the limits table of 10.10, the event frames), and a "Compatibility rules" section: only **additive** changes inside `/v1` (new optional fields, new endpoints, new error codes the client treats as generic); clients ignore unknown fields; a breaking change = `/v2`; the remote object format stays governed by `sync-format-v1.md`.
2. **Latency instrumentation (for the gate):** at `info` level the app logs `latency.saved <path-hash8> <epochMs>` when a note file is written to disk by the editor/vault (the moment the user's save reaches disk — **after** the editor's own ~1 s autosave debounce) and `latency.applied <path-hash8> <epochMs>` when the sync executor finished writing a downloaded file; both use `DateTime.now().toUtc().millisecondsSinceEpoch` and `sha256(path).substring(0,8)` (no paths in logs). `tool/latency_report.dart --a <logA> --b <logB>` pairs `saved` on one device with the next `applied` of the same hash on the other and prints min/median/p95/max; both devices must have NTP-synchronised clocks (Windows: `w32tm /resync`; Android: automatic time on); the tool prints the apparent clock offset (`min` latency should not be negative; if negative, the clocks are off by at least that much — redo after resync). The same marks feed an **automated loopback test** (`server/test/cloud/latency_e2e_test.dart`: two real `SyncEngine`s + `TestServer` + WS, 50 edits, p95 `saved→applied` **< 1.0 s**, max < 2.5 s).
3. **`docs/testing/cloud-real-device.md` — procedure** (run on the real phone + PC + a second device if available, against **staging** first, then production for the final checks; record every result and number in `PROGRESS.md`):
   1. **Fresh setup:** phone: choose Tephra Cloud → sign up (real SMTP, the verification mail arrives within 1 minute and is not in spam; record the sender reputation result) → verify → create an encrypted vault from a copy of the real vault → PC: sign in with the same account → connect → enter vault password → download. Compare file counts and spot-check 10 notes.
   2. **Latency:** both apps in the foreground on normal networks; edit a note on the PC, record from `latency.saved`/`latency.applied` logs; **20 runs each direction**; **gate: every run ≤ 3 s** (record min/median/p95/max); also record with the PC on Ethernet and the phone on mobile data.
   3. **Airplane day** (as Phase 3 real-device 3): 3 clean merges, 2 conflict copies, no lost edits.
   4. **Network loss mid-upload** (50 MB file, 2-minute outage) → completes, no duplicate; **server restart during sync** (`docker compose restart tephra-staging`) → clients recover without user action within 2 minutes.
   5. **Token lifecycle:** leave both apps idle 20 minutes (access token expired) → next edit syncs without any prompt; `tephra-admin revoke-sessions` → app shows "Sign in to Tephra Cloud" (no vault password asked after signing in); remove a device from another device → it signs out within ~60 s.
   6. **Quota:** set a 5 MB override → uploads stop with the clear message, downloads continue; raise it → resumes.
   7. **Email flows:** forgot-password email arrives, the browser page works, all sessions are revoked, the vault password is **not** reset (open the vault after signing in again; no data loss); change password; **account deletion on a throwaway account** on staging (`ACCOUNT_DELETION_GRACE_DAYS=0`) → mail received, `tephra-admin stats` shows the objects gone, the blob directory has no files for that vault.
   8. **Readable-data check:** copy the staging server's `blobs/` directory and the SQLite file to the PC (`scp`); search the whole copy for 10 distinctive note words and 10 note file names (`Select-String -Path <dir> -Pattern '<word>' -Recurse -SimpleMatch`; for the SQLite file use `strings`-equivalent: `Select-String -Path tephra.sqlite -Pattern '<word>' -SimpleMatch -Encoding Default`) → **zero matches**; list what the DB does contain (emails, device names, vault names, object keys) and compare with the privacy policy.
   9. **TLS and exposure:** `curl -vI https://cloud.<domain>/health` (TLS 1.3, valid chain, HSTS header); `curl -I http://cloud.<domain>/` redirects to https; an SSL test (https://www.ssllabs.com/ssltest/) grade **A or better**; from outside the VPS `nmap -Pn -p 1-1024,8094,5432,3306 <ip>` shows only 22, 80, 443 open (install nmap or use an online port scanner); `/metrics` without token → 401; WebSocket through Caddy works (the live-push test above).
   10. **Migration (gate):** with the **10,000-note encrypted Drive vault** (H7): note start/end times; run **Move to Tephra Cloud** on the PC (keep Drive as backup on); on completion read `migration-report.json`: **verification differences = 0**, copied counts equal the Drive object counts (`list('')` minus `locks/`); the post-switch cycle reports **0 actions**; switch the phone (same account) → no downloads of existing files, no conflicts; edit on both → syncs via Cloud ≤ 3 s; confirm in Google Drive that the old folder still exists, now with `movedTo` in `vault.json` (open it in the Drive web UI preview if readable, else via the app's "Use Drive copy" dry run); trigger the mirror → new journals appear in Drive; emergency-return test on a **copy** vault.
   11. **Phone background 24 h** with Cloud: battery for Tephra < 2%/day (Phase 3 gate), edits from the PC during the day arrived (via WorkManager polling, no WS).
   12. **Restore drill** (10.20) done and recorded; **backup freshness** shown in Healthchecks.
   13. **Self-host smoke:** Windows zip run locally + Tailscale (or LAN https via Tailscale serve) + phone sign-up against it → sync works (skip with "not verified on device" if the human has no Tailscale).
4. **Docs and guide:** add `06b Sync with Tephra Cloud.md` (what it is, sign-up, two passwords, storage, devices, deleting the account, privacy), `Moving from Google Drive to Tephra Cloud.md` (the wizard, other devices, mirror, undo), FAQ additions (≥ 8: "Is Tephra Cloud free?", "Can you read my notes?", "What if I forget my account password / vault password?", "Do I need Tephra Cloud?", "Can I self-host?", "How do I leave?", "Where is my data stored?", "What happens to my data if I delete my account?"); update `00 Start here.md` and the guide test (links resolve). `docs/ops/README.md` indexes all ops docs.
5. **Release v2.0.0:** set `app/pubspec.yaml` `version: 2.0.0+<next build>`; `CHANGELOG.md` `2.0.0` (Added: Tephra Cloud, accounts, push sync, move from Drive, Drive mirror, self-hostable server; Changed: save debounce 1 s on Cloud; Security: …); `secrets/release.json` gets `TEPHRA_CLOUD_URL=https://cloud.<domain>`; `dart run tool/release.dart build --all` (Phase 9 pipeline, unchanged otherwise) and `dart run tool/release.dart server`; smoke-test the produced APK/installer (09.5 list + cloud sign-up + migration on a small vault); **deploy the server to production first** (10.19 upgrade procedure, backup before), verify `/ready`, create the invitation policy per H3, **then** publish the app via the Phase 9 order (binaries → verify → page → manifest last) and the self-host artifacts; tag `v2.0.0` after merging `phase-10` (`git checkout main; git merge --no-ff phase-10; git tag v2.0.0`); archive `dist/` and the ops records.
6. **Rollback plan** in `docs/ops/runbook.md`: server (previous image tag; DB pre-migrate backup; `bump-epoch`), app (republish the previous manifest — Phase 9 rollback), a Cloud outage never blocks local use or Drive users.
7. Update `PROGRESS.md`: all steps, gate numbers (latency min/median/p95/max, load-test table, soak table, migration timing and differences, restore drill RTO/RPO), contract additions, open limitations.

**Verify.** Every Exit-gate item.

**Pitfalls.** Do not deploy the app that points at production before the server is healthy and backed up. Never test destructive flows (account deletion, vault delete) on production data. Do not remove the Drive provider code: Drive remains a first-class provider.

---

## Demo script

Run with the release candidate on the Android phone and the Windows PC against **staging**, record results in `PROGRESS.md`:

1. **Account:** phone → Settings → Sync & backup → Set up sync → **Tephra Cloud** → Advanced → server address = staging URL → Check shows the name and version → create account → read the two-passwords box → accept terms → the verification email arrives → open the link in the browser ("Email confirmed") → the app continues by itself.
2. **Vault:** create an encrypted vault (vault password ≠ account password) → save the recovery key → first upload of the demo vault → the Storage screen shows usage.
3. **Second device:** PC → sign in with the same account → choose the vault → vault password → download.
4. **Instant sync:** edit `Demo.md` on the PC; watch the phone show the change within ~1–3 s without touching it. Edit on the phone → PC updates. Show the sync log line "from <device>" and the latency numbers from `latency_report`.
5. **Offline merge:** phone in airplane mode edits paragraph 1, PC edits paragraph 3 → reconnect → both edits present within seconds; same-line edit → conflict copy and the Phase 3 conflict screen.
6. **Devices:** Settings → Devices shows both with last seen; remove the phone from the PC → the phone shows "This device was removed"; sign in again.
7. **Password flows:** Forgot password → email → browser page → new password → all devices asked to sign in → vault opens without the vault password being touched. Change password in Settings.
8. **Quota:** admin sets a tiny quota → uploads pause with "Tephra Cloud is full" → raise → resumes; Clean up now.
9. **Move from Drive:** take a vault that syncs with Google Drive → Settings → Move to Tephra Cloud → sign in → keep Drive as backup → progress → "Verified: 0 differences" → switch the second device → edit on both → syncs via Cloud; open Google Drive: the old folder is intact.
10. **Server:** `tephra-admin stats` on the VPS; `docker compose restart tephra` while both apps are open → they reconnect and keep syncing; show `/metrics` (with token) and the uptime monitor; show the latest restic snapshot and the recorded restore drill.
11. **Self-host:** run the Windows zip on the PC, sign up against it over Tailscale HTTPS (if available).
12. **Account deletion** on a throwaway staging account → mail → data gone.

## Exit gate

Check every item; record numbers and dates in `PROGRESS.md`. Any failing item → stop and ask the human (GEMINI.md §5).

- [ ] Steps 10.1–10.24 ticked; `flutter analyze --fatal-infos` 0 issues; `dart test` in every package **and** `server/`; `flutter test --exclude-tags golden`; `dart test tool/test`; `dart run tool/check_licenses.dart` passes (no AGPL/GPL anywhere; MinIO **server** not used).
- [ ] **Provider contract:** `runSyncProviderContract` passes for `TephraCloudSyncProvider` against the real test server (plus the cloud-specific extra tests).
- [ ] **Fuzz and data-safety on Tephra Cloud:** cloud fuzz (default and the local 20,000-op run) 0 lost content, convergence every run; nightly green for **7 consecutive nights** (record seeds); the 1,000-seed crash-point drill, the 200-iteration real-kill drill (`--provider cloud`), the corrupted-remote tests (server-side storage corruption) and the server-crash test (SIGKILL during PUT) all pass (`docs/ops/data-safety-cloud.md`).
- [ ] **Speed:** a save on one device appears on the other **≤ 3 s** in all 20 runs per direction on real devices (min/median/p95/max recorded); the automated loopback test p95 < 1.0 s.
- [ ] **Migration:** the 10,000-note encrypted Drive vault moves to Tephra Cloud with **zero differences** (history equality, plan equality, content sample, object counts equal), the post-switch cycle has 0 actions, the second device switches without re-downloading, Drive is untouched (marker/mirror only), and the migration report is recorded.
- [ ] **Backups:** daily restic backup running 7/7 days; **restore drill passed** (record RTO ≤ 2 h, RPO ≤ 24 h, `verify-storage --deep` exit 0, `restore_check` 0 differences, `bump-epoch` done).
- [ ] **Staging soak:** 7 days with no unexplained `SEVERE` log lines, 0 invariant failures, RSS within +10% of day 1, planned restart and SIGKILL recovered automatically, backups 7/7, uptime ≥ 99.9% excluding induced restarts (`docs/ops/soak-staging.md`).
- [ ] **Load:** 100 concurrent devices meet every target of 10.23 (error rate < 0.1%, p95 latencies, push p95 < 1 s, 0 undelivered, no RSS growth) in the three recorded runs.
- [ ] **Security:** Argon2id parameters as specified (hash time recorded), refresh-token rotation + reuse detection + 30-s grace verified by tests and the real two-process check, rate limits verified, `nmap` shows only 22/80/443, SSL Labs A or better, `/metrics` protected, the readable-data check finds **zero** note words/names in the server data, the privacy policy lists the metadata the server can see.
- [ ] **Email and accounts:** verification, reset, change-password, account deletion (grace, purge, mail) work on staging with real SMTP; the vault password is never affected by account-password changes.
- [ ] **Self-hosting:** Windows zip, Linux x64/arm64 tarballs and Docker image built and smoke-tested on clean environments; the guide with Tailscale and Cloudflare Tunnel is complete; the release app refuses `http://` servers.
- [ ] **Legal:** Terms of Service, privacy update, self-host licence published, no `{{PLACEHOLDER}}` left, retention numbers in text equal the code constants (test green).
- [ ] **Dev Launcher:** `server` registered as a second process of "Tephra (Gemini build)" (`autoStart: false`), starts on `PORT` 8094 with the `Local:`/`Network:` lines, and the web preview (`dart run tool/dev.dart`, port 8093) still works.
- [ ] `docs/decisions/cloud-api-v1.md` committed; v2.0.0 released through the Phase 9 channel; `git checkout main; git merge --no-ff phase-10; git tag v2.0.0`; stop and report to the human.

## Hand-off

What Phase 11 relies on:

1. **Tephra Cloud API v1** (frozen in `docs/decisions/cloud-api-v1.md`): accounts/sessions/devices, vault and object endpoints, changes feed with epoch, WebSocket events, quota, error envelope, rate limits. Phase 11 **adds** endpoints (for example `/v1/inbox` for the web clipper and share/collaboration endpoints) following the compatibility rules (additive only); the middleware pipeline (10.7), DAOs (10.3), jobs (10.11) and admin CLI (10.12) are the extension points; migrations are numbered (`m003_…`).
2. **Provider abstraction:** `RemoteVaultDirectory`, `SyncProviderFactory`, `TephraCloudSyncProvider`, `CloudEventsClient`, `CloudAuthApi` (reusable by a browser-extension port or a web client in Phase 11). End-to-end encryption means **server-side features cannot read notes**: collaboration and clipping must use client-side keys (Phase 11 designs that).
3. **Accounts and tokens:** email + password, JWT/refresh rotation, device list — the clipper authenticates with the same API as a device named "Web clipper".
4. **Release/ops pipeline:** `tool/release.dart` (`build`, `server`), `server-release.yml`, the Docker/Caddy deployment, backups and the restore drill, the ToS/privacy/self-host templates, `legal_test`. Store releases (Phase 11) must keep the privacy policy URL in sync.
5. **Contract additions of this phase** (fold into `00-conventions.md` when the human approves): `isValidRemoteKey/checkRemoteKey`, `RemoteKeyExistsException`, `AccountActionRequiredException`, `RemoteVaultDirectory`, `MovedTo` header field, `meta` keys (`cloudServerUrl`, `mirrorProviderId`, `migrationState`, `lastMirrorAt`), provider id `'tephra-cloud'` with its 1-s save debounce, secret keys `tephra.cloud.*`, server port 8094.
6. **Open limitations to carry:** single server node (SQLite; no horizontal scaling), no payment integration (plan changes by admin), no email-address change, no in-app re-acceptance of updated terms, no server-side history UI (client history only), local-disk blobs by default (S3 supported, tested with s3mock only), mirror never prunes, iOS/macOS/Linux clients do not exist yet.
