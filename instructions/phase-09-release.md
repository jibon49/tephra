# Phase 09 — Release hardening → v1.0 (direct download: signed APK + Windows installer, in-app updates)

> **Duration:** 3 weeks (one full-time developer, ~15% buffer included) + a 2-week beta that overlaps weeks 2–3.
> **Goal:** a build that is safe to give to other people: opt-in crash reporting, the performance budgets met on a **4 GB** Android phone, small
> per-ABI APKs, a security and licence review with written results, data-safety drills that prove "no loss" under disk-full / kill / corruption,
> **signed** Android APKs and a Windows installer (Inno Setup) plus a portable zip, a signed update manifest with an in-app updater on both platforms,
> a download page, legal templates, a user-guide vault, an FAQ and an Obsidian migration guide. Distribution v1 is **direct download only**
> (no Play Store / Microsoft Store — those are Phase 11).
>
> **Decisions made for you (do not revisit; they are listed here so nothing is ambiguous):**
> closed source; permissive licences only; crash reporting = `sentry_flutter`, **off until the user opts in**; APK install = **our own small
> platform channel** (not `open_filex`, whose current version removed `REQUEST_INSTALL_PACKAGES`); update manifest = JSON **signed with Ed25519**
> (public key compiled into the app) in addition to SHA-256 per file; Windows installer installs **per-user by default** (`{autopf}` resolves to
> `%LOCALAPPDATA%\Programs\Tephra` without admin, or `C:\Program Files\Tephra` if the user picks "all users") so silent in-app updates need no UAC prompt;
> VC++ runtime DLLs are **bundled app-local** (no separate redistributable installer); release builds are made **on the human's PC**, never in CI,
> because the signing keys must not leave it.

Read this whole file once before starting step 09.1. Then do the steps strictly in order. Every step ends with the standard GEMINI.md §3 loop
(format, analyze, tests of touched packages, tick `PROGRESS.md`, commit `phase 09.N: <summary>`).

---

## Before you start

### Prerequisite gate (check each; write the result in `PROGRESS.md`)

1. `PROGRESS.md` shows the Phase 8 exit gate fully checked and `git tag` lists `v0.08.0`. You are on `main`, the working tree is clean, then
   `git checkout -b phase-09`.
2. `flutter analyze --fatal-infos` = 0 issues; `dart test` passes in every package; `flutter test --exclude-tags golden` passes in `app/`;
   `dart run tool/check_licenses.dart` passes.
3. Phase 3's 2-week daily beta is finished and its notes in `PROGRESS.md` show no open data-loss issue. If one is open, stop and tell the human.
4. The human has done the "Human prerequisites" below that are marked **needed before 09.N** for the step you are about to start. Each step names
   what it needs; ask for the missing item at that moment, not all at once at the beginning (except H2 and H3, which have long lead times: ask for
   them **now**, in your first message of the phase).

### What already exists (from Phases 0–8) and what you rely on

Look at the real code before using any of these (Grep tool or `Select-String -Path packages,app,tool -Pattern '<name>' -Recurse`).

| Thing | Where | Used by this phase for |
|---|---|---|
| Crash handlers in bootstrap (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded`) | `app/lib/main.dart`, `app/lib/core/` | hooking the crash reporter (09.2) |
| App-level settings (`<appSupportDir>/settings.json`) with typed accessors | `app/lib/core/settings/` | consent state, update-check state |
| `package:logging` setup with a file sink (if Phase 0 added one; otherwise 09.2 adds a rotating file log) | `app/lib/core/logging/` | local crash log |
| `tool/gen_bench_vault.dart` and the bench vault in `test_vaults/bench/` | `tool/` | performance re-profiling (09.4) |
| `tool/check_licenses.dart` and `THIRD_PARTY_NOTICES.md` | `tool/`, repo root | licence review (09.7) |
| `CrashInjector`, `SimWorld` fuzz simulator, `MemorySyncProvider`, `FakeDriveServer` | `packages/tephra_sync/test/` | data-safety drills (09.9) |
| `NoteIndex.open/rebuild/reconcile` | `packages/tephra_index` | corrupted-index drill (09.8) |
| `SyncStateStore`, `JournalReader`, `RemoteHistory`, `HistoryRetention`, `GarbageCollector`, `BackupVerifier` | `packages/tephra_sync` | corrupted-remote drill (09.9) |
| `ci.yml` (jobs `checks`, `android`, `windows`) and `nightly.yml` | `.github/workflows/` | extra release-readiness checks (09.1) |
| `app/android/app/build.gradle.kts` with `namespace = "com.tephra.app"`, `minSdk = 26` | `app/android/` | signing (09.10), R8 (09.5), installer channel (09.15) |
| Windows runner `app/windows/runner/` (`BINARY_NAME` in `app/windows/CMakeLists.txt`) | `app/windows/` | installer (09.11) |
| `.gitignore` already ignores `secrets/*` (except `*.example.json`), `*.jks`, `*.keystore`, `key.properties`, `build/` | repo root | keystore handling |
| AI settings privacy text, list of network destinations, APK size breakdown `docs/release/size-phase-08.md` | Phase 8 (08.54) | privacy policy (09.18), size work (09.5) |
| Phase 8 encrypted notes (`.tephraenc`) and app lock | `app/lib/…` | security review (09.6) |

If an item is missing, stop and tell the human which earlier item is missing (GEMINI.md §5). Do not build it silently.

---

## Human prerequisites

Copy this whole section into your first message to the human. Items marked **now** have lead time; the rest are requested when their step starts.

### H1. Sentry project (needed before 09.2) — free account is enough

1. Open https://sentry.io → sign up (or sign in) → create an **organisation** (name: `tephra`).
2. **Projects → Create Project** → platform **Flutter** → name `tephra-app` → Create.
3. Copy the **DSN** (looks like `https://<key>@o<digits>.ingest.sentry.io/<digits>`). It is not a password, but it is configuration:
   create `D:\script\tephra-gemini\secrets\sentry.json` containing exactly `{ "TEPHRA_SENTRY_DSN": "<the DSN>" }`.
4. Project → **Settings → Security & Privacy**: turn **on** "Prevent Storing of IP Addresses", **on** "Data Scrubber" and "Use Default Scrubbers",
   set "Data Retention" to the shortest option offered (30 days on the free plan).
5. Tell Gemini "Sentry ready".

### H2. A low-end Android phone (**now**) — needed before 09.4

A real phone with **4 GB RAM or less** (or the weakest phone the human owns), USB debugging enabled, Android 11 or newer, connected to this PC.
If none exists, tell Gemini; the performance gate then cannot be passed and the human must decide (buy/borrow one, or accept an emulator
result recorded as "not verified on device" — GEMINI.md §5 rule).

### H3. Signing and backup decisions (**now**) — needed before 09.10

1. Choose a **keystore password** and **key password** (they may be the same; at least 16 characters; a passphrase is fine). Do **not** tell them to Gemini
   in chat. Gemini will create `secrets/key.properties` with placeholders and the human types the passwords into that file themselves (step 09.10).
2. Choose **two offline places** for the keystore backup (for example an encrypted USB stick kept at home and the human's password manager's
   file attachment). Losing the Android signing key means **no user can ever update the app again**; the keystore and its passwords must exist in two places.
3. Decide the **certificate owner name** for the keystore (default: the human's name or company, e.g. `CN=Tephra, O=<company>, C=BD`).

### H4. Where the downloads live (needed before 09.17) — human chooses **A** or **B**; Gemini prepares both

- **A. Releases-only public GitHub repository** (recommended: free, hosts large files, source stays private).
  1. github.com → New repository → name `tephra-releases` → **Public** → add a README → Create.
  2. Install and sign in the GitHub CLI on this PC (`gh auth login`, choose HTTPS + browser) if not already done; tell Gemini the repo as `<owner>/tephra-releases`.
  3. Optional: Settings → Pages → Source "Deploy from a branch" → `main` / `/docs` to get a free download page at `https://<owner>.github.io/tephra-releases/`.
- **B. Static site host** (own domain): Cloudflare Pages, Netlify or any web host. The human provides the base URL, e.g. `https://tephra.example/`.
  Gemini produces a folder `dist/site/` to upload.
- In both cases the human decides the **update manifest URL** (stable forever, because installed apps hard-code it), for example
  `https://<owner>.github.io/tephra-releases/update/manifest.json` or `https://tephra.example/update/manifest.json`. Tell Gemini the exact URL (needed before 09.14).

### H5. Inno Setup 6 (needed before 09.11)

Gemini tries `winget install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements` in PowerShell. If it asks for
administrator approval or fails, Gemini stops and the human runs the same command in an **Administrator** PowerShell (or installs from https://jrsoftware.org/isdl.php,
choosing the default options). Afterwards `iscc.exe` must exist at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` (per-machine install) or
`%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe` (per-user install). Inno Setup is a build tool only; nothing of it is shipped inside the app.

### H6. Google OAuth for release builds (needed before 09.20; **required** if you will have more than 100 beta users or want to avoid the weekly reconnect)

1. After 09.10 Gemini prints the **SHA-1 of the release keystore** (`keytool -list -v …`). Open Google Cloud console → project `Tephra` → APIs & Services →
   Credentials → **Create credentials → OAuth client ID** → **Android** → name `Tephra Android (release)` → package `com.tephra.app` → paste the SHA-1 → Create.
   (The debug client from Phase 3 stays; Google matches by package + SHA-1, nothing goes into the code.)
2. Google Auth Platform → **Branding**: set app name `Tephra`, **application home page** (the download page URL from H4), **privacy policy link**
   (published in 09.17), authorised domain, support email. Then **Audience → Publish app → In production**. `drive.file` is a non-sensitive scope, so no paid
   security assessment is needed; until Google finishes brand verification the consent screen shows an "unverified app" notice — normal and acceptable for v1.0
   (record it in the FAQ). This also removes the 7-day refresh-token expiry of the Testing mode.
3. Tell Gemini "Google release client ready".

### H7. Legal review (needed before the v1.0 tag)

Gemini writes templates in 09.18. The human must replace every `{{PLACEHOLDER}}` (company/owner name, contact email, jurisdiction, effective date) and
should have a lawyer review the EULA and privacy policy. Gemini is not a lawyer; the templates are starting points, not legal advice.

### H8. Optional: Windows code-signing certificate (needed only if the human wants no SmartScreen warning)

Without a certificate the installer shows "Windows protected your PC" (More info → Run anyway) until the file builds reputation. A paid OV/EV code-signing
certificate (or Microsoft's Azure Trusted Signing, where available) removes or reduces that. If the human has a `.pfx`, place it at
`secrets/codesign.pfx` and put its password in the environment variable `TEPHRA_CODESIGN_PASSWORD` for the shell that runs the release (never in a file).
If not, skip; the release tool works unsigned and the download page explains the warning (09.17).

### H9. Beta users (needed before 09.20)

Recruit ≥ 10 testers (or commit to your own heavy daily use on phone + PC) for a **2-week beta** of the release candidate. Testers on Google sync must
be added as OAuth test users **unless** H6 step 2 (In production) was done. Gemini prepares a one-page tester guide in 09.20.

---

## What exists when done

- `app/lib/core/crash/` — `CrashService`, `CrashReporter` interface, `SentryCrashReporter`, `NoopCrashReporter`, `EventScrubber`, `CrashConsent` state,
  local crash log; consent dialog in the first-run flow and a switch in Settings → Privacy.
- `docs/release/` — `perf-v1.0.md`, `size-v1.0.md`, `security-review.md`, `permissions.md`, `licence-review.md`, `data-safety-drills.md`, `release-checklist.md`,
  `tester-guide.md`, `distribution.md`; `docs/legal/` — `PRIVACY_POLICY.md`, `EULA.md`, `EULA.txt` (generated), `TERMS_PLACEHOLDERS.md`.
- Release plumbing: `app/android/app/build.gradle.kts` signing config reading `secrets/key.properties`, R8 + resource shrinking with `proguard-rules.pro`;
  `installer/tephra.iss`; `tool/release.dart` (+ `tool/release/*.dart`, tests in `tool/test/`); `CHANGELOG.md`; version rules in `docs/release/versioning.md`.
- Updater: `app/lib/core/updater/` (manifest model, Ed25519 verification, version/ABI selection, downloader, Android installer channel, Windows installer launcher,
  providers) and `app/lib/settings/about/` (About page, "Check for updates", update dialog); Kotlin channel `InstallerChannel.kt` + FileProvider.
- Data-safety work: fixes found by the drills, plus new regression tests (`packages/tephra_vault/test/drills/`, `packages/tephra_index/test/drills/`,
  `packages/tephra_sync/test/drills/`), `tool/drill_kill_sync.dart`, and the written drill log.
- Download page generator `tool/make_site.dart` (`dist/site/` for option B, `docs/` layout for option A); user-guide vault as assets
  (`app/assets/guide/`) with the command `app.open-user-guide`; FAQ; Obsidian migration guide.
- Tag `v1.0.0` with published, signed artifacts and checksums.

---

## Dependencies

Add each with `flutter pub add <pkg>` inside `app/` (or `dart pub add` where stated), then `flutter pub get` at the repo root and
`dart run tool/check_licenses.dart`. Licences below were checked on pub.dev when this file was written; **re-check each package's pub.dev page
(licence + README) when you add it**. If a licence is not allowed, stop and ask the human.

| Package | Where | Licence | Why |
|---|---|---|---|
| `sentry_flutter` (10.x at writing) | app | MIT (verified) | opt-in crash reporting (Android + Windows supported) |
| `package_info_plus` (10.x) | app | BSD-3-Clause (verified) | installed version/build for the updater and the About page |
| `cryptography` (already in tephra_sync; add to **app** if absent) | app | Apache-2.0 | Ed25519 verification of the update manifest, SHA-256 |
| `http` (already present) | app | BSD-3-Clause | manifest + installer download |
| `url_launcher` (already present) | app | BSD-3-Clause | open privacy policy / download page |
| `archive` | repo root, **dev** dependency of `tool/` | MIT (re-check) | zip creation for the portable build (PowerShell 5.1 `Compress-Archive` writes backslash entry names; do not use it) |
| `markdown` | repo root, **dev** dependency of `tool/` | BSD-3-Clause (re-check) | render the legal/guide pages to HTML for the download site (the Phase 1 parser stays hand-written; this is only for the site generator) |
| `yaml` (already present) | repo root dev | MIT | read `pubspec.yaml` version in `tool/release.dart` |
| `sentry_dart_plugin` | **optional**, dev machine only (`dart pub global activate`), not a dependency | check licence before use | upload debug symbols to Sentry (09.2 step 8); skip if not clearly permissive — symbols are archived regardless |

No other new dependencies are allowed in this phase. Inno Setup, `keytool`, `signtool`, `iscc`, `adb` and DevTools are build/dev tools, not shipped dependencies.

---

## Steps

Every step has: **Purpose**, **Files**, **Implementation**, **Tests**, **Verify**, **Pitfalls**. "Verify" always also means the standard GEMINI.md §3 commands:

```
dart format --output=none --set-exit-if-changed app/lib app/test packages tool
flutter analyze --fatal-infos
```

plus `dart test` in every package you touched and `flutter test --exclude-tags golden` in `app/` if you touched the app, and `dart test tool/test` if you touched `tool/`.
Every new Dart file starts with `// © 2026 Tephra. All rights reserved.` Every new user-visible string goes into `app/lib/l10n/app_en.arb`.
Logger names used here: `crash`, `updater`, `release`, `drill`.
**Never log** note text, paths inside the vault, tokens, keys, DSNs or passwords.

---

### 09.1 — Branch, versioning rules, changelog, release-readiness CI

**Purpose.** Fix how versions are written so later steps (updater, installer, Android versionCode) agree.

**Files.** `docs/release/versioning.md`, `CHANGELOG.md`, `app/pubspec.yaml` (edit), `tool/version.dart`, `tool/test/version_test.dart`, `.github/workflows/ci.yml` (edit), `.gitignore` (edit).

**Implementation.**
1. `docs/release/versioning.md` states (copy these rules exactly):
   - Version string = **semantic version** `MAJOR.MINOR.PATCH` plus an integer **build number**: `app/pubspec.yaml` → `version: 1.0.0+7` (`1.0.0` is the version, `7` the build).
   - The build number increases by exactly 1 for **every** artifact set that leaves this PC (release candidates included) and **never exceeds 999**
     (Flutter's `--split-per-abi` computes Android `versionCode = abiOffset * 1000 + build`, with offsets 1 for x86, 2 for x86_64, 3 for armeabi-v7a, 4 for arm64-v8a).
     At build 999 the project must switch to a different scheme (stop and ask the human).
   - Release candidates are tagged `v1.0.0-rc.1` (git tag only; the pubspec version stays `1.0.0+<build>`); the final release is `v1.0.0`.
   - Phase tags `v0.NN.0` stay as they are. v1.0 is tagged `v1.0.0`, v2.0 (Phase 10) `v2.0.0`.
   - **Updater rule:** the app compares `(MAJOR, MINOR, PATCH)` tuples first, then the **build number modulo 1000** (on Android `package_info_plus` returns the *versionCode*, which
     already contains the ABI offset; reduce it with `% 1000`; on Windows it returns the build number unchanged).
   - Android APK file names: `tephra-<version>-android-<abi>.apk` (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and `tephra-<version>-android-universal.apk`.
     The updater always picks the ABI-specific file. A user who installed the universal APK can be upgraded to an ABI-specific one (higher versionCode) but
     **cannot** later sideload the universal one over it (Android rejects a lower versionCode) — written into the FAQ (09.19).
   - Windows file names: `tephra-<version>-windows-x64-setup.exe` and `tephra-<version>-windows-x64-portable.zip`.
2. `CHANGELOG.md` in the repo root, format "Keep a Changelog": `## [Unreleased]`, then `## [1.0.0] - YYYY-MM-DD` with `### Added / Changed / Fixed / Security`. Create the `1.0.0`
   section now as `## [Unreleased]` content to be finalised in 09.20. Add a first bullet per phase (Phases 0–8 features in one-line form, taken from `README.md`'s feature list).
3. `tool/version.dart`: library with `AppVersion parseVersion(String pubspecVersion)` (`major, minor, patch, build`, throws `FormatException` on anything not matching
   `^\d+\.\d+\.\d+\+\d+$`), `int compareVersions(AppVersion a, AppVersion b)` (tuple then build), and `String sanitizeAndroidBuild(int packageInfoBuild)` →
   `packageInfoBuild % 1000`. `AppVersion.display` = `1.0.0`; `AppVersion.full` = `1.0.0+7`. A `main` that prints the version of `app/pubspec.yaml` (used by scripts).
4. Set `app/pubspec.yaml` `version: 0.9.0+1` now (the release candidate series starts at `0.9.0` for the beta; 09.20 raises it to `1.0.0+<n>`).
5. `.gitignore`: add `dist/` (release output), `.data/` (Phase 10 server dev data), `build/symbols/`. Keep `secrets/*` rules unchanged.
6. `ci.yml` job `checks`: add `dart test tool/test` (already present) — no new job. Add to the `windows` job an artifact step that uploads nothing signed (CI never signs).

**Tests.** `tool/test/version_test.dart`: parse valid/invalid strings; compare (`1.0.0+7` < `1.0.0+8`, `1.0.1+1` > `1.0.0+999`, `1.10.0` > `1.9.0`); `sanitizeAndroidBuild(4007) == 7`, `(2012) == 12`, `(7) == 7`.

**Verify.** `dart test tool/test/version_test.dart`.

**Pitfalls.** Never compare versions as strings. Never put a build number ≥ 1000 in pubspec.

---

### 09.2 — Crash reporting core: reporter interface, scrubber, local crash log

**Purpose.** Capture crashes safely: always keep a **local** report; send to Sentry only with consent; never send note content or file paths.

**Files.** `app/lib/core/crash/crash_reporter.dart` (interface + `NoopCrashReporter`), `crash_service.dart`, `crash_consent.dart`, `event_scrubber.dart`,
`sentry_crash_reporter.dart`, `local_crash_log.dart`, `providers.dart` (edit `app/lib/core/providers.dart` to export `crashServiceProvider`), `app/lib/main.dart` (edit),
`app/lib/core/sentry_config.dart`, `secrets/sentry.example.json` (committed; `{ "TEPHRA_SENTRY_DSN": "REPLACE_ME" }`), tests under `app/test/core/crash/`.

**Implementation.**
1. Dependency: `flutter pub add sentry_flutter`; `dart run tool/check_licenses.dart`. Re-read its README for the current `SentryFlutter.init` / `SentryFlutterOptions` API (names below are the 8.x–10.x shape).
2. `sentry_config.dart`: `const sentryDsn = String.fromEnvironment('TEPHRA_SENTRY_DSN');` and `bool get crashReportingAvailable => sentryDsn.isNotEmpty && !sentryDsn.contains('REPLACE')`.
   Release builds pass `--dart-define-from-file=../secrets/sentry.json` (09.13 wires it). If unavailable, the consent dialog and the Settings switch are **hidden**, and the reporter is `NoopCrashReporter`.
3. `CrashConsent` — enum `CrashConsent { unknown, granted, denied }` stored in app-level settings as `crashReporting` (`"unknown"` default). Only the user's explicit action changes it from `unknown`.
4. `abstract interface class CrashReporter { Future<void> start(); Future<void> stop(); Future<void> capture(Object error, StackTrace? stack, {String? where}); bool get isActive; }`.
5. `LocalCrashLog` — **always on, independent of consent**, writes nothing to the network. `<appSupportDir>/logs/crash-<yyyyMMdd-HHmmss>.txt` containing: app version+build, platform, OS version string,
   Dart exception type name, **scrubbed** message (same rules as the scrubber, step 6), stack trace with paths reduced to `package:` form. Keep the newest 20 files. Settings → Privacy shows
   "Last crash report" with buttons "Open folder" and "Copy" so a user can attach it to an email manually.
6. `EventScrubber` — a pure class used by both the local log and Sentry's `beforeSend`:
   - `String scrubString(String s)`: apply in order (a) Windows paths `[A-Za-z]:\\[^\s"'<>|]*` → `<path>`; (b) UNC `\\\\[^\s"'<>|]+` → `<path>`; (c) Android/Unix absolute paths
     `/(storage|sdcard|data|home|Users|var|tmp|mnt)/[^\s"'<>|]*` → `<path>`; (d) `file://…` → `<path>`; (e) emails `[\w.+-]+@[\w-]+\.[\w.-]+` → `<email>`; (f) URLs: keep scheme+host only,
     drop path/query: `https://host/...` → `https://host/<redacted>`; (g) long hex/base64-ish tokens `[A-Za-z0-9+/_-]{32,}={0,2}` → `<token>`; (h) vault names cannot be matched by regex, so
     **additionally** replace every occurrence of the current vault display names and the user's OS user name (passed to the scrubber at start-up as a `Set<String> literals`, only those of length ≥ 3) with `<name>`.
   - `SentryEvent scrub(SentryEvent e, Object? original)`: remove `user`, `serverName`, `request`, `breadcrumbs`; clear `contexts.device` fields `name`, `model_id`, `device_unique_identifier`, `id`,
     `timezone`, `locale`, `memory_size`, `storage_size`, `free_storage`, `external_storage_size`, `external_free_storage` (keep `family`, `brand` for Android model **family only**, `arch`); for each exception:
     keep `value` **only if** `original is TephraException` (their messages are technical English by contract, §5.4) and then `scrubString(value)`, else set `value = '<redacted>'` (exception messages from Dart
     (`FormatException`, `RangeError`, `FileSystemException`) can embed note text or paths). Do **not** decide by `runtimeType.toString()` — release builds are obfuscated, class names are mangled.
     For each stack frame: set `absPath = null`, `fileName = frame.package != null ? 'package:<package>/<file>' : '<redacted>'`, clear `vars`, `contextLine`, `preContext`, `postContext`;
     `scrubString` the `function`. Remove `extra`, set `tags` to exactly `{ platform, abi? (android), appVariant: 'direct' }`. Set `event.message` = `null`.
7. `SentryCrashReporter` options (exact): `dsn = sentryDsn`; `release = 'tephra@<version>+<build>'` (from `package_info_plus`; on Android use `sanitizeAndroidBuild`); `dist = '<build>'`; `environment = kReleaseMode ? 'production' : 'debug'`;
   `sendDefaultPii = false`; `attachScreenshot = false`; `attachViewHierarchy = false`; `attachThreads = false`; `maxBreadcrumbs = 0`; `beforeBreadcrumb = (_, __) => null`; `enableAutoNativeBreadcrumbs = false`;
   `enableUserInteractionBreadcrumbs = false`; `enableUserInteractionTracing = false`; `enableAutoPerformanceTracing = false`; `tracesSampleRate = 0.0`; `profilesSampleRate = 0.0`;
   `enableAutoSessionTracking = true` (needed for the crash-free-session metric; sessions carry only release/environment); `autoAppStart = false`; `captureFailedRequests = false`;
   `reportSilentFlutterErrors = false`; `enableLogs = false` (disable the log forwarding feature if the installed version has it); `beforeSend = (event, hint) => scrubber.scrub(event, event.throwable)` (use the throwable the SDK exposes on the event; re-read the README for the exact field).
   `enabled` only when consent is `granted` **and** `kReleaseMode` (debug and profile builds never send).
8. `CrashService` — constructed in `main.dart` **before** `runApp`: reads consent; installs the local-log handlers **first** (they were already installed in Phase 0; extend them to call `localCrashLog.write` and then `reporter.capture` if active);
   if consent is `granted`, `await reporter.start()` (`SentryFlutter.init(options)` **without** `appRunner`, so our own bootstrap stays in control; Sentry chains to the handlers already installed — verify with the test below).
   `grant()` → persist `granted`, `start()`; `deny()` → persist `denied`, `stop()` (calls `Sentry.close()` immediately — turning it off takes effect at once); `revoke` is the same as `deny`.
9. Symbols: every release build uses `--obfuscate --split-debug-info=build/symbols/<platform>` (09.13). Upload to Sentry is optional: if the human wants it, `dart pub global activate sentry_dart_plugin` (check licence first), configure
   `sentry.properties`/`pubspec.yaml` `sentry:` block with `upload_debug_symbols: true`, `upload_sources: false`, `include_native_sources: false`, org `tephra`, project `tephra-app`, and the auth token from the environment variable `SENTRY_AUTH_TOKEN` (never in a file).
   If skipped, 09.13 archives the symbols zip per release so `flutter symbolize -d <zip contents>` can decode a stack trace by hand.

**Tests.** `event_scrubber_test.dart`: every regex rule with ≥ 3 positive and 2 negative examples (`C:\Users\Moinul\Documents\Vault\Secret plan.md`, `/storage/emulated/0/Documents/Vault/a.md`, `moinul@x.com`,
`https://api.example.com/v1/x?token=abc`, a 40-char token, a vault name literal); an event built with a `FormatException('bad: my diary text…')` throwable → `<redacted>`; the same with a `SyncException('quota')` →
kept (scrubbed); stack frames contain no `absPath`; `user`, `request`, `breadcrumbs`, `extra` are empty after `scrub`; `contexts.device.name` is gone. `crash_service_test.dart` with a fake reporter: consent `unknown` → reporter never started;
`grant` starts, `deny` stops; an error is always written to the local log, and forwarded only when active; local log keeps 20 files; an error thrown inside `capture` never propagates.
A "chain" test: install `FlutterError.onError` = recorder, run `CrashService` init with a fake reporter, call `FlutterError.reportError` → both the recorder and the local log saw it.

**Verify.** `cd app; flutter test test/core/crash`. Manual (release build later, 09.13): with consent granted and a deliberately thrown `StateError('secret note text C:\Users\x\Vault\a.md')` from a hidden command
`debug.crash-test` (registered only when `kDebugMode` **or** the build was made with `--dart-define=TEPHRA_CRASH_TEST=true`; debug and profile builds never send to Sentry, so build one **release** APK/Windows build with that define for this check, then rebuild without it and confirm the command is absent) the Sentry event shows no message, no path, no user.

**Pitfalls.** A scrubber bug is a privacy bug: every field the SDK sets automatically must be reviewed in the Sentry web UI "JSON" view of a real event (done in 09.3 verify). Never add `extra` data with note content.
Never initialise Sentry in debug/profile builds (noise + risk). Never block start-up on `reporter.start()` longer than 2 s (wrap in `Future.any` with a timeout; failure → continue without reporting).

---

### 09.3 — Crash reporting UI: first-run consent, Settings → Privacy, About

**Purpose.** Ask once, plainly, with no dark patterns; let the user change it any time; show what is sent.

**Files.** `app/lib/core/crash/ui/consent_dialog.dart`, `app/lib/settings/privacy/privacy_settings_page.dart`, `app/lib/settings/about/about_page.dart` (created here, extended in 09.16),
`app/lib/workspace/…` first-run hook (find how Phase 1 shows the vault picker first run), l10n keys, tests `app/test/core/crash/ui/*_test.dart`, `app/test/settings/privacy_settings_page_test.dart`.

**Implementation.**
1. **When asked:** the **first launch after this version is installed**, once the user is past the vault picker (never on top of a blocking error), if `crashReportingAvailable` and consent is `unknown`. A modal dialog (centred, max 480 dp; full-width bottom sheet on phone):
   - Title `crashConsentTitle`: "Help fix crashes?"
   - Body `crashConsentBody`: "If Tephra crashes, it can send a report to the developer. The report contains the app version, your phone/PC type and technical error details. It **never** contains your notes, file names, folder names, vault names, passwords or keys, and no account or IP address is stored. You can change this any time in Settings → Privacy."
   - Link "What exactly is sent?" → opens `PrivacyDetailsPage` listing the fields (derived from the scrubber rules in 09.2 — generate the list from a constant `CrashReportFields.sent` / `.neverSent` so text and code cannot drift).
   - Two **equal-weight** buttons: `crashConsentAllow` "Send crash reports" and `crashConsentDeny` "No thanks". No pre-checked box, no "remind me later", Back or tapping outside the dialog = "No thanks" (stored as `denied`; the question is never asked again unless the user opens Settings → Privacy).
2. `PrivacyDetailsPage` (also reachable from Settings → Privacy): the two lists, plus "See the last crash report on this device" (local crash file viewer, scrubbed text), plus a switch `privacyCrashReports` bound to consent (on = `granted`, off = `denied`; toggling applies immediately via `CrashService`).
3. Settings → Privacy also lists the other network destinations in plain language (from Phase 8's notes): Google Drive (only if sync is on), Anthropic and Voyage (only when you use AI features, with your key), Hugging Face (model downloads, no user data), the update server (one request per day when "Check for updates automatically" is on), Sentry (only if allowed above). Each row says what is sent and links to the privacy policy.
4. `AboutPage` (Settings → About): app name, version `1.0.0 (build 7)`, "Open-source licences" (`showLicensePage` plus `THIRD_PARTY_NOTICES.md` shown as a page), "Privacy policy" and "Terms (EULA)" (open URLs from 09.18/09.17 via `url_launcher`; URLs come from constants `legalPrivacyUrl`, `legalEulaUrl`, `downloadPageUrl` in `app/lib/core/release_links.dart`, taken from `--dart-define` `TEPHRA_PRIVACY_URL`, `TEPHRA_EULA_URL`, `TEPHRA_DOWNLOAD_URL`, empty = row hidden), "Check for updates" (09.16), "Copy diagnostics" (version, OS, device family, no paths).
5. All strings in `app_en.arb` (`crashConsent*`, `privacy*`, `about*`), with `@` descriptions for the placeholders.

**Tests.** Widget tests (phone 400 dp + desktop 1200 dp): dialog appears only when unknown + available; Allow → consent `granted`, reporter started; No thanks and outside tap → `denied`, never shown again; settings switch round trip; the "sent" list renders every constant; About page shows version and hides link rows whose URLs are empty.

**Verify.** `flutter test test/core/crash test/settings`. Manual on the Windows release build later (09.13): trigger the test crash with consent on and open the event in Sentry → inspect the raw JSON: no `user`, no `request`, no breadcrumbs, no absolute paths, message `<redacted>` for a non-Tephra exception. **Record the JSON field list in `docs/release/security-review.md`.**

**Pitfalls.** Do not show the dialog before the user can read it (not during the vault-picker transition). Do not call Sentry APIs from widgets — only `CrashService`.

---

### 09.4 — Performance re-profiling on the 4 GB Android phone and the Windows PC

**Purpose.** Prove every conventions §10 budget on the weakest device, fix regressions, record numbers. This step needs **H2**.

**Files.** `docs/release/perf-v1.0.md`, `tool/bench_adb.ps1` is **not** created (no wrapper scripts; commands are listed below and in the doc), fixes in whichever package/app files the profile points at, regression tests/benchmarks next to them.

**Implementation.**
1. Prepare: `dart run tool/gen_bench_vault.dart` (10k notes → `test_vaults/bench/`). Push it to the phone: `adb push test_vaults/bench /sdcard/Documents/TephraBench` (takes minutes). Use a **profile** build:
   `cd app; flutter run -d <phone-id> --profile --dart-define-from-file=../secrets/google_oauth.json`. On Windows: `flutter run -d windows --profile`.
2. Record the **device**: `adb shell getprop ro.product.model`, `adb shell getprop ro.build.version.release`, `adb shell cat /proc/meminfo | Select-String MemTotal`, `adb shell cat /proc/cpuinfo | Select-String Hardware`. Close all other apps; note battery saver off.
3. Measure, **three runs each, report median and worst**, in the table in `perf-v1.0.md` (columns: metric, budget, low-end phone median/worst, Windows median/worst, pass/fail):

   | Metric | How to measure | Budget |
   |---|---|---|
   | Cold start → editable note (after first index) | `adb shell am force-stop com.tephra.app`; `adb shell am start -W -n com.tephra.app/.MainActivity` prints `TotalTime`; add the app's own `Stopwatch` log line `startup.editable` (from process start to first editable frame, logged at `info`); use the latter | Android < 2.5 s, Windows < 1.5 s |
   | First full index of 10k notes | app log `index.full` duration, UI stays responsive (DevTools frame chart shows no jank > 32 ms during it) | < 60 s / < 20 s |
   | Typing latency, 5,000-line note | DevTools Performance → record while typing 50 characters; the per-frame UI build+raster time, p95 and max | < 16 ms |
   | Plain-text search, 10k notes | app log `search.query` for 5 fixed queries (`the`, `meeting notes`, `"exact phrase"`, `tag:#project`, `file:readme`) | < 200 ms |
   | Quick switcher results | log `switcher.query` for 5 typed prefixes | < 50 ms |
   | Memory, 10k-note vault open | DevTools Memory tab (RSS) and `adb shell dumpsys meminfo com.tephra.app` → "TOTAL PSS" after 5 minutes of use (open 20 notes, search, graph view, scroll) | Android < 350 MB, Windows < 500 MB |
   | Sync idle | with Drive sync on and idle for 10 min, CPU near 0 in DevTools; battery check in 09.9 | no jank |
   | Sync of 500 files | frame chart while a 500-file sync runs | no dropped frames > 32 ms |
   | Release APK size | 09.5 | < 40 MB per ABI |

4. Profile with **DevTools** (open from the `flutter run` output URL): Performance tab (frame analysis, "Track widget builds" on), CPU profiler (record a 10-s typing session; find the hottest functions), Memory tab (take a heap snapshot before/after opening 20 notes; look for retained `Editor`/`ParsedNote` instances after closing tabs = leaks), Network tab (no unexpected requests while idle — only the update check and sync polling).
5. For each failed or marginal (> 80% of budget) metric: find the cause in the profile, fix it, add a regression benchmark (`test/` with `Stopwatch` and a generous threshold, tagged `@Tags(['perf'])`, not run in default CI) or a unit test of the fixed behaviour, re-measure, and record before/after in the doc. Typical fixes to try, in order: avoid rebuilding the whole editor on each keystroke
   (granular providers `select`), move parsing of notes > 64 KiB to `Isolate.run`, cache `TextPainter` layouts, limit explorer rebuilds with `ListView.builder` + `itemExtent`, lower the number of simultaneous isolates, defer non-critical start-up work (AI index warm-up, OCR queue, backup schedule check) until 5 s after the first frame, lazy-load graph/canvas code paths.
6. Low memory: on the 4 GB phone also run `adb shell am send-trigger-memory-level com.tephra.app MODERATE`? (not available on all builds) — instead background the app with 10 other apps open and return after 5 minutes: the app must restore its tabs (Phase 1 workspace restore) with no data loss. Record "unsaved text survives process death": type text, wait 2 s (autosave), `adb shell am kill com.tephra.app`, reopen, text present.
7. Rule (GEMINI.md §5): a budget missed by > 25% after reasonable optimisation → stop and report with the profile evidence and your options (reduce scope, raise the budget for the low-end tier with the human's approval). Do not edit the budgets yourself.

**Tests.** Regression tests for each fix. Keep all existing tests green.

**Verify.** `perf-v1.0.md` is complete, shows the device model/RAM, and every row is pass or has an approved note. Re-run the standard commands.

**Pitfalls.** Never measure debug builds. Do not measure on a phone that is charging above 40 °C or on battery saver. A single run is not a measurement.

---

### 09.5 — APK size: split per ABI, obfuscation, R8, resource shrinking, icon tree-shaking

**Purpose.** Release APK < 40 MB per ABI, reproducibly.

**Files.** `app/android/app/build.gradle.kts` (edit), `app/android/app/proguard-rules.pro`, `docs/release/size-v1.0.md`, `tool/release/` later uses these flags.

**Implementation.**
1. Baseline: `Push-Location app; flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols/android --dart-define-from-file=../secrets/google_oauth.json; Pop-Location`. Output: `app/build/app/outputs/flutter-apk/app-<abi>-release.apk` for `armeabi-v7a`, `arm64-v8a`, `x86_64`. Record sizes in `size-v1.0.md` next to Phase 8's numbers.
2. Flags that must be **on** for every release build (09.13 hard-codes them): `--release`, `--split-per-abi` (plus a separate `--release` universal build), `--obfuscate`, `--split-debug-info=build/symbols/<platform>`, and icon tree-shaking (default in release; **never** pass `--no-tree-shake-icons` — if the build fails with "non-constant IconData", fix the code to use constant `Icons.x`/`IconData` literals).
3. R8/ProGuard in `app/android/app/build.gradle.kts`, `android { buildTypes { release { … } } }` (Kotlin DSL):
   ```kotlin
   release {
       signingConfig = signingConfigs.getByName("release")   // added in 09.10; until then keep debug signing
       isMinifyEnabled = true
       isShrinkResources = true
       proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
   }
   ```
   `proguard-rules.pro` starts with the Flutter embedding keep rules the Flutter docs list, then add **only** rules that a failing release run proves necessary, each with a comment naming the plugin (typical: `-keep class com.google.mlkit.** { *; }` for ML Kit, `-keep class com.tephra.app.InstallerChannel { *; }`, `-dontwarn` lines R8 prints as "Missing class", workmanager). Run the **full release smoke test** after enabling R8 (step 6) — R8 problems appear only at run time.
4. Remove unneeded native code: restrict ABIs to the three shipped (`ndk { abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64") }` is implicit with `--split-per-abi`; do not add `x86`). Check `app/android/app/build.gradle.kts` for leftovers (`packaging.jniLibs.pickFirsts`) and ensure ML Kit uses **only Latin** (Phase 8 rule), ONNX runtime only the needed ABIs.
5. `flutter build apk --release --analyze-size --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols/android` → read the printed tree and the `*-code-size-analysis_*.json` (open with DevTools → App Size → "Analyze size"). In `size-v1.0.md` list the top 10 contributors (libflutter.so, libapp.so, ONNX runtime, ML Kit, whisper, fonts, assets). Decisions to apply if > 40 MB: (a) move large assets/models to on-demand download (Phase 8 already downloads models; confirm nothing >1 MB is bundled that need not be), (b) drop unused fonts/assets from `pubspec.yaml`, (c) remove an unused plugin, (d) report to the human with the breakdown (Phase 8's gate allows reporting instead of passing; the **Phase 9 gate requires < 40 MB per ABI or the human's explicit written approval of the overrun** in `PROGRESS.md`).
6. **Release smoke test** on the 4 GB phone (a checklist file `docs/release/smoke-test.md`, run for every release candidate on both platforms): install; first-run screens; open vault from `/sdcard/Documents/TestVault`; edit + save + reopen; search; link/backlink; graph; sync setup with Drive (sign-in works with the **release** keystore only after 09.10 + H6); AI key entry (no request sent); OCR on a photo; voice note; sketch; encrypted folder unlock; app lock; stickies/widget/overlay; share-into-Tephra; import a zip; export PDF; backup now; open the user guide (09.19); About page; update check against a test manifest (09.16). Each item pass/fail with notes.

**Tests.** None new beyond the smoke test; Gradle must build with `isMinifyEnabled = true` from a clean checkout.

**Verify.** `size-v1.0.md` has the three APK sizes and the top-10 list; the smoke test passes on the phone with the R8 build.

**Pitfalls.** R8 can strip reflection-based plugin code silently: **a green build is not evidence** — run the smoke test. `--obfuscate` mangles Dart class names; nothing may depend on `runtimeType.toString()` (grep for `runtimeType` in `app/lib` and `packages/` and replace logic-bearing uses with `is` checks; logging-only uses are fine). Keep `build/symbols/android` per build; without it stack traces are unreadable.

---

### 09.6 — Security review (code, permissions, network, storage) — written result

**Purpose.** A checked, written review; fix what it finds.

**Files.** `docs/release/security-review.md`, `docs/release/permissions.md`, fixes + tests as needed, `app/android/app/src/main/AndroidManifest.xml` (edit).

**Implementation.** Go through every row; for each write **Finding / Evidence (file:line or command output) / Action / Status** in `security-review.md`. Fix every "fail" before 09.20.

1. **Encryption code review (Phase 3 sync + Phase 8 notes encryption).** Checklist: (a) AES-GCM nonce never reused with one key (each object has a fresh HKDF salt + random nonce; grep for every `seal`/`encrypt` call and confirm it goes through `ObjectCipher`/the Phase 8 cipher); (b) no custom primitives (`grep -r "xor\|rotl\|sbox"` in `packages/tephra_sync` and the Phase 8 crypto package returns nothing suspicious); (c) KATs still pass (`dart test test/crypto`); (d) Argon2id parameters ≥ floor everywhere a password is derived; (e) keys/passwords are never logged (`Grep` for `masterKey|password|recovery|refreshToken|apiKey` in `Logger` calls; each log line reviewed); (f) secrets only in `flutter_secure_storage` (list every key written: `tephra.*`, `ai.*`) and never in `settings.json`, `.tephra/`, the sync DB or crash logs; (g) in-memory secrets are zeroed where the API allows and the app does not keep the password in provider state after use (03.18 Pitfall); (h) timing: no secret compared with `==` on strings; (i) tamper tests (flip one byte) still fail closed; (j) `Random.secure()` everywhere keys/salts/nonces are generated (`Grep "Random("` — every non-secure `Random` must be in tests only).
2. **Secrets and repository hygiene.** Run `gitleaks detect --source . --no-banner` (the human has CI gitleaks; locally use `docker run` only if Docker exists, otherwise rely on CI and run `git log -p | Select-String -Pattern 'AIza|GOCSPX|ghp_|sk-ant|-----BEGIN'` manually). `git ls-files secrets` must list only `*.example.json`. `git check-ignore` prints the path for `secrets/key.properties`, `*.jks`, `secrets/sentry.json`.
3. **Network.** Android: `android:usesCleartextTraffic="false"` in the main manifest (debug builds may allow cleartext through `app/android/app/src/debug/AndroidManifest.xml`; Phase 10's LAN dev server uses that). Enumerate every outbound host from code (`Grep "https://"` and `Uri.parse(`) and compare with the privacy-policy list (09.18): `www.googleapis.com`, `oauth2.googleapis.com`, `accounts.google.com`, `api.anthropic.com`, `api.voyageai.com`, `huggingface.co`, the update host, `*.ingest.sentry.io`. Anything else = finding. All HTTP clients validate TLS (no `badCertificateCallback` anywhere: `Grep badCertificateCallback` must be empty).
4. **Storage.** Android manifest: `android:allowBackup="false"` (the vault is user-visible files; app-private data holds the keys; auto-backup would copy secure-storage-adjacent data to Google), `android:fullBackupContent`/`dataExtractionRules` absent or empty, `android:debuggable` not set. Windows: app data under `%APPDATA%`/`%LOCALAPPDATA%` only, no secrets in files. The vault `.tephra/` folder contains no secrets (grep the folder of a configured test vault for the master key base64 and any token: zero matches).
5. **Permissions audit** → `permissions.md`. Produce the **merged release manifest** (`app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`, or `aapt2 dump permissions app-arm64-v8a-release.apk` using `D:\dev\android-sdk\build-tools\36.0.0\aapt2.exe`) and list **every** permission with: who declared it (app or which plugin), why it is needed, which feature breaks without it, and whether it is requested at runtime. Expected set and justifications (adjust to the real result): `INTERNET` (sync, AI, updates); `MANAGE_EXTERNAL_STORAGE` (vault in shared storage, Obsidian compatibility; exact Play wording in Phase 11); `READ_EXTERNAL_STORAGE maxSdk 32`, `WRITE_EXTERNAL_STORAGE maxSdk 29` (legacy);
   `POST_NOTIFICATIONS` (reminders, sync notice); `RECORD_AUDIO` (voice notes, runtime only); `CAMERA` (only if scan/capture feature exists); `SYSTEM_ALERT_WINDOW` (floating capture bubble, Phase 4, runtime via settings page); `FOREGROUND_SERVICE*` (only if a service type is declared; if present, confirm the type is justified); `RECEIVE_BOOT_COMPLETED` (workmanager reschedule); `USE_BIOMETRIC` (app lock);
   `REQUEST_INSTALL_PACKAGES` (added in 09.15 for in-app updates; **removed in the Play build in Phase 11**); `WAKE_LOCK` (workmanager); `ACCESS_NETWORK_STATE` (Wi-Fi-only sync). Any permission a plugin adds that no feature needs → remove it with `<uses-permission android:name="…" tools:node="remove" />` in the app manifest (add `xmlns:tools`). Re-generate the merged manifest and re-check.
6. **Intents/exported components.** Every `<activity>`, `<service>`, `<receiver>`, `<provider>` in the merged manifest: `android:exported` explicitly set; only the launcher activity and the share/VIEW intent filters Tephra intends are exported; FileProvider `exported="false"` with `grantUriPermissions="true"`.
7. **WebView / HTML.** Note rendering must never execute HTML/JS (conventions §6.3 "never executed"): `Grep -r "WebView\|webview_flutter\|flutter_inappwebview"` — if any package is used (e.g. Mermaid/math rendering), list what loads, confirm JS is limited to bundled assets, no remote URLs, no `file://` access to the vault. Link taps open in the **system browser**, only `http/https/mailto` schemes (unit test with `javascript:`, `file:`, `intent:` URLs → blocked).
8. **Path traversal / zip slip.** Import (Phase 5) and restore (03.23) must reject entries with `..`, absolute paths, drive letters, NUL bytes: unit test with a crafted zip (use `archive` to create `../evil.md`, `C:\evil.md`, `a/../../b.md`) for every importer that unzips, and for backup restore with crafted paths in a manifest → all rejected with a clear error and nothing written outside the target.
9. **Update channel** (09.14–09.16) is part of this review; revisit after those steps and tick the rows: manifest signature verified before anything is downloaded; SHA-256 verified before install; HTTPS only; refuses downgrade; the APK installer intent only points at our FileProvider path.
10. **Dependency audit.** `dart pub outdated --no-dev-dependencies` and `dart pub deps --style=list` for each package; for each dependency with a published security advisory (check https://osv.dev for the package names with `https://api.osv.dev/v1/query`: `Invoke-RestMethod -Method Post -Uri https://api.osv.dev/v1/query -Body (@{package=@{name='<pkg>';ecosystem='Pub'}} | ConvertTo-Json) -ContentType 'application/json'` for the 20 most security-relevant packages: `http`, `archive`, `xml`, `yaml`, `cryptography`, `sentry_flutter`, `flutter_secure_storage`, `google_sign_in`, `url_launcher`, `file_picker`, `sqlite3`, `drift`, `path_provider`, `workmanager`, plus Phase 8 AI/OCR/ONNX packages) update or document.
11. Apply fixes with tests; every fix = a regression test (GEMINI rule 12).

**Tests.** The link-scheme test, the zip-slip tests, a test that scans `app/lib` for `badCertificateCallback`, `print(`, `debugPrint(` outside `kDebugMode`, and `http://` literals (allow-list: `http://localhost`, `http://127.0.0.1`, `http://schemas.android.com`), written as a Dart test in `tool/test/hygiene_test.dart` so CI keeps them true.

**Verify.** `docs/release/security-review.md` has every row with a status; no open "fail". `dart test tool/test`.

**Pitfalls.** Do not "review" by reading your own summary — run the commands and paste the evidence. A permission left in because a plugin added it is a finding.

---

### 09.7 — Licence review and third-party notices

**Purpose.** Prove every shipped dependency (Dart, native, models, fonts, assets) is permitted and credited.

**Files.** `docs/release/licence-review.md`, `THIRD_PARTY_NOTICES.md` (regenerated), `app/assets/licenses/extra_licenses.json` (native/model/font entries not covered by pub), `tool/check_licenses.dart` (extend only if needed), tests `tool/test/`.

**Implementation.**
1. `dart run tool/check_licenses.dart` (full, not `--no-notices`) → regenerates `THIRD_PARTY_NOTICES.md`. Must report zero GPL/LGPL/AGPL/unknown.
2. **Non-pub components**, each with name, version, licence, URL, and where it is bundled — add to `extra_licenses.json` and `licence-review.md`: Flutter engine (BSD-3), Skia/Impeller (BSD-3), Dart SDK (BSD-3), ICU (Unicode licence), HarfBuzz (MIT), FreeType (FTL/BSD-like), ONNX Runtime (MIT), the embedding model `multilingual-e5-small` (MIT), whisper.cpp (MIT) and the Whisper model weights (MIT), ML Kit text recognition (Google ML Kit Terms — closed-source binary, human accepted in Phase 8), Windows OCR plugin (own code), SQLite (public domain), fonts bundled in `app/assets/fonts/` (each font's licence file: OFL/Apache), icons (Material Icons Apache-2.0), Mermaid/KaTeX/other JS bundled assets (MIT) if any, Sentry native SDK (MIT), Inno Setup runtime stub in the installer (Inno Setup licence permits redistribution of the installer it creates), the **VC++ runtime DLLs** bundled app-local (09.11; Microsoft Visual C++ Redistributable terms permit app-local deployment — keep the licence text in the notices).
3. In-app page lists `THIRD_PARTY_NOTICES.md` (09.3) — load it from `app/assets/licenses/THIRD_PARTY_NOTICES.md` (copied by `tool/check_licenses.dart` or by 09.13 before build; add the copy step and a test that the asset exists and is non-empty).
4. A dependency whose licence changed since it was added (e.g. a package moved to a non-permissive licence in a newer version): compare `pubspec.lock` versions with the versions recorded in the previous notices file; any licence change → stop and ask the human.
5. Confirm there is **no copied code** from Obsidian or GPL projects (GEMINI rule 8): grep for attribution comments (`Copyright`, `SPDX`, `GPL`) in `app/lib`, `packages/` and fix/ask.
6. The EULA/privacy mention third-party components generically and point to the in-app notices page.

**Tests.** A test in `tool/test/licences_test.dart`: `extra_licenses.json` parses, each entry has `name/version/licence/url`; `THIRD_PARTY_NOTICES.md` contains every direct dependency name from every `pubspec.yaml`.

**Verify.** `dart run tool/check_licenses.dart` passes; review doc complete.

**Pitfalls.** "Free to use" is not a licence. If a model or font has no clear licence file, replace it or ask the human; do not ship it.

---

### 09.8 — Data-safety drills A: disk full, corrupted index, corrupted sync state

**Purpose.** Prove (with automated regression tests + one manual real-device run) that the app loses nothing and recovers by itself.

**Files.** `packages/tephra_vault/test/support/faulty_vault_fs.dart`, `packages/tephra_vault/test/drills/disk_full_test.dart`,
`packages/tephra_index/test/drills/corrupt_index_test.dart`, `packages/tephra_sync/test/drills/corrupt_sync_state_test.dart`, fixes in `packages/tephra_vault/lib/src/io_vault_file_system.dart`,
`packages/tephra_index/lib/src/…`, `packages/tephra_sync/lib/src/store/…`, app l10n/UI for the repair banners, `docs/release/data-safety-drills.md` (a running log, one section per drill: date, method, result, fix, regression test).

**Implementation.**
1. **Drill D1 — disk full while saving.**
   - Automated: `FaultyVaultFileSystem(VaultFileSystem inner)` wrapper in test support: `failWriteAfter(int n, Object error)` throws on the nth `writeBytes/writeText` (a `FileSystemException('No space left on device', path, OSError('No space left on device', 28))` on Android; `OSError('There is not enough space on the disk.', 112)` on Windows). Also a variant that fails **after writing the temp file but before rename**, and one that fails mid-write (the temp file is truncated). Tests against `IoVaultFileSystem` on a real temp directory using a tiny helper that simulates the error by injecting a failing `File` factory (constructor parameter `FileOpener`, default real) — add that seam to `IoVaultFileSystem` (additive, default unchanged).
   - Asserted behaviour (fix the code until true): the **original file is byte-identical** after a failed write; no `*.tephra-tmp` leftovers (cleaned in `finally`, and a start-up sweep deletes stale `*.tephra-tmp` older than 1 hour in the vault; sweep must never touch other files); the exception surfaces as `PermissionDeniedException`? No — add `VaultStorageFullException extends TephraException` in `tephra_core` (**additive**; conventions §7.1 lists base classes and says other packages extend them; core is the right home, note it in `PROGRESS.md` as a contract addition) thrown by `IoVaultFileSystem` when the OS error is ENOSPC (28) / ERROR_DISK_FULL (112) / ERROR_HANDLE_DISK_FULL (39) / EDQUOT (122); the editor keeps the unsaved text **in memory and in a recovery file in app support** (`<appSupportDir>/recovery/<vaultId>/<pathHash>.md`, written only if that write succeeds; also fails gracefully) and shows a persistent banner `editorErrorDiskFull` "Your device is full. Your latest changes are not saved yet. Free up space, then tap Retry." with Retry; autosave retries every 30 s; once saved the recovery file is deleted; on next start, if a recovery file is newer than the note, offer "Recover unsaved changes". Same for sync: `SyncEngine` maps the exception to status `error` with `syncErrorDeviceFull`; downloads that would not fit pause (check `fs`-level exception, keep the plan unapplied), uploads continue.
   - Manual, Android: `adb shell df /sdcard` → fill with `adb shell "dd if=/dev/zero of=/sdcard/fill.bin bs=1M count=<free-MB minus 3>"`; type in a note for 30 s → banner appears, no crash; `adb shell rm /sdcard/fill.bin` → autosave succeeds within 30 s, text present. Manual, Windows (needs administrator → ask the human or skip with a note): create a 20 MB VHDX with `diskpart` (`create vdisk file=C:\tephra-full.vhdx maximum=20 type=fixed` → `attach vdisk` → `create partition primary` → `format fs=ntfs quick` → `assign letter=T`), put a vault on `T:`, fill it with `fsutil file createnew T:\fill.bin <bytes>`, repeat the test; detach and delete the VHDX afterwards. Record in the drill log.
2. **Drill D2 — corrupted search index → automatic rebuild.**
   - Cases (each a test on a real temp SQLite file produced by `NoteIndex.open`): (a) file truncated to half; (b) first 100 bytes zeroed; (c) random bytes appended inside; (d) the `-wal` file deleted/garbage; (e) a zero-byte file; (f) an index from a newer schema version; (g) a file that is not SQLite at all (text).
   - Required behaviour: `NoteIndex.open` never throws these to the app. On `SqliteException` or `PRAGMA quick_check` ≠ `ok` or schema-version mismatch: rename the bad file to `<name>.corrupt-<yyyyMMddHHmmss>` (keep newest 2, delete older), create a fresh DB, set a flag so `reconcile()` performs a full `rebuild()` in the background, log `warning` `index.recovered`, and the UI shows a dismissible info `indexRebuilt` "Search was rebuilt. This can take a minute." Notes and user files are never touched (the index lives outside the vault, conventions §6.6). Also handle a failure **during** use (query throws `SqliteException`): one automatic recovery attempt per session, then a persistent "Search is unavailable — Rebuild now" action (`index.rebuild` command).
   - After recovery the app's own queries return the same results as before (golden comparison against a pre-corruption snapshot of `allNotes()`, `backlinks()`, `fullText('word')` on the `syntax` fixture vault).
3. **Drill D3 — corrupted sync state DB.**
   - The sync DB is the engine's memory (bases, cursors, device id). Cases as in D2. Required: `SyncStateStore.open` throws a new `SyncStateCorruptException extends SyncException` (in tephra_sync; add to `sync_exceptions.dart` with a test) after renaming the bad file to `<vaultId>.sqlite.corrupt-<ts>`; the engine stops with status `error`/`syncStateDamaged`; the UI banner `syncStateDamaged` "Sync information on this device was damaged. Your notes are safe. Tap Repair to reconnect." → **Repair** runs the setup wizard pre-filled for the same remote vault with first-sync choice **Merge both** forced (no destructive option exists, 03.18) and a **new device id** (a fresh install behaves like a clone, 03.7 item 7); the master key remains in secure storage so the password is not asked again if it is present; otherwise the unlock page appears.
   - Test: corrupt the file → open throws `SyncStateCorruptException`; simulate the repair with `MemorySyncProvider` + two devices: no file content lost on either device; conflicts produce copies, never overwrites.
4. Run the three drills on the real phone **after** 09.5's R8 build (R8 can break exception types) and record results.

**Tests.** As above; all deterministic with fixed seeds. Include the regression tests permanently.

**Verify.** `dart test` in `tephra_vault`, `tephra_index`, `tephra_sync`; drill log sections D1–D3 filled.

**Pitfalls.** Never "fix" a corrupt index by deleting anything inside the vault. Never auto-delete the corrupt file immediately (keep two for diagnosis). Never retry a failed atomic write by writing the destination directly.

---

### 09.9 — Data-safety drills B: kill during sync, corrupted remote data

**Purpose.** Prove crash-safety with real process kills and the remote-corruption behaviour (documented resolution below).

**Files.** `packages/tephra_sync/test/support/directory_sync_provider.dart` (test-only `SyncProvider` that stores each object as a file under a directory, atomic writes, so two processes can share a "remote"),
`packages/tephra_sync/test/drills/crash_points_drill_test.dart`, `tool/drill_kill_sync.dart`, `packages/tephra_sync/test/drills/corrupt_remote_test.dart`,
`packages/tephra_sync/lib/src/engine/damaged_remote.dart` (+ small engine/reader edits), app banner/screen `app/lib/sync_ui/damaged/damaged_remote_screen.dart`, `docs/release/data-safety-drills.md`.

**Implementation.**
1. **Drill D4a — random executor crash points (in-process, 1,000 seeds).** Extend the Phase 3 simulator: `crash_points_drill_test.dart` runs 1,000 seeded scenarios; each scenario = a populated 3-device world (≥ 40 files, mixed text/binary, one 6 MiB file) with pending edits on every device, then **one to three** crashes
   injected at random `CrashPoint`s (including *during* blob uploads and between `afterJournalPut` and `afterCommitStateUpdate`) on random devices, each followed by a restart (new engine, same FS + store). Then convergence rounds as in 03.12. Same invariants (no loss, convergence, no forks). Env `TEPHRA_DRILL_SEEDS` (default 200 in CI, 1,000 locally and nightly).
2. **Drill D4b — real process kills.** `tool/drill_kill_sync.dart` (run with `dart run tool/drill_kill_sync.dart --iterations 200 --seed 1`): creates a temp root with `vaultA/`, `vaultB/`, `remote/`, `state/`; spawns `dart run tool/drill_kill_sync.dart --child <role>` processes (the same file in child mode: builds an `IoVaultFileSystem`, file-backed `SyncStateStore`, `DirectorySyncProvider(remote)`, `EncryptingObjectCipher` with a fixed key, runs `syncOnce`). The parent loop: mutate files in a vault (random edits/creates/deletes using the seed), start a child, wait a random 20–1,500 ms, **`Process.kill(ProcessSignal.sigkill)`** (on Windows `Process.kill` terminates immediately), run a clean sync for that device, and every 10 iterations run a full convergence check (both devices sync until quiet; `mustSurvive` hashes found in a vault, trash, history or remote). Prints `DRILL FAILURE seed=<n> iteration=<i> <message>` + the last 20 actions. Pass = 200 iterations on Windows and 0 failures. Record duration.
3. **Drill D4c — Android force-stop.** With a 500-file vault on the phone syncing to Drive (or the fake Drive server over `adb reverse tcp:<port> tcp:<port>` if offline testing is preferred): start a sync, and `adb shell am force-stop com.tephra.app` at random intervals (PowerShell loop: `1..30 | % { adb shell am start -n com.tephra.app/.MainActivity; Start-Sleep -Milliseconds (Get-Random -Min 500 -Max 6000); adb shell am force-stop com.tephra.app }`), then open normally and let it finish. Compare the vault file list + hashes with the PC (`Get-ChildItem -Recurse -File | Get-FileHash` on both; `adb pull` the phone vault) → identical (conflict copies allowed only where edits were made on both sides). Record.
4. **Drill D5 — corrupted remote data.** The behaviour contract (resolution of "skip + report" versus Phase 3's "never skip a gap", stated here so no one reinterprets it):
   - Detection (already in Phase 3): a journal batch that fails to decrypt/parse/validate stops reading **that device's** journal at that batch (its later batches are **quarantined**, not applied); every other device keeps syncing; the engine reports `DamagedRemote` instead of a generic error.
   - **Report:** status `needsAttention`, banner `syncDamagedRemoteBanner` "Some synced data from \<device\> is damaged." → `DamagedRemoteScreen` listing: device name, batch key (`journals/<id>/0000000041.json.enc` shown as "batch 41"), first/last seq if readable, reason (`tampered`, `unreadable`, `format`), and the effect ("changes made on \<device\> after <time> are not applied here yet").
   - **Actions (user-chosen, never automatic):** (a) **"Skip the damaged batch and continue"** — records `skippedBatches` (JSON list of `{deviceId, firstSeq}`) in the sync DB `meta`, treats that seq range as present-but-empty for cursor purposes, and continues reading the device's next batches. Entries that reference parents inside the skipped batch have unknown parents; `RemoteHistory` already ends walks at unknown ids and the planner then yields `Rgone`/fork rows, which republish or merge — **never delete** (03.10 rows 6, 12, 20). The skip is local to this device; the damaged remote object is left untouched. (b) **"Check remote data"** — runs `RemoteVerifier`: full read of all journals/snapshots/manifests and a download+hash check of every head's blobs; produces a list of damaged keys. (c) **"Repair from this device"** (offered when this device holds the affected files): `SyncEngine.republishPaths(List<VaultPath>)` stages normal `put` entries (fresh blobs, `parent = current head`) for those paths **bypassing rule zero**, so a corrupted blob is replaced by a new entry that points at new blobs; history keeps the old (broken) entry, shown as "no longer available".
   - Damaged **snapshot** → ignored (snapshots are an optimisation; bootstrap falls back to journals); GC aborts if any journal/manifest is unreadable (03.23 rule, unchanged). Damaged **`vault.json`** → `RemoteFormatException` as before (never auto-replaced). Damaged **blob** (hash mismatch or tag failure) → that file's download is skipped with a `fine` log + counted in the report; other files proceed; status `needsAttention` "N files could not be downloaded".
   - Implement `DamagedRemote` (sealed: `DamagedJournal(deviceId, firstSeq, reason)`, `DamagedBlob(key, path)`, `DamagedSnapshot(key)`) and the plumbing in `JournalReader`/`BlobStore`/`SyncEngine`, the screen and l10n (`syncDamagedRemote*` keys).
   - Corruption injectors for tests: flip a byte in a journal batch; truncate it; replace it with another vault's batch (wrong vault id → AAD mismatch); delete a middle batch (gap, must **wait**, not skip, and report `gap` after 24 h of no progress with `syncGapBanner`); flip a byte in a blob; make a snapshot unreadable; make `vault.json` invalid JSON.
5. Run D5 on the real remote once (a test vault on Drive, damage a journal file by editing/replacing it in the Drive web UI is not possible for encrypted content — instead use the fake Drive server in a test or the `DirectorySyncProvider` on the PC; record "real Drive not used for D5").

**Tests.** The drill tests above; `corrupt_remote_test.dart` asserts for each injector: other devices' data still applies; the damaged device's later batches are quarantined; the UI-facing `DamagedRemote` value is produced; "skip" lets the reader continue and the planner never emits a delete for paths whose history became unknown; `republishPaths` makes a corrupted blob readable again; the gap case waits and then reports.

**Verify.** `dart test test/drills` (packages/tephra_sync, defaults) and `dart run tool/drill_kill_sync.dart --iterations 200 --seed 1` pass; drill log D4–D5 filled with durations and seeds.

**Pitfalls.** A drill failure is a real bug: fix the engine, add the failing seed as a fixed regression test, never loosen an invariant. `Process.kill` on a child that holds `RandomAccessFile.lock` releases it at once (OS closes handles) — that is the point; the next run must acquire the lock.

---
### 09.10 — Android release signing (keystore, `key.properties`, Gradle wiring, backup)

**Purpose.** Every public APK is signed by one long-lived key that only the human holds, with a written backup procedure. Needs **H3** (decided at the start) and, for the Google client, **H6**.

**Files.** `app/android/key.properties.example` (committed), `app/android/app/build.gradle.kts` (edit), `docs/release/KEY_BACKUP.md`, `docs/release/signing-cert.md` (public fingerprints), `.gitignore` (check only).

**Implementation.**
1. **The human creates the keystore** (Gemini must not see the passwords; Gemini prints the command, the human runs it in their **own** PowerShell window and answers the prompts):
   ```
   & "C:\Program Files\Java\jdk-17\bin\keytool.exe" -genkeypair -v `
     -keystore "D:\script\tephra-gemini\secrets\tephra-upload.jks" `
     -alias tephra-upload -keyalg RSA -keysize 4096 -validity 10000 `
     -dname "CN=<owner name>, O=<company or owner>, C=BD"
   ```
   keytool then asks for the keystore password and key password (the human types the values chosen in H3; if keytool offers "Re-enter new password", repeat the same). `-validity 10000` = ~27 years (Google Play requires validity to 2033 or later; Android requires the certificate to outlive the app).
   The file lands in the git-ignored `secrets/` folder (`*.jks` is also in `.gitignore`). Gemini then verifies only that the file exists: `Test-Path secrets\tephra-upload.jks` and `git check-ignore secrets/tephra-upload.jks` prints the path.
2. **The human prints the public fingerprints** and pastes them to Gemini (they are not secret): `& "C:\Program Files\Java\jdk-17\bin\keytool.exe" -list -v -keystore "D:\script\tephra-gemini\secrets\tephra-upload.jks" -alias tephra-upload` (asks the password). Gemini writes `SHA-1` and `SHA-256` and the validity dates into `docs/release/signing-cert.md`; the tool in 09.13 compares every built APK against this SHA-256. Gemini also gives the SHA-1 to the human for **H6** (second Android OAuth client).
3. `app/android/key.properties.example` (committed):
   ```
   storePassword=REPLACE_ME
   keyPassword=REPLACE_ME
   keyAlias=tephra-upload
   storeFile=../../secrets/tephra-upload.jks
   ```
   (`storeFile` is resolved with `rootProject.file(...)`; `rootProject` is `app/android`, so `../../secrets/…` is `<repo>/secrets/…`.) The human copies it to `app/android/key.properties` (git-ignored by the `key.properties` rule) and types the two passwords into it **in their own editor**. Gemini checks `git check-ignore app/android/key.properties` prints the path and that `git status` does not list it.
4. `app/android/app/build.gradle.kts` (Kotlin DSL) — add at the top `import java.util.Properties` and:
   ```kotlin
   val keystoreProps = Properties().apply {
       val f = rootProject.file("key.properties")
       if (f.exists()) f.inputStream().use { load(it) }
   }
   android {
       signingConfigs {
           create("release") {
               if (keystoreProps.isNotEmpty()) {
                   keyAlias = keystoreProps.getProperty("keyAlias")
                   keyPassword = keystoreProps.getProperty("keyPassword")
                   storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                   storePassword = keystoreProps.getProperty("storePassword")
               }
           }
       }
       buildTypes {
           release {
               signingConfig = if (keystoreProps.isNotEmpty()) signingConfigs.getByName("release") else null
               isMinifyEnabled = true
               isShrinkResources = true
               proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
           }
       }
   }
   gradle.taskGraph.whenReady {
       val wantsRelease = allTasks.any { it.name.contains("Release", ignoreCase = true) && it.name.startsWith("assemble") }
       if (wantsRelease && keystoreProps.isEmpty()) {
           throw GradleException("Release build needs app/android/key.properties (see docs/release/KEY_BACKUP.md). Refusing to sign with the debug key.")
       }
   }
   ```
   This **fails loudly** instead of silently producing a debug-signed "release" APK. Profile builds keep using the debug key (Flutter's profile type), which is correct for `flutter run --profile`.
5. `docs/release/KEY_BACKUP.md` (committed, contains no secrets): (a) what the key is and that **losing it means no user can ever update the app** (Android refuses an APK signed by a different key; the only way out is a new application id and users reinstalling manually); (b) the **backup checklist** the human ticks and dates: copy `tephra-upload.jks` to two offline places (H3 step 2); store the two passwords in the human's password manager; do not email or chat them; (c) a **restore test** to repeat yearly: copy the backup to a temp folder and run `keytool -list -keystore <copy>` — the SHA-256 must equal `signing-cert.md`; (d) the key is never used in CI and never leaves the PC except into the two backups; (e) Phase 11 note: Play Store can hold a copy of the signing key (Play App Signing) — decision deferred to Phase 11.
6. Warn the human **in the chat message of this step** (plain language, once): "Back up secrets/tephra-upload.jks and both passwords in two separate places today. If they are lost you can never update Tephra for existing users."
7. Add the Google release client (H6 step 1) and record "Google release client ready" in `PROGRESS.md`; the release build can sign in to Drive only after that.

**Tests.** None automated. Manual: a `flutter build apk --release` **without** `key.properties` fails with the GradleException message (rename the file temporarily to prove it); with it, the APK verifies:
`& "D:\dev\android-sdk\build-tools\36.0.0\apksigner.bat" verify --verbose --print-certs app\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` prints `Verified using v2 scheme (APK Signature Scheme v2): true` (and v3) and the certificate SHA-256 equals the one in `signing-cert.md`.

**Verify.** As above; `git status` shows no keystore or key.properties.

**Pitfalls.** Never commit or paste the keystore, passwords or `key.properties`. Do not change `keyAlias`/the key after v1.0 ships. If the human wants the passwords stored in environment variables instead, that is acceptable (`storePassword = System.getenv("TEPHRA_STORE_PASSWORD")`), but the file approach above is the documented default.

---

### 09.11 — Windows release build, bundled runtime, Inno Setup installer

**Purpose.** A double-click installer: per-user by default, Start-menu shortcut, optional desktop shortcut, uninstaller, no separate VC++ redistributable. Needs **H5**.

**Files.** `installer/tephra.iss`, `installer/README.md`, `tool/release/windows_stage.dart` (stage folder + runtime DLLs), `docs/legal/EULA.txt` (generated in 09.18; for now a one-line placeholder so the script compiles), `app/windows/runner/resources/app_icon.ico` (exists from Flutter; replace with the Tephra icon if Phase 0 created one), tests `tool/test/windows_stage_test.dart`.

**Implementation.**
1. Install Inno Setup 6 (H5). Confirm: `& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /?` prints the usage (or the per-user path).
2. **Release build command** (from `app/`; `--obfuscate` mangles names, `--split-debug-info` writes symbols next to the build):
   ```
   flutter build windows --release --obfuscate --split-debug-info=build/symbols/windows `
     --dart-define-from-file=../secrets/google_oauth.json --dart-define-from-file=../secrets/sentry.json --dart-define-from-file=../secrets/release.json
   ```
   Output folder: `app\build\windows\x64\runner\Release\` containing `tephra.exe` (the name comes from `BINARY_NAME` in `app/windows/CMakeLists.txt`; confirm it, and if it differs use the real name everywhere below), `flutter_windows.dll`, plugin DLLs, `data\` (with `app.so`, `icudtl.dat`, `flutter_assets`).
   `secrets/release.example.json` (committed) = `{ "TEPHRA_UPDATE_MANIFEST_URL": "", "TEPHRA_PRIVACY_URL": "", "TEPHRA_EULA_URL": "", "TEPHRA_DOWNLOAD_URL": "" }`; the real `secrets/release.json` is filled when H4 is known (09.14/09.17).
3. **Bundle the VC++ runtime app-locally** (decision: no redistributable installer; Microsoft's Visual C++ Redistributable terms permit app-local deployment of these files). `tool/release/windows_stage.dart` copies `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll` **from the Visual Studio redist folder**, not from `System32` (the files in System32 may be newer than what the build used and are not licensed for copying):
   find `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC\<newest version>\x64\Microsoft.VC143.CRT\` (search for `Microsoft.VC14*.CRT` under `VC\Redist\MSVC\*\x64\`, take the newest version folder), copy the three DLLs next to `tephra.exe` in a **staging copy** of the Release folder (`dist/stage/windows/`), never into `build/`. If a plugin DLL needs `msvcp140_1.dll`/`msvcp140_2.dll`/`concrt140.dll`, `dumpbin /dependents` shows it — copy those too (run `dumpbin` from a "Developer PowerShell for VS" or by full path under `...\VC\Tools\MSVC\<ver>\bin\Hostx64\x64\dumpbin.exe`; list every DLL of the staging folder and every `*.dll` dependency not found in the folder and not a Windows system DLL; write the result to `docs/release/windows-deps.md`).
   Test: on this PC the staged `tephra.exe` must start with `PATH` stripped of the VS paths, and — better — on a **clean Windows 10 VM or a Windows Sandbox** session (Windows Sandbox: enable the optional feature if the human agrees; copy the installer in via a mapped folder) the installer runs and the app starts with no "VCRUNTIME140.dll was not found" dialog. Record it.
4. **`installer/tephra.iss`** — write exactly this (adjust only the marked values):
   ```
   ; Tephra installer. Build with:  iscc /DAppVersion=1.0.0 /DAppVersion4=1.0.0.7 /DSourceDir=<staged folder> /DOutputDir=<dist folder> installer\tephra.iss
   #ifndef AppVersion
     #error Pass /DAppVersion=<major.minor.patch>
   #endif
   #ifndef AppVersion4
     #define AppVersion4 AppVersion + ".0"
   #endif
   #ifndef SourceDir
     #define SourceDir "..\dist\stage\windows"
   #endif
   #ifndef OutputDir
     #define OutputDir "..\dist"
   #endif

   [Setup]
   ; NEVER change AppId: it is how upgrades find the previous install.
   AppId={{B7E3C1A4-5D2F-4E8B-9A16-3F0C7D2E48A1}
   AppName=Tephra
   AppVersion={#AppVersion}
   AppVerName=Tephra {#AppVersion}
   VersionInfoVersion={#AppVersion4}
   AppPublisher=Tephra
   DefaultDirName={autopf}\Tephra
   DefaultGroupName=Tephra
   DisableProgramGroupPage=yes
   UninstallDisplayIcon={app}\tephra.exe
   UninstallDisplayName=Tephra
   OutputDir={#OutputDir}
   OutputBaseFilename=tephra-{#AppVersion}-windows-x64-setup
   SetupIconFile=..\app\windows\runner\resources\app_icon.ico
   LicenseFile=..\docs\legal\EULA.txt
   Compression=lzma2/ultra64
   SolidCompression=yes
   WizardStyle=modern
   ArchitecturesAllowed=x64compatible
   ArchitecturesInstallIn64BitMode=x64compatible
   MinVersion=10.0.17763
   ; Per-user by default (no UAC, silent updates just work); the user can choose "all users" in the dialog.
   PrivilegesRequired=lowest
   PrivilegesRequiredOverridesAllowed=dialog
   UsePreviousPrivileges=yes
   ; Close a running Tephra instead of failing on locked files; the updater relaunches via [Run].
   CloseApplications=yes
   RestartApplications=no
   CloseApplicationsFilter=tephra.exe
   #ifdef SignTool
   SignTool=tephrasign $f
   SignedUninstaller=yes
   #endif

   [Languages]
   Name: "english"; MessagesFile: "compiler:Default.isl"

   [Tasks]
   Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

   [Files]
   Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

   [Icons]
   Name: "{group}\Tephra"; Filename: "{app}\tephra.exe"
   Name: "{group}\{cm:UninstallProgram,Tephra}"; Filename: "{uninstallexe}"
   Name: "{autodesktop}\Tephra"; Filename: "{app}\tephra.exe"; Tasks: desktopicon

   [Run]
   ; No skipifsilent: after a silent in-app update the app comes back by itself.
   Filename: "{app}\tephra.exe"; Description: "{cm:LaunchProgram,Tephra}"; Flags: nowait postinstall

   [UninstallDelete]
   ; Only the program files. The uninstaller NEVER touches vaults or %APPDATA%/%LOCALAPPDATA% app data.
   Type: filesandordirs; Name: "{app}"
   ```
   Notes: `{autopf}` = `%LOCALAPPDATA%\Programs` for a per-user install and `C:\Program Files` for "all users", so the default folder is `…\Programs\Tephra`. The doubled `{{` in `AppId` is Inno's escape for a literal `{`. Keep `AppId` exactly as written (it is a freshly generated GUID for this project).
   Optional `tephrasign` sign tool is defined on the command line only when signing (09.12): `iscc /Stephrasign="signtool.exe sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f ..\secrets\codesign.pfx /p $ENV_PASSWORD $f"` (the release tool builds this string from the environment, see 09.12).
5. **Build the installer** (done by `tool/release.dart` in 09.13; do it by hand once now to test):
   ```
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DAppVersion=0.9.0 /DAppVersion4=0.9.0.1 /DSourceDir="$PWD\dist\stage\windows" /DOutputDir="$PWD\dist" installer\tephra.iss
   ```
   Output `dist\tephra-0.9.0-windows-x64-setup.exe` (≈ 25–40 MB).
6. **Manual installer tests** (record in `docs/release/smoke-test.md`): (a) fresh install per-user: installs into `%LOCALAPPDATA%\Programs\Tephra`, Start menu entry **Tephra** exists, desktop shortcut only if the box was ticked, app launches from the finish page, an entry appears in Settings → Apps; (b) install again over it (same version) and over it with a higher `/DAppVersion`: upgrade in place, settings/vaults untouched, no second "Tephra" in Apps; (c) silent upgrade as the updater will do it: `.\tephra-<ver>-windows-x64-setup.exe /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS` while Tephra is running → app closes, upgrade completes, app relaunches; exit code 0 (`$LASTEXITCODE`); (d) uninstall from Apps: program folder removed, `%APPDATA%` data and the vault folders **remain**; (e) "all users" install via the dialog (needs UAC) installs into `C:\Program Files\Tephra`; (f) a path with spaces and a non-ASCII user name works (use a test local user if the human agrees; otherwise note "not tested").

**Tests.** `tool/test/windows_stage_test.dart`: the staging function against a fake Release folder and a fake redist folder (temp dirs) copies the three DLLs, picks the newest version folder, fails with a clear message if the redist folder is missing, never writes into the source folder.

**Verify.** Installer builds; manual tests (a)–(e) pass; `docs/release/windows-deps.md` exists.

**Pitfalls.** `iscc` fails on a missing `LicenseFile` — generate `EULA.txt` first (placeholder now, real in 09.18). Do not set `PrivilegesRequired=admin` (it breaks silent updates). Do not bundle `msvcp140.dll` from `System32`. Inno path separators in `.iss` are backslashes.

---

### 09.12 — Portable zip and optional Authenticode signing

**Purpose.** A no-installer zip for people who cannot or will not install; optional signing against SmartScreen.

**Files.** `tool/release/zip_portable.dart`, `tool/release/sign_windows.dart`, `installer/PORTABLE_README.txt`, tests `tool/test/zip_portable_test.dart`.

**Implementation.**
1. **Portable zip** = the staged folder (same files as the installer, runtime DLLs included) zipped under a top-level folder `Tephra/` plus `PORTABLE_README.txt` ("Unzip anywhere and run tephra.exe. Your notes stay where they are. Tephra's settings are kept in your user profile, like the installed version. To remove it, delete this folder. Updates: download the new zip from <download page>."). Name `tephra-<version>-windows-x64-portable.zip`.
   Use `package:archive` (`ZipFileEncoder` or `Archive` + `ZipEncoder`), forward-slash entry names, deflate, preserve nothing else. **Do not use `Compress-Archive`** (PowerShell 5.1 writes backslashes in entry names; some unzip tools then create files with literal backslashes).
   Decision: **no separate portable data mode in v1** (settings/index/sync DB stay in `%APPDATA%`/`%LOCALAPPDATA%` like the installed version); a true "data next to the exe" mode goes to `PROGRESS.md` → Ideas.
2. **Installed vs portable detection** (used by the updater, 09.16): `File('<dir of Platform.resolvedExecutable>\unins000.exe').existsSync()` → installed (Inno writes `unins000.exe` there); otherwise portable.
3. **Optional signing** (`sign_windows.dart`, runs only with `--sign` and only if `secrets/codesign.pfx` exists and `TEPHRA_CODESIGN_PASSWORD` is set; otherwise prints "Skipping code signing (no certificate)" and continues):
   - Find `signtool.exe` under `C:\Program Files (x86)\Windows Kits\10\bin\<newest>\x64\signtool.exe` (installed with the Windows SDK, which the machine has).
   - Sign `tephra.exe` and every first-party DLL in the staging folder **before** zipping/installing: `signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f secrets\codesign.pfx /p <password from env> <file>` (timestamp is essential: the signature stays valid after the certificate expires). The password is passed through the process arguments only for the duration of the call and never printed (print the command with `/p ****`).
   - Sign the installer through Inno's `SignTool` (09.11 item 4): `iscc /Stephrasign="signtool.exe sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f ..\secrets\codesign.pfx /p %TEPHRA_CODESIGN_PASSWORD% $f" /DSignTool=1 …` (Inno expands `$f`; the env var is expanded by the shell, so build the string in code and run `iscc` with `Process.run` using `environment:` rather than putting the password in the command line).
   - Verify: `signtool verify /pa /v <file>` must say "Successfully verified"; record.
4. Without a certificate: document in `docs/release/distribution.md` and on the download page (09.17) how to get past SmartScreen ("More info" → "Run anyway") and that the SHA-256 on the page lets users verify the file.

**Tests.** `zip_portable_test.dart`: zip a fake folder → entries use `/`, have the `Tephra/` prefix, include `PORTABLE_README.txt`, round-trip contents equal; empty folders skipped; refuses to overwrite an existing zip unless `--force`.
`sign_windows` has a dry-run mode (`--dry-run` prints commands with `/p ****`) tested for argument construction and password masking.

**Verify.** Unzip the portable zip into `C:\Temp\TephraPortable` and run `tephra.exe` — starts, opens a vault. Delete the folder afterwards.

**Pitfalls.** Never write the certificate password to disk or logs. Never sign before staging (signing the `build/` output would change files CI compares).

---

### 09.13 — The release tool `tool/release.dart`: build, verify, checksum, manifest

**Purpose.** One command builds everything the same way every time and refuses to produce a bad release.

**Files.** `tool/release.dart` (CLI entry), `tool/release/config.dart`, `tool/release/preflight.dart`, `tool/release/android_build.dart`, `tool/release/windows_build.dart` (uses 09.11/09.12 pieces), `tool/release/checksums.dart`, `tool/release/manifest_writer.dart`, `tool/release/update_key.dart`, `tool/release/notes.dart`, tests `tool/test/release_*_test.dart`, `docs/release/release-checklist.md`, `docs/release/distribution.md`.

**Implementation.**
1. CLI: `dart run tool/release.dart <command> [flags]` with commands `keygen-update-key`, `build` (flags `--android`, `--windows`, `--all` (default), `--rc <n>`, `--skip-checks` (refused unless `--rc`), `--allow-dirty` (only with `--rc`), `--sign`, `--hosting github|static`, `--base-url <url>`), `manifest` (re-create manifest from an existing `dist/<version>/`), `verify <dir>` (re-check an output folder). Use `package:args` (BSD-3; already in the workspace if `tool/` uses it; otherwise parse manually). Output folder: `dist/<version>/` (`dist/` is git-ignored).
2. **Preflight** (abort on any failure): pubspec version parses (09.1) and equals the top section of `CHANGELOG.md` (except rc); `git status --porcelain` empty; branch is `main`/`phase-09`; the tag `v<version>` does not exist yet (final) ; `secrets/google_oauth.json`, `secrets/sentry.json`, `secrets/release.json`, `app/android/key.properties`, `secrets/tephra-upload.jks`, `secrets/update_signing_key.json` exist; `iscc.exe` and `apksigner.bat` found; `flutter doctor` has no "[✗]"; no `*REPLACE*` in secrets values; the update **public key** constant equals the public key derived from `secrets/update_signing_key.json`.
3. **Checks** (skipped only with `--skip-checks`): format, `flutter analyze --fatal-infos`, `dart test` in every package, `flutter test --exclude-tags golden`, `dart test tool/test`, `dart run tool/check_licenses.dart`, hygiene tests (09.6), the guide-vault test (09.19). Fail fast with the first failing command's output.
4. **Android** (from `app/`): build split APKs then the universal APK with the flags of 09.5, each with `--dart-define-from-file=../secrets/google_oauth.json --dart-define-from-file=../secrets/sentry.json --dart-define-from-file=../secrets/release.json`. Copy to `dist/<version>/` as `tephra-<version>-android-<abi>.apk` / `-universal.apk`. For every APK run (a) `apksigner verify --print-certs` → v2 (and v3) true and certificate SHA-256 equals `docs/release/signing-cert.md` (**fail otherwise**: a debug-signed or wrongly signed APK must never leave the PC); (b) `aapt2 dump badging <apk>` → `package: name='com.tephra.app'`, `versionName` equals the version, `versionCode % 1000` equals the build, `sdkVersion:'26'`, no `debuggable`; (c) size ≤ 40 MiB per ABI APK (warn above 36 MiB; fail above 40 MiB unless `PROGRESS.md` contains the human's approval line `SIZE-APPROVED <version>`); (d) `aapt2 dump permissions` equals the approved list in `docs/release/permissions.md` (parsed from a fenced block in that file: the tool fails on any extra permission).
   Archive symbols: zip `app/build/symbols/android` → `dist/<version>/tephra-<version>-symbols-android.zip` (private! not published in the download page).
5. **Windows**: build (09.11 item 2), stage + runtime DLLs, optional sign, installer via `iscc`, portable zip, `tephra-<version>-symbols-windows.zip`. Verify the installer file exists and is > 10 MB; run `iscc` with `/Q`.
6. `SHA256SUMS.txt` in `dist/<version>/` (format `<hex>  <file>`, two spaces, sorted, LF endings) for every published file (APKs, installer, portable zip; symbols zips are listed in a separate private file `SHA256SUMS-private.txt`).
7. **`release-notes.md`** = the matching section of `CHANGELOG.md`.
8. **Update manifest** (`manifest_writer.dart`) — exact schema (`schema: 1`), file `dist/<version>/update/manifest.json` (UTF-8, `\n` endings, 2-space indent, keys in this order):
   ```json
   {
     "schema": 1,
     "channel": "stable",
     "version": "1.0.0",
     "build": 7,
     "releasedAt": "2026-12-01T09:00:00Z",
     "issuedAt": "2026-12-01T09:05:00Z",
     "notes": { "en": "- Added … (markdown, from CHANGELOG, ≤ 4,000 characters)" },
     "platforms": {
       "android": {
         "arm64-v8a":   { "url": "https://…/tephra-1.0.0-android-arm64-v8a.apk",   "sha256": "<hex>", "size": 31457280 },
         "armeabi-v7a": { "url": "…", "sha256": "…", "size": 0 },
         "x86_64":      { "url": "…", "sha256": "…", "size": 0 },
         "universal":   { "url": "…", "sha256": "…", "size": 0 }
       },
       "windows": {
         "x64": { "url": "https://…/tephra-1.0.0-windows-x64-setup.exe", "sha256": "<hex>", "size": 0,
                  "portableUrl": "https://…/tephra-1.0.0-windows-x64-portable.zip" }
       }
     }
   }
   ```
   `build` is the pubspec build number (1–999). Hex is lower-case. `url`s come from `--hosting`/`--base-url` (09.17). The **signature** file `manifest.json.sig` = standard base64 (with padding) of the 64-byte **Ed25519 signature over the exact bytes of `manifest.json`**, plus a trailing newline. Sign with `package:cryptography` `Ed25519().sign(bytes, keyPair: …)` from the seed in `secrets/update_signing_key.json`. After writing, **verify** the signature with the public key constant (round trip) and re-parse the manifest with the same parser the app uses (import it from the app via a small shared pure-Dart file `app/lib/core/updater/update_manifest.dart` — it must not import Flutter so the tool can use it; if that is awkward, duplicate the 60-line parser in `tool/release/` **and** add a test that both accept/reject the same fixtures).
9. `keygen-update-key`: generates an Ed25519 key pair (`Ed25519().newKeyPair()`), writes `secrets/update_signing_key.json` `{ "seedBase64": "<32 bytes>", "publicKeyBase64": "<32 bytes>" }`, writes/updates `app/lib/core/updater/update_public_key.dart` (`const updatePublicKeysBase64 = <String>['<public key>'];` — a **list**, so a future rotation can ship an app that trusts two keys), refuses to overwrite an existing key unless `--rotate` (which **appends** the new public key to the list and asks the human to confirm in the console). Prints: "Back up secrets/update_signing_key.json in two places. If it is lost, no installed app can ever auto-update again; users must reinstall manually."
10. `docs/release/release-checklist.md`: the ordered human+Gemini checklist for each release (bump version + build; finalise CHANGELOG; `dart run tool/release.dart build --all`; smoke test on both platforms with the produced files; install the previous release and test in-app update to this one on both platforms; publish per 09.17; tag; archive symbols; update the privacy/guide pages if behaviour changed).

**Tests.** `tool/test/release_*_test.dart`: preflight with a fake file tree (each missing item gives its own error); checksum file format; manifest writer produces the exact key order and schema and the signature verifies; a one-byte change to the manifest fails verification; `aapt2`/`apksigner` output parsers on captured sample outputs (store samples in `tool/test/fixtures/`); size policy (36/40 MiB boundaries, approval line); permissions parser (extra permission → failure); `--skip-checks` refused without `--rc`.

**Verify.** `dart test tool/test`; then a dry run `dart run tool/release.dart build --all --rc 1 --allow-dirty --skip-checks` produces `dist/0.9.0/…` with all files; open each APK's signature and badging by hand once.

**Pitfalls.** The manifest must be written **last** and published **last** (09.17). The tool never uploads anything. Never put `build/symbols` in `dist/<version>/` publish folder. Re-running for the same version must overwrite `dist/<version>/` only after the human's `--force`.

---

### 09.14 — Updater core: manifest, signature, version policy, download

**Purpose.** Pure, heavily tested logic for "is there a newer build, is it authentic, fetch it safely". Needs the manifest URL from **H4**.

**Files.** `app/lib/core/updater/update_manifest.dart` (pure Dart), `update_public_key.dart` (generated in 09.13), `manifest_verifier.dart`, `update_policy.dart`, `update_service.dart`, `update_downloader.dart`, `update_state.dart`, `providers.dart`, `app/lib/core/settings/` additions (`updateCheckAuto: bool = true`, `lastUpdateCheckSuccessAt`, `lastUpdateCheckAttemptAt`, `skippedUpdateVersion`, `lastSeenManifestIssuedAt`), tests `app/test/core/updater/*_test.dart`.

**Implementation.**
1. `UpdateManifest.fromJson` (hand-written, immutable, strict): requires `schema == 1` (greater → `UpdateManifestUnsupported`, shown as "Your version of Tephra is too old to check for updates; download the latest from <site>"), `channel == 'stable'`, semver `version`, `build` integer 1–999, ISO-8601 `releasedAt`/`issuedAt`, `notes.en` string ≤ 4,000 chars, platform entries with `url` (https only), `sha256` (64 lower-case hex), `size` (> 0, ≤ 500 MiB). Unknown fields ignored. Any violation → `UpdateManifestInvalid`.
2. `ManifestVerifier.verify(Uint8List manifestBytes, String sigBase64, List<String> publicKeysBase64)` → true if **any** key verifies the Ed25519 signature (`Ed25519().verify(bytes, signature: Signature(sigBytes, publicKey: SimplePublicKey(keyBytes, type: KeyPairType.ed25519)))`). Verify **before** parsing JSON. Wrong length/invalid base64 → false.
3. `UpdatePolicy` (pure):
   - `shouldAutoCheck({now, lastSuccessAt, lastAttemptAt, enabled, configured})` → `enabled && configured && (lastSuccessAt == null || now − lastSuccessAt ≥ 24 h) && (lastAttemptAt == null || now − lastAttemptAt ≥ 1 h)`. Called **only at app start**, 10 s after the first frame (never on resume, never while a vault is still opening).
   - `isNewer(installed, manifest)`: compare `(major, minor, patch)` then `build` using the `sanitizeAndroidBuild` rule (09.1). Equal or lower → not newer. **Downgrades are never offered.**
   - `selectAndroidAsset(manifest, List<String> supportedAbis)`: first ABI in the device's priority list (`Build.SUPPORTED_ABIS` order) that exists in the manifest; never `universal` for automatic updates; none → `NoCompatibleAsset`.
   - `selectWindowsAsset(manifest)`: `windows.x64`.
   - Replay protection: reject a manifest whose `issuedAt` is older than `lastSeenManifestIssuedAt` (store the newest accepted `issuedAt`).
4. `UpdateService.check({required bool manual})`: if the URL (`String.fromEnvironment('TEPHRA_UPDATE_MANIFEST_URL')`) is empty → `UpdateState.notConfigured`. GET manifest (`http`, timeout 15 s, `User-Agent: Tephra/<version>`, **no cookies, no other headers, no identifiers**; max body 256 KiB via streaming limit) then GET `<manifest url>.sig` (hard-coded suffix `.sig`, max 1 KiB) → verify → parse → policy. Results: `UpToDate`, `UpdateAvailable(manifest, asset)`, `Failed(kind)` where auto checks swallow `Failed` silently (log at `info`) and manual checks show it. Persist `lastAttemptAt` before the request and `lastSuccessAt` after a verified manifest.
5. `UpdateDownloader.download(asset, {onProgress, cancel})`: HTTPS only (`asset.url` must be `https`; redirects up to 5, each also `https`); target dir: Android `<cacheDir>/updates/` (the directory the FileProvider exposes, 09.15), Windows `%TEMP%\tephra-update\`; file name = last URL segment sanitised to `[A-Za-z0-9._-]`, written as `<name>.part`; stream with progress; **check free space** ≥ `size × 1.2` when the API is available (skip the check if not); compute SHA-256 incrementally (`sha256.startChunkedConversion` from `package:crypto`); at the end require byte count == `size` and hash == `asset.sha256`, else **delete the file** and throw `UpdateIntegrityException` (UI: "The download was damaged. Try again."); rename `.part` → final; return the file. On cancel/app exit delete the `.part`. `purgeOldUpdates()` at app start deletes everything in the update dir older than 1 day except the file currently being installed.
6. `UpdateState` (sealed): `UpdateIdle`, `UpdateChecking`, `UpdateUpToDate(checkedAt)`, `UpdateAvailable(manifest, asset, notes)`, `UpdateDownloading(progress)`, `UpdateReady(file)`, `UpdateFailed(kind)`, `UpdateNotConfigured`. Riverpod `updateControllerProvider` (Notifier) exposes it and `checkNow()`, `startDownload()`, `skipThisVersion()`.
7. Privacy: the **only** data sent are the HTTPS request itself (IP address, `User-Agent: Tephra/1.0.0`); say exactly this in the privacy policy (09.18) and in Settings → Privacy (09.3 item 3).
8. Setting `updateCheckAuto` (default **on**) in Settings → About ("Check for updates automatically").

**Tests.** Manifest: valid fixture; each violation (http url, bad hash length, build 0/1000, schema 2, missing platform) → typed error. Verifier: signature made with a test key pair verifies; flipped byte in manifest fails; wrong key fails; two keys (rotation) either verifies. Policy: 24 h/1 h boundaries with a fake clock; version tuples (`1.0.0+7` vs `1.0.0+8`, `1.0.1+1` vs `1.0.0+9`, `0.9.0+5` vs installed `1.0.0+1` = no); Android build `4007` sanitised to 7 compares equal to manifest build 7; ABI selection with `['arm64-v8a','armeabi-v7a']`, with only `x86_64`, none; replay (older `issuedAt`) rejected. Service with a fake `http.Client` (local `HttpServer` in the test): oversize manifest rejected; missing `.sig` → `Failed(signature)`; auto check swallows errors; not-configured. Downloader against a local `HttpServer`: success; wrong SHA → file deleted + exception; wrong size; `http://` URL refused; redirect to `http://` refused; cancel deletes `.part`.

**Verify.** `flutter test test/core/updater`.

**Pitfalls.** Never act on a manifest that failed signature verification, even to show "update available". Never use the manifest's `sha256` before verifying the signature. Do not add analytics. The manifest URL is compiled in; do not read it from user-editable settings.

---

### 09.15 — Android in-app install: platform channel, FileProvider, permission

**Purpose.** Hand the verified APK to the system installer. **Decision (final):** a small own Kotlin channel (about 60 lines), not `open_filex` — its current README states it removed `REQUEST_INSTALL_PACKAGES`, and we need exact control over the file location and the exported surface.

**Files.** `app/android/app/src/main/kotlin/com/tephra/app/InstallerChannel.kt`, `UpdateFileProvider.kt`, `MainActivity.kt` (edit), `app/android/app/src/main/res/xml/update_file_paths.xml`, `app/android/app/src/main/AndroidManifest.xml` (edit), `app/lib/core/updater/installer/apk_installer.dart` (interface + method-channel implementation), `apk_installer_fake.dart` (tests), tests `app/test/core/updater/apk_installer_test.dart`.

**Implementation.**
1. Manifest additions: `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />` and inside `<application>`:
   ```xml
   <provider
       android:name=".UpdateFileProvider"
       android:authorities="${applicationId}.updatefiles"
       android:exported="false"
       android:grantUriPermissions="true">
       <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/update_file_paths" />
   </provider>
   ```
   A **subclass** (`class UpdateFileProvider : androidx.core.content.FileProvider()`) is required because two `<provider>` entries with the same `android:name="androidx.core.content.FileProvider"` (ours and a plugin's, e.g. a share or file picker plugin) fail the manifest merger. Check the merged manifest after the change (`processReleaseManifest`).
2. `res/xml/update_file_paths.xml`: `<paths><cache-path name="updates" path="updates/" /></paths>` (maps to `<cacheDir>/updates/`).
3. `InstallerChannel.kt` (channel name `com.tephra.app/installer`), registered in `MainActivity.configureFlutterEngine`:
   ```kotlin
   class InstallerChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
     override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
       when (call.method) {
         "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
         "canRequestPackageInstalls" -> result.success(activity.packageManager.canRequestPackageInstalls())
         "openInstallSettings" -> {
           activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
           result.success(null)
         }
         "installApk" -> {
           val path = call.argument<String>("path") ?: return result.error("arg", "path missing", null)
           val dir = File(activity.cacheDir, "updates").canonicalFile
           val file = File(path).canonicalFile
           if (!file.path.startsWith(dir.path + File.separator) || !file.name.endsWith(".apk") || !file.isFile) {
             return result.error("path", "APK must be inside the updates folder", null)
           }
           val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updatefiles", file)
           val intent = Intent(Intent.ACTION_VIEW)
             .setDataAndType(uri, "application/vnd.android.package-archive")
             .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
           activity.startActivity(intent)
           result.success(true)
         }
         else -> result.notImplemented()
       }
     }
   }
   ```
   (`canRequestPackageInstalls()` exists from API 26 = our minSdk.) The canonical-path check is the security boundary: the channel cannot be used to install an arbitrary file.
4. Dart `ApkInstaller` interface: `Future<List<String>> supportedAbis()`, `Future<bool> canInstall()`, `Future<void> openInstallSettings()`, `Future<void> install(File apk)`. Implementation `MethodChannelApkInstaller`; `UnsupportedApkInstaller` for other platforms; `FakeApkInstaller` for tests. The `updateController` flow on Android: `UpdateReady(file)` → `canInstall()`; false → dialog "To install updates, allow Tephra to install apps" with button "Open settings" (`openInstallSettings()`), and when the app resumes call `canInstall()` again and continue; true → `install(file)`. The system then shows its own confirmation; after the user confirms, Android replaces the app and **kills the running process** (the user reopens it; mention this in the dialog text "Tephra will close while it updates").
5. Update cache dir: Dart side gets it with `path_provider` `getTemporaryDirectory()` (= `cacheDir` on Android) + `updates`; assert equality with the Kotlin path in a unit test on the string `updates`.
6. **Manual test on the phone** (use two builds with different versions, e.g. `0.9.0+1` then `0.9.0+2`, both signed with the release key): install build 1 by `adb install`; host `manifest.json` + `.sig` + APK on a local test server (`dart run tool/release.dart` output served by `python`-free means: use `dart run tool/serve_dist.dart <dir> --port 8095`, a 30-line `HttpServer` file server in `tool/`; make the build 1 accept `http://` for **this test only** by building it with `--dart-define=TEPHRA_UPDATE_ALLOW_HTTP=true`, which the downloader honours **only when `kDebugMode || const bool.fromEnvironment('TEPHRA_UPDATE_ALLOW_HTTP')`** — default false; and reach the PC from the phone with `adb reverse tcp:8095 tcp:8095`, URL `http://127.0.0.1:8095/...`). Verify: check finds build 2; download progress; unknown-sources prompt; install; app restarts at build 2; data and vault intact; the stale APK is purged on next start. Then tamper with one byte of the served APK → "download damaged", file deleted. Then serve a manifest with a bad signature → "could not verify update".
7. Behaviour on Android versions: on Android 14+ the installer may show Play Protect "App scan recommended" for sideloaded updates; document in the FAQ. The system never allows silent install without privileges; that is expected.

**Tests.** Dart tests with the fake installer: state machine (can't install → settings → resumed → installs); `install` refused for a file outside the updates dir (Dart-side guard too). Kotlin side has no unit tests (no test infrastructure in the project); the manual test above is the check — record it.

**Verify.** Manual test passes on the 4 GB phone; merged manifest contains exactly one `updatefiles` provider with `exported="false"`; `aapt2 dump permissions` lists `REQUEST_INSTALL_PACKAGES`.

**Pitfalls.** Do **not** make the provider `exported="true"`. Do not request `REQUEST_INSTALL_PACKAGES` in a Play Store build (Phase 11 removes it via a flavor). Do not try `PackageInstaller` sessions in v1 (needs more UI; ACTION_VIEW is sufficient).

---

### 09.16 — Windows in-app install, About page "Check for updates", update UI

**Purpose.** Same flow on Windows; shared, polite UI on both.

**Files.** `app/lib/core/updater/installer/windows_installer.dart`, `app/lib/core/updater/installer/installer_provider.dart`, `app/lib/settings/about/update_section.dart`, `app/lib/settings/about/update_dialog.dart`, `app/lib/core/updater/update_badge.dart`, l10n keys (`update*`), tests `app/test/core/updater/windows_installer_test.dart`, `app/test/settings/about/update_section_test.dart`.

**Implementation.**
1. `WindowsUpdateInstaller`:
   - `bool get isInstalledBuild` → `unins000.exe` next to `Platform.resolvedExecutable` (09.12 item 2). Portable build: the update dialog offers only "Open download page" (`url_launcher` with `asset.portableUrl`); no download, no execution.
   - `Future<void> installAndExit(File setup)`: precondition — the user confirmed in a dialog "Install version X now? Tephra will close, update and open again." (buttons "Install and restart" / "Later"). Then: (1) flush every editor and stop the sync worker through the existing shutdown path (find the Phase 3 `Shutdown` handling and the editor save-all command; await up to 5 s); (2) `Process.start(setup.path, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'], mode: ProcessStartMode.detached)`; (3) `exit(0)` (use the app's `WindowService.quit` if it exists so the tray icon is removed). The installer waits for Tephra to end, replaces files, and relaunches through the `[Run]` entry (09.11 item 4).
   - Before launching, re-verify the file's SHA-256 against the manifest (a second check right before execution; the file could have been replaced on disk). Mismatch → delete + error.
   - The updater passes **no other arguments** and never uses a shell (`runInShell: false`).
   - If the install dir needs elevation (previous install was "all users"), Windows shows the UAC prompt; the app has already exited — if the user declines, the app is simply closed. Mention in the dialog only when `Platform.resolvedExecutable` starts with `%ProgramFiles%`: "Windows may ask for permission."
2. `UpdateSection` (in About): row states per `UpdateState` — "Up to date (checked <time>)" + "Check for updates"; "Checking…"; "Version 1.0.1 is available" + "What's new" (notes as plain text via the reading renderer if reusable, else `SelectableText`) + "Download and install" (Android: download then prompt; Windows installed: download then confirm dialog) + "Skip this version" (hidden for portable); progress bar with bytes; errors as plain language (`updateErrorNetwork`, `updateErrorSignature` "Could not verify the update. It was not installed.", `updateErrorDownload`, `updateErrorNoAsset` "No update file for this phone's processor."); "Not configured" row when the URL is empty (debug builds).
3. **Automatic check:** in `app.dart` after the first frame + 10 s, if `UpdatePolicy.shouldAutoCheck(...)` → `check(manual: false)`; result `UpdateAvailable` (not skipped) → a **non-modal** snackbar/banner "Tephra 1.0.1 is available" with "View" (opens About) — shown at most once per version per day; plus a dot badge on the Settings entry (`UpdateBadge`). Never a blocking dialog, never during typing (do not show while the editor has focus; queue until idle or next start).
4. Command registry (conventions §7.8): `app.check-for-updates` (palette, label l10n `commandCheckForUpdates`), `app.open-about`.
5. Windows-only start-up cleanup: delete `%TEMP%\tephra-update\*` older than 1 day. Android: `purgeOldUpdates()` (09.14).
6. After an update the first launch shows a one-time "Updated to 1.0.1 — see what's new" snackbar (compare stored `lastRunVersion` with the current one; show the **local** CHANGELOG excerpt bundled as an asset `app/assets/changelog_latest.md` produced by `tool/release.dart`, no network).

**Tests.** Installer launcher with an injected `ProcessLauncher` fake: exact argument list and `detached` mode; refuses a file whose hash changed; portable build never launches; confirmation required; flush-before-launch order. Widget tests for every `UpdateState` at phone and desktop widths; the auto-check snackbar frequency rule with a fake clock; command registration.

**Verify.** Manual on Windows: install build `0.9.0+1` with the real installer (per-user); serve a test manifest + installer of build 2 from `tool/serve_dist.dart` (HTTP allowed only for the test, as in 09.15); check for updates → available → install → app closes → installer runs silently → app reopens at build 2 within ~15 s; vaults, settings, open tabs restored; run it once more starting from the **portable** build (expect only the download-page option); tamper test (one byte changed) → refused.

**Pitfalls.** Never run the installer from inside the app directory (it would be locked). Do not call `exit(0)` before the sync worker and editors are flushed. Do not auto-install without the user's click.

---

### 09.17 — Distribution: download page, checksums, releases-only repository or static site

**Purpose.** A page where people get the files, and a stable URL for the manifest. Needs **H4**. Gemini prepares **both** options; the human chooses; the unchosen one is kept working in `tool/make_site.dart` but not published.

**Files.** `tool/make_site.dart`, `tool/site/templates/` (HTML templates as plain Dart string builders or `.html` files with `{{placeholders}}`), `tool/site/site.css`, `docs/release/distribution.md`, tests `tool/test/make_site_test.dart`.

**Implementation.**
1. `dart run tool/make_site.dart --release dist/<version> --hosting github|static --base-url <url> --out dist/site` generates a static site: `index.html` (download page), `privacy.html`, `eula.html`, `changelog.html`, `faq.html` (from `docs/legal/*.md`, `CHANGELOG.md`, `docs/user/FAQ.md` using `package:markdown`), `update/manifest.json` + `update/manifest.json.sig` (copied unchanged from the release folder), `site.css` (one small stylesheet, system fonts, light/dark with `prefers-color-scheme`), `robots.txt` (allow all). **No JavaScript frameworks, no analytics, no external fonts/CDNs, no cookies.** One tiny inline script is allowed: highlight the recommended download by `navigator.userAgent` (Windows → installer, Android → arm64 APK); the page works without it.
2. **Download page content:** product name + one-line description; version, release date, "What's new" (CHANGELOG section); for each file a button, size and **SHA-256** (copyable) — Windows installer (recommended), Windows portable zip, Android "arm64-v8a (most phones from 2017 on)", "armeabi-v7a (older 32-bit phones)", "x86_64 (emulators/Chromebooks)", "Universal (if unsure; larger)". **How to verify:** Windows `Get-FileHash .\tephra-1.0.0-windows-x64-setup.exe -Algorithm SHA256`; Android: verify on the PC before copying, or trust Android's signature check on install. **Install guides:** Windows (SmartScreen "More info → Run anyway" if unsigned; per-user install; where files go; how to uninstall); Android (download in the browser, tap the file, allow "Install unknown apps" for the browser once, Play Protect notice, grant "All files access" on first vault open and why). System requirements (Windows 10 1809+ x64; Android 8.0+). Links: privacy policy, EULA, changelog, FAQ, support email. A "Google sign-in shows 'unverified app'" note if H6 verification is not finished.
3. **Option A — GitHub releases-only repo** (`--hosting github --base-url https://github.com/<owner>/tephra-releases`):
   - Asset URLs in the manifest: `https://github.com/<owner>/tephra-releases/releases/download/v<version>/<file>`.
   - Site files go to the repo's `/docs` folder (Pages source `main:/docs`); the manifest URL = `https://<owner>.github.io/tephra-releases/update/manifest.json`.
   - Publish with the GitHub CLI **from `D:\script\tephra-gemini` but operating on a separate clone** `D:\script\tephra-releases` (`gh repo clone <owner>/tephra-releases`): (1) `gh release create v<version> dist/<version>/*.apk dist/<version>/*.exe dist/<version>/*.zip dist/<version>/SHA256SUMS.txt --repo <owner>/tephra-releases --title "Tephra <version>" --notes-file dist/<version>/release-notes.md --draft` (exclude `*symbols*`); (2) **re-download** two assets with `Invoke-WebRequest` and compare SHA-256 with `SHA256SUMS.txt`; (3) publish the draft (`gh release edit v<version> --draft=false`); (4) copy `dist/site/*` into the clone's `docs/`, commit, push (**manifest last**); (5) fetch the public manifest URL and verify the signature with `dart run tool/release.dart verify --manifest-url <url>`.
   - The source repository stays private; the releases repo contains only `README.md`, `docs/`, and GitHub release assets.
4. **Option B — static site** (`--hosting static --base-url https://tephra.example`): asset URLs `https://tephra.example/downloads/<version>/<file>`; Gemini writes `dist/site/` including `downloads/<version>/` with the binaries and `SHA256SUMS.txt`; the human uploads the folder with their host's tool (SFTP/`rsync`/Cloudflare Pages drag-and-drop/`netlify deploy`). The **manifest file is uploaded last**. Cache headers advice for `update/manifest.json`: `Cache-Control: no-cache` (Pages/Netlify honour a `_headers` file: emit `dist/site/_headers` with `/update/*` `Cache-Control: no-cache, max-age=0`).
5. **Order of publication (both options):** binaries → verify downloads match checksums → page → **manifest last**. Rollback = replace the manifest with the previous release's signed manifest (keep every old `manifest.json` + `.sig` in `docs/release/manifests/<version>/` locally, committed; they contain no secrets). Never delete old binaries (users may still be downloading them).
6. `docs/release/distribution.md` records the chosen option, the manifest URL, the repo/site, and the exact commands used; the URLs are then entered into `secrets/release.json` (`TEPHRA_UPDATE_MANIFEST_URL`, `TEPHRA_PRIVACY_URL`, `TEPHRA_EULA_URL`, `TEPHRA_DOWNLOAD_URL`) **before** the release build of 09.20 (installed apps hard-code them; **the manifest URL can never change after v1.0 ships** without a new app release that also ships under the old URL).
7. Google OAuth branding (H6 step 2) uses the published privacy-policy URL.

**Tests.** `make_site_test.dart`: generated `index.html` contains every file name, size and checksum from a fixture release folder; links are relative or absolute per hosting mode; both hosting modes produce correct asset URLs and an identical manifest **except** URLs (the manifest is generated by `release.dart`, so test that `make_site` copies it byte-for-byte and verifies the signature before copying; a tampered manifest aborts); no `<script src=`/`https://cdn` in output; HTML is well-formed (parse with `package:html`? not allowed to add; check balanced tags with a simple tag-stack test helper).

**Verify.** Open `dist/site/index.html` in a browser (file://) and click through; run the (dry-run) publish commands against a **scratch** test repo if the human prefers (`--dry-run` prints the `gh` commands instead of running them).

**Pitfalls.** GitHub release assets have a 2 GiB limit per file — fine. GitHub Pages serves `.sig` as `application/octet-stream`; fine. Never publish `SHA256SUMS-private.txt` or symbol zips.

---

### 09.18 — Legal templates: privacy policy and EULA (for human and lawyer review)

**Purpose.** Accurate, plain-language documents that match what the app really does, ready to be finalised.

**Files.** `docs/legal/PRIVACY_POLICY.md`, `docs/legal/EULA.md`, `docs/legal/EULA.txt` (generated by `tool/make_site.dart --legal-only` or a 20-line `tool/legal_txt.dart`: strips Markdown to plain text, wraps at 80 columns), `docs/legal/PLACEHOLDERS.md` (list of every `{{…}}` the human must fill), first-run link wiring (09.3), `tool/test/legal_test.dart`.

**Implementation.** Both documents begin with a visible banner: "**TEMPLATE — not legal advice. Replace every {{PLACEHOLDER}} and have it reviewed before publishing.**" which `release.dart` preflight **refuses to publish** while any `{{` remains in the final-release site input (the check is skipped for `--rc`).
1. Placeholders: `{{OWNER_NAME}}`, `{{CONTACT_EMAIL}}`, `{{POSTAL_ADDRESS}}` (optional), `{{JURISDICTION}}`, `{{EFFECTIVE_DATE}}`, `{{WEBSITE_URL}}`.
2. **Privacy policy** — sections (write each in plain English, short sentences): (1) Who we are and how to contact us. (2) **Summary**: Tephra is local-first; notes stay on your device; we run no servers in v1.0 and have no accounts; we cannot read your notes. (3) **Data on your device**: vault files, `.tephra/` folder, app settings, search index, sync state, crash logs, encrypted-notes keys in the system keystore — where stored, never sent unless you choose a feature below. (4) **Optional features that send data**, one subsection each, in the exact terms of what leaves the device (verify each against the code via the 09.6 network list): *Google Drive sync* (to your own Drive, using the `drive.file` scope; Tephra sees only files it created; with encryption on Google sees only encrypted data and hash names; the vault name is visible as a folder name; sign-in tokens stored in the system keystore; Google's own privacy policy applies); *AI features* (only when you invoke them; the text shown in the preview goes to Anthropic — and Voyage AI if you chose remote embeddings — using **your own API key**; we never see it; no data sent in the background); *Model downloads* (Hugging Face, no user data; your IP address is visible to them); *OCR* (on-device ML Kit; no image leaves the device — **verify against ML Kit's documentation and Phase 8 notes; write what is true**); *Voice transcription* (on-device); *Update check* (once a day at most when enabled: a request to `{{WEBSITE_URL}}` revealing your IP address and `Tephra/<version>` — nothing else; can be turned off); *Crash reports* (**opt-in**; what is and is not included — copy the `CrashReportFields` lists; processor: Sentry; retention 30 days; IP storage disabled). (5) **What we do not do**: no analytics/ads/tracking, no selling data, no reading notes. (6) **Children**. (7) **Retention and deletion** (on-device = you control; crash reports 30 days; deleting Drive data is done in your Google Drive; how to remove Tephra's access at https://myaccount.google.com/permissions). (8) **Your rights** (access/deletion requests by email; for crash reports provide the event id shown in Settings → Privacy → Last crash report if sent — the app shows the Sentry event id only when consent is on; implement: `CrashService.lastEventId` shown in the details page). (9) **Security** (encryption design in two sentences; no guarantee clause; password/recovery-key warning). (10) **International transfers** (Google, Anthropic, Sentry are US-based; the human fills jurisdiction specifics). (11) **Changes** (version + effective date; material changes announced in the app). (12) Contact. Phase 10 appends the Tephra Cloud section (10.22).
3. **EULA** — sections: licence grant (personal, non-exclusive, non-transferable, closed-source; no reverse engineering except as law allows; third-party components under their own licences, see in-app notices); ownership (your notes are yours; we claim no rights in your content; the software is ours); user responsibility for backups and for the recovery key (no recovery possible by anyone); disclaimer of warranty ("as is") and limitation of liability (human/lawyer to adapt to jurisdiction; explicitly flag the data-loss clause: "Tephra is designed not to lose data; keep your own backups"); third-party services (Google, Anthropic, Voyage, Sentry: separate terms; user's API keys and costs are the user's); updates (the app may check for and install updates only with your action); termination; governing law `{{JURISDICTION}}`; contact. Installer shows `EULA.txt` (Inno `LicenseFile`); the app's first-run welcome links to the online copy; the About page links both.
4. First-run acceptance wording (in the consent/welcome flow from 09.3, shown only on the very first launch): below the crash consent, a line `eulaAcceptanceLine` "By using Tephra you agree to the Terms and the Privacy Policy" with both as links. The human/lawyer decides whether a checkbox is needed (note in `PLACEHOLDERS.md`).
5. `docs/legal/PLACEHOLDERS.md` lists each placeholder and the files it appears in; `release.dart` preflight (09.13) parses it.

**Tests.** `legal_test.dart`: every `{{PLACEHOLDER}}` found in the two documents is listed in `PLACEHOLDERS.md` (and vice versa); `EULA.txt` is generated deterministically; the privacy policy mentions every host from the network list (`tool/test` reads the list from `docs/release/security-review.md`'s fenced `hosts` block and asserts each appears in the policy text).

**Verify.** Documents render on the site (09.17); installer shows the EULA.

**Pitfalls.** Do not copy another company's policy text. Do not claim anything the code does not do (e.g. "no data leaves your device" is false when Drive sync is on). If a statement cannot be verified, write it as a question for the human in `PLACEHOLDERS.md` instead of guessing.

---

### 09.19 — User guide vault, FAQ, Obsidian migration guide

**Purpose.** Help users inside the app, in the format the app itself reads.

**Files.** `app/assets/guide/` (Markdown pages, below), `app/pubspec.yaml` (declare `assets: - assets/guide/` — one entry per folder level), `app/lib/core/guide/guide_installer.dart`, command `app.open-user-guide` + first-run hint, `docs/user/FAQ.md` (same text as `app/assets/guide/FAQ.md`; the site generator reads `app/assets/guide/FAQ.md` directly — no copy), tests `app/test/core/guide/guide_vault_test.dart`.

**Implementation.**
1. **Pages** (file names; each starts with frontmatter `tags: [tephra-guide]`; headings `#`; cross-links as `[[Page name]]`; plain language; short; one concept per page; every instruction names the **button/menu text exactly as in l10n** and gives both the phone and the PC way):
   `00 Start here.md` (what Tephra is, 5-minute tour, links to everything), `01 Your vault and files.md` (vault = folder; Android All-files-access why; where `.tephra/` is), `02 Writing notes.md` (editor modes, toolbar, Markdown cheat-sheet incl. callouts, tasks, math, footnotes), `03 Links and backlinks.md` (`[[ ]]`, aliases, headings, block IDs, embeds, unlinked mentions), `04 Search and quick switcher.md` (operators table from Phase 2), `05 Properties and tags.md`, `06 Sync with Google Drive.md` (setup, encryption + recovery key, two-device demo, conflicts, history, backups/restore, what "mobile mode" means), `07 Backups and history.md`, `08 Stickies and quick capture.md`, `09 Importing.md` (sources from Phase 5), `10 Exporting and sharing.md`, `11 Graph, Canvas and Bases.md`, `12 AI assistant.md` (key, privacy, confirm-before-send), `13 Tasks, Kanban, flashcards.md`, `14 Encryption and app lock.md`, `15 Keyboard shortcuts.md` (generated from the command registry by a test-time tool so it cannot go stale: `tool/gen_shortcuts_page.dart` or a Dart test that **fails** when the page differs from the registry; commit the generated text), `16 Troubleshooting.md` (index rebuilt, sync conflicts, device full, damaged remote data banner from 09.9, recovery key lost, updates), `FAQ.md`, `Migrating from Obsidian.md` (item 4), `Privacy and your data.md` (short, links to the policy), `About Tephra.md` (version placeholder `{{version}}` replaced at install time).
2. **FAQ** (`FAQ.md`, ≥ 25 Q&As, each 2–5 sentences): Is Tephra free? Is it open source (no; closed source, free to use — human to confirm pricing text)? Does it work with my Obsidian vault? Can I use Obsidian and Tephra at the same time (yes on a folder; do not run two sync systems on the same vault; `.obsidian` is never written)? Why does Android ask for "All files access"? Where are my notes stored? What if I lose my sync password / recovery key (cannot be recovered, by design; notes on devices remain)? Does Google see my notes (not with encryption on; sees encrypted blobs and the vault name)? Why does Google say "unverified app"? Why weekly reconnect (only before the app is published)? What happens on a sync conflict? Where did my deleted note go (Recently deleted / vault `.trash`)? How do I restore an old version? How do I back up (daily encrypted backups; restore into new folder)? Is AI mandatory (no; your own key; nothing sent without your action)? Which data leaves my device (link to privacy page)? How do I update (in-app; direct download; the universal vs ABI APK note from 09.1; SmartScreen warning explained; Play Protect notice)? How do I uninstall without losing notes (notes are your files; uninstall removes only the app)? Can I run it on iPhone/Mac/Linux (not yet)? Why is Bangla OCR missing? How do I report a bug (email; include the "Copy diagnostics" text; crash-report event id)? Keyboard shortcuts? Performance tips for huge vaults (excluded folders, mobile mode)?
3. **Obsidian migration guide** (`Migrating from Obsidian.md`) — sections: *The short version* (open the same folder; nothing to convert); *Step by step* (Android: grant All-files-access, pick the vault folder; Windows: open folder; first index progress); *What Tephra reads from `.obsidian`* (hotkeys? types.json, bookmarks, daily-notes/templates/attachment settings — **exactly the set Phase 1/7 import**, verified against the code) and *what it never writes* (`.obsidian/` is read-only; Tephra's data is in `.tephra/`); *Feature mapping table* (Obsidian core plugins → Tephra: from the Phase 7 parity checklist: supported / partial / not supported); *Community plugins* (not supported; Dataview → `tephra-query` (subset), Tasks format compatible, Kanban compatible, Templater not supported (templates core only), Calendar → daily-notes command; link to Phase 8 unsupported list); *Themes and CSS snippets* (not applied; `cssclasses` preserved); *Sync warning* (Obsidian Sync/iCloud/Syncthing + Tephra's Drive sync on the same vault = conflicts; choose one); *Things that look different* (live preview details); *Going back* (the vault stays Obsidian-compatible; nothing to undo); *Checklist* (10 items). Keep a table of **known differences** from the Phase 7/8 limitation lists (inline fields unsupported, `file.etags`, Bangla OCR, WAV-only transcription, AVX2 requirement for semantic indexing on Windows — copy from `PROGRESS.md`).
4. `GuideInstaller` (app): command `app.open-user-guide` (palette + Settings → Help) and a one-time hint on first run ("New to Tephra? Open the user guide"): asks "Where should the guide be created?" with default `<Documents>/Tephra Guide`; writes every asset file (read via `AssetManifest.loadFromAssetBundle` filtered by prefix `assets/guide/`) through `IoVaultFileSystem` (atomic writes), creates `.tephra/vault.json` (new id), replaces `{{version}}`, then opens it as a vault via the Phase 1 vault-opening code. If the folder exists and contains `.tephra/vault.json` → just open it (never overwrite the user's edits). Re-creating after an app update: "Update the guide" writes the new pages as `<name> (new).md` only if the existing page differs from the **previous shipped** hash (stored in `.tephra/guide-hashes.json`), otherwise overwrites silently; never deletes pages.
5. The guide is itself a **fixture vault**: `app/test/core/guide/guide_vault_test.dart` loads every guide file with `MarkdownParser.parse` and asserts: each `[[wikilink]]` resolves to an existing page (case-insensitive, using the Phase 2 resolution rules against an in-memory index of the guide), no page has an empty body, every page has the tag, no line contains `TODO` or `{{` except `{{version}}`, total size < 400 KiB. Also run it through the Phase 5 HTML exporter once to prove it renders (no exceptions).
6. Screenshots are **not** included in v1.0 (they go stale and add size); the human may add images later to `app/assets/guide/media/`. Write in `PROGRESS.md` → Ideas.

**Tests.** The guide-vault test above; the shortcuts-page-equals-registry test; `GuideInstaller` against `MemoryVaultFileSystem` (creates all files, never overwrites an existing guide folder with `.tephra/vault.json`, update rule).

**Verify.** `flutter test test/core/guide`; manual: open the guide on both platforms, follow three links, search inside it.

**Pitfalls.** Instructions must match the real UI strings — copy label text from `app_en.arb`, not from memory. Do not link to pages that do not exist yet (Tephra Cloud is documented in Phase 10).

---

### 09.20 — Beta, update-path test, release candidate, final gate, v1.0.0

**Purpose.** Prove the whole chain with real people and real files, then ship. Needs **H6, H7, H9**.

**Files.** `docs/release/tester-guide.md`, `docs/release/smoke-test.md` (results), `docs/release/beta-report.md`, `CHANGELOG.md` (final), `PROGRESS.md`, `app/pubspec.yaml` (version), `secrets/release.json` (URLs).

**Implementation.**
1. **Tester guide** (one page, for non-developers): how to install (Android / Windows), what to test for two weeks (use Tephra for real notes; try sync on two devices; try the user guide; try an update), how to report problems (email + "Copy diagnostics" button + whether crash reports were allowed), a data-safety promise ("keep your own copy of your vault for the beta"), and a short feedback form (list of 8 questions).
2. **Release candidate 1:** set `app/pubspec.yaml` `version: 1.0.0+<next build>`; finalise the `CHANGELOG.md` `1.0.0` section; `dart run tool/release.dart build --all --rc 1`; run `docs/release/smoke-test.md` on the 4 GB phone and the Windows PC **using the produced files** (installer, APK, portable zip); tag `v1.0.0-rc.1`. Publish **privately first**: Option A: a draft/pre-release; Option B: a hidden URL. Send to testers.
3. **Update-path test (mandatory):** (a) install the previous published build (`0.9.0+<n>` from the earlier rc, installed from its real installer/APK, **signed with the same key**) on a phone and the PC; publish the new manifest on the real hosting (pre-release manifest URL for the test is **not** the production URL: use a test manifest URL via a separate build flag, **or** temporarily point production at rc.2 only if no real users exist yet — at this stage none do); (b) in the old build: Settings → About → Check for updates → available → install → app restarts on the new build with data intact; (c) the automatic daily check: set `lastUpdateCheckSuccessAt` back 25 h (debug command `debug.reset-update-check`, debug builds only) and restart → banner appears. Record both platforms in `beta-report.md`. **Android signing continuity check:** the update installs over the old APK without "App not installed" — proves same key.
4. **Beta (2 weeks, ≥ 10 users or own heavy use):** daily log in `beta-report.md`: installs, crashes (Sentry crash-free sessions % from Sentry → Releases → `tephra@<version>`), data-loss reports (must be **zero**), top issues. Fix issues as small commits on `phase-09` with regression tests; any fix that touches sync, vault writes or crypto needs a full re-run of 09.8–09.9 drills before the next rc (record). Each rebuilt artifact set bumps the build number and gets a new rc tag (`rc.2`, …).
5. **Performance and size re-check** on the final candidate (numbers in `perf-v1.0.md`, `size-v1.0.md`): all budgets on the low-end phone and Windows; APK < 40 MB per ABI (or the recorded approval).
6. **Final release:** human completes H7 (placeholders replaced, review done) → `legal_test` and `release.dart` preflight pass → build the **final** artifacts (no `--rc`, no `--skip-checks`) → publish per 09.17 order (binaries, verify, page, **manifest last**) → fetch the public manifest and verify its signature → tag `v1.0.0` on `main` after merging (`git checkout main; git merge --no-ff phase-09; git tag v1.0.0`) → **archive**: copy `dist/1.0.0/` (including symbols zips and private checksums) and the signed manifests to the human's backup location; ask the human to confirm the keystore and `update_signing_key.json` backups are done (checklist ticks with dates in `KEY_BACKUP.md`).
7. **Rollback plan** documented in `docs/release/distribution.md`: if a bad release ships — (1) immediately republish the previous manifest (apps stop seeing the new version); (2) fix; (3) ship a higher build number (never reuse a build number or version).
8. Update `PROGRESS.md`: all steps ticked, the gate numbers, known limitations, contract additions (`VaultStorageFullException`, `SyncStateCorruptException`, `DamagedRemote`, `IoVaultFileSystem` file-opener seam, updater settings keys).

**Verify.** All of Exit gate.

**Pitfalls.** Do not publish the manifest before the binaries are verifiable at their URLs. Do not reuse a build number. Do not skip the update-path test: a broken updater cannot be fixed by an update.

---

## Demo script

Run with the **final release artifacts** on the 4 GB Android phone and the Windows PC (fresh, nothing installed), and record results in `PROGRESS.md`:

1. **Download page**: open it on the phone; the Android arm64 button is highlighted; download the APK; compare the SHA-256 shown with the file (PC: `Get-FileHash`). On the PC download the installer and compare.
2. **Install**: Android (Install unknown apps → install; launch). Windows: run the installer → per-user install → desktop shortcut ticked → launch from the finish page. Neither shows a "missing VCRUNTIME140.dll" error.
3. **First run**: the welcome/consent dialog; choose "No thanks"; Settings → Privacy shows crash reports off; the guide hint appears.
4. **User guide**: open the guide vault, follow 3 links, search "sync".
5. **Obsidian vault**: open a copy of the real Obsidian vault; compare against the Migration page checklist.
6. **Sync + encryption** (Phase 3 demo condensed): set up Drive sync with the **release** Google client, create an encrypted vault, connect the phone, edit on both, resolve one conflict.
7. **Crash opt-in**: Settings → Privacy → allow crash reports; use the release-with-test-define build to throw the test crash; open the event in Sentry — no message, paths or user; then turn the switch off.
8. **Data-safety**: fill the phone storage nearly full → banner, no crash → free space → saves; corrupt the search index file (close app; overwrite first 100 bytes) → app starts, "Search was rebuilt"; kill the app during a 500-file sync 5 times → everything converges.
9. **Update**: with the previous build installed (the rc), Settings → About → Check for updates → install → restarts on the new version with the vault, tabs and settings intact (both platforms).
10. **Uninstall** on Windows → vault folders and app data remain.

## Exit gate

Check every item; record numbers and dates in `PROGRESS.md`. Any failing item → stop and ask the human (GEMINI.md §5).

- [ ] Steps 09.1–09.20 ticked; `flutter analyze --fatal-infos` 0 issues; every package's tests, `flutter test --exclude-tags golden` and `dart test tool/test` pass; `dart run tool/check_licenses.dart` passes; hygiene tests green.
- [ ] **Beta:** 2 weeks with ≥ 10 users (or the human's own heavy daily use on phone + PC) with **no data-loss report**; `beta-report.md` written; Sentry crash-free sessions ≥ **99.5%** for the final release candidate when ≥ 100 sessions were recorded (otherwise: zero unresolved crash groups with more than one occurrence, and the report says how many sessions were seen).
- [ ] **Performance:** every conventions §10 budget met on the 4 GB phone and Windows (numbers in `perf-v1.0.md`), no jank during idle sync or a 500-file sync, unsaved text survives process death.
- [ ] **Size:** release APK < 40 MB per ABI (`size-v1.0.md`), or the human's written approval line `SIZE-APPROVED 1.0.0` in `PROGRESS.md`.
- [ ] **Security and licences:** `security-review.md`, `permissions.md`, `licence-review.md` complete with no open "fail"; the permission list equals the shipped APK's; `THIRD_PARTY_NOTICES.md` regenerated and shown in the About page.
- [ ] **Data-safety drills** D1–D5 all pass with logged evidence; the 1,000-seed crash-point drill and the 200-iteration real-kill drill have 0 failures; corrupted index auto-rebuilds; corrupted remote journal is quarantined and reported with the three user actions working.
- [ ] **Crash reporting:** off until the user opts in (verified by network inspection: no request to `*.ingest.sentry.io` before consent); on-event JSON contains no note text, paths, names, user, IP or breadcrumbs (09.3 verify), and the setting can be turned off at once.
- [ ] **Signing and artifacts:** signed APKs (3 ABI + universal), Windows installer, portable zip, `SHA256SUMS.txt`, `manifest.json` + `manifest.json.sig`, symbols archived; every APK's certificate SHA-256 equals `signing-cert.md`; the installer runs on a clean Windows machine/Sandbox with no runtime error; keystore and update-signing-key backups ticked in `KEY_BACKUP.md`.
- [ ] **Updates:** in-app update from the previous release verified on **both** platforms (Android keeps data and signature continuity; Windows silent upgrade relaunches); tampered file and bad signature both refused; automatic check runs at most once per day.
- [ ] **Distribution:** download page + privacy policy + EULA published at the chosen hosting; manifest URL recorded and stable; Google OAuth consent screen points at the privacy policy; templates have no `{{PLACEHOLDER}}` left (H7 done).
- [ ] **Docs:** user-guide vault shipped and tested, FAQ ≥ 25 Q&As, Obsidian migration guide present; `CHANGELOG.md` final.
- [ ] `PROGRESS.md` updated; `git checkout main; git merge --no-ff phase-09; git tag v1.0.0`; stop and report to the human.

## Hand-off

What Phase 10 (Tephra Cloud) relies on, all committed:

1. **Versioning and release plumbing** — `docs/release/versioning.md` rules, `tool/release.dart` (Phase 10 extends it with a `server` command and a Windows/Linux server artifact set; the server version is the same semver; app `2.0.0+<build>`), the manifest schema `1` (Phase 10 adds nothing to it; self-hosted servers do **not** serve app updates), and the signing keys (Android upload keystore, update-signing key). The release build now also passes `--dart-define TEPHRA_CLOUD_URL=…` through `secrets/release.json` (add the key then).
2. **Privacy policy / EULA templates** — Phase 10 step 10.22 appends the Tephra Cloud section and a separate Terms of Service; the placeholder mechanism and `legal_test` are reused.
3. **Crash reporting** — `CrashService`/`EventScrubber`; Phase 10's new client code must not put server URLs with tokens, emails or object keys into exception messages (the scrubber redacts non-`TephraException` messages; new exceptions extend `SyncException` with technical English only).
4. **Data-safety drills** — the crash-point drill, the real-kill tool (`tool/drill_kill_sync.dart`, parameterised by provider) and the corrupted-remote tests are re-run **against the Tephra Cloud provider** in Phase 10 (10.14). `DirectorySyncProvider` is the pattern for a second implementation of the contract suite.
5. **Updater/distribution** — hosting option and the manifest URL are fixed; Phase 10 ships v2.0 through the same channel (manifest bump). The OAuth release client and consent-screen state stay as they are.
6. **Contract additions** from this phase (fold into `00-conventions.md` when the human approves): `VaultStorageFullException` (tephra_core), `SyncStateCorruptException` and `DamagedRemote` (tephra_sync), `IoVaultFileSystem` file-opener seam, `SyncEngine.republishPaths`, reader-local `skippedBatches`. Phase 10 must not contradict them.
7. **Open limitations to carry:** no forced updates; no portable-data mode; no Play/MS Store builds (Phase 11 removes `REQUEST_INSTALL_PACKAGES` via a flavor and disables the updater there).
