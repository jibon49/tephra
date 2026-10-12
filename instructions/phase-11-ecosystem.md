# Phase 11 — Ecosystem: stores, collaboration spike, web clipper, plugins, more platforms, static sites

> **Duration:** open-ended ("later"). The eight work items below are **independent** and can be done in any order the human chooses, one at a time (suggested order: A Play Store → B Microsoft Store → H static-site publishing → D web clipper → E plugin API → F iOS/macOS/Linux → C collaboration spike). Each item has its own steps, its own **gate**, and ends with a merge and a tag; nothing here blocks anything else, except that **11.1 (build flavors) must be done first**.
> **Goal:** widen Tephra's reach (stores, more platforms), add the ecosystem features that need new designs (real-time collaboration, web clipping, plugins), and let people publish a vault as a website — without changing the sync format, the engine, or the closed-source, permissive-licence rules.
>
> **Decisions made for you (do not revisit):**
> v1.0/v2.0 stay direct-download; the **store builds are separate build flavors** of the same code (`TEPHRA_DIST` = `direct` | `play` | `msstore` | `appstore`) with the **in-app updater and `REQUEST_INSTALL_PACKAGES` removed** from store builds (store policies forbid self-updating);
> the Android package id stays `com.tephra.app` for every distribution;
> collaboration = a **design spike only** in this phase (recommendation: own pure-Dart sequence CRDT, RGA/YATA-style) — no collaboration feature ships here;
> the web clipper sends **end-to-end-encrypted** clips to a per-vault inbox on Tephra Cloud (the server never sees clip content), with a `tephra://clip` fallback that always asks for confirmation;
> plugins run in **QuickJS inside a separate isolate**, permission-gated, installed per device (never synced through a vault), sideload-only in v1;
> macOS ships first as a notarized **Developer ID DMG** (not sandboxed); iOS is built and tested through **TestFlight** — App Store submission is a documented follow-up, not a gate;
> the static-site exporter lives in `tephra_io` as a normal `Exporter` (no new package, so conventions §2 is unchanged).
>
> **Not in this file (kept in `PROGRESS.md` → Ideas, from PHASE_PLAN Phase 11):** extra sync targets (WebDAV/Nextcloud, S3, Dropbox, OneDrive, Git). The `SyncProvider` interface already supports them; each is a separate small phase when wanted.

Read this whole file once. Pick one item with the human, do its steps in order, run its gate, merge, tag, stop. Every step ends with the standard GEMINI.md §3 loop (format, analyze, tests of touched packages, tick `PROGRESS.md`, commit `phase 11.N: <summary>`). Use one branch per item (`phase-11a-play`, `phase-11b-msstore`, `phase-11c-collab-spike`, `phase-11d-clipper`, `phase-11e-plugins`, `phase-11f-platforms`, `phase-11h-sitepub`, plus `phase-11-flavors` for step 11.1) and tags `v2.<n>.0` (store/platform items) or `v2.<n>.0-<item>` as the human decides.

---

## Before you start

### Prerequisite gate (check each; write the result in `PROGRESS.md`)

1. `PROGRESS.md` shows the Phase 10 exit gate fully checked; `git tag` lists `v2.0.0`; Tephra Cloud has been in production for at least **2 weeks** without a severity-1 incident (for items D and C, which touch the server). You are on `main`, tree clean.
2. `flutter analyze --fatal-infos` = 0; `dart test` passes in every package and `server/`; `flutter test --exclude-tags golden` passes; `dart run tool/check_licenses.dart` passes; `dart test tool/test` passes.
3. Read `docs/decisions/cloud-api-v1.md` (additive-only rule for new server endpoints), `docs/decisions/sync-format-v1.md`, `docs/release/versioning.md`, `docs/release/permissions.md`, `docs/legal/*`, and the Phase 9/10 hand-off sections.
4. For the item you are about to start, the human has completed its **Human prerequisites** (below). Ask for them when the item starts, except the store accounts (A, B, F), which have identity-verification lead times — ask at the very beginning if the human wants any store item.

### What already exists (from Phases 0–10) and what you rely on

| Thing | Where | Used by |
|---|---|---|
| Release pipeline `tool/release.dart`, signing, updater, `docs/release/*`, download site generator | Phase 9 | 11.1, A, B, F |
| Android permission list and justifications `docs/release/permissions.md`; merged-manifest check in `release.dart` | Phase 9 (09.6) | A |
| Privacy policy / Terms templates, `legal_test`, `PLACEHOLDERS.md`, server legal pages generator | Phases 9–10 | A, B, D |
| Tephra Cloud server (`server/`), API v1, WebSocket events, accounts, admin CLI | Phase 10 | C, D |
| `VaultFileSystem`, `IoVaultFileSystem`, `MemoryVaultFileSystem`; platform service interfaces in `app/lib/core/platform/` | Phases 1–4 | A (SAF contingency), E, F |
| `Exporter` interface, Phase 5 HTML/markdown renderer, `ExportSink`, export UI | `packages/tephra_io`, `app/lib/import_export/` | H |
| `MarkdownParser`, `NoteIndex` (links, backlinks, tags), graph layout code | Phases 1, 2, 6 | E, H |
| Command registry (conventions §7.8), `StoragePermissionService` | Phases 1–2 | E, A |
| Windows installer `installer/tephra.iss` | Phase 9 | D (protocol handler) |

---

## Human prerequisites

### HA. Google Play Console (item A) — **lead time: days to weeks**

1. Create a **Google Play developer account** at https://play.google.com/console (one-time USD 25 fee). Choose **organisation** if the human has a registered business (needs a D-U-N-S number; verification can take days) or **personal**. **Important policy (verify the current text in the Console's "Testing requirements" before relying on it):** newly created **personal** accounts must run a **closed test with at least 12 testers opted in for 14 continuous days** before they can apply for production access; organisation accounts are exempt.
2. Complete identity verification (government ID; for organisations, D-U-N-S + website + phone). Add a payments profile only if paid apps/IAP are ever planned (not now).
3. Create a **Google Group or a list of 12+ tester email addresses** (Gmail accounts) willing to install from the closed-test link for 14 days (friends, beta users from Phase 9).
4. Provide: developer name (shown on the store), support email, support website (the download page), the privacy-policy URL (Phase 9), and the **account-deletion web page URL** (11.4 creates it on the Tephra Cloud server).
5. Decide how the **app signing key** is handled (11.2 explains the two options and recommends one); the human confirms.

### HB. Microsoft Partner Center (item B)

1. Register at https://partner.microsoft.com/dashboard (individual: one-time fee about USD 19; company: about USD 99 — **verify current fees**). Complete identity verification.
2. **Reserve the app name** (`Tephra`; if taken use `Tephra Notes`). Then open the product → **Product identity** and copy exactly: **Package/Identity/Name**, **Package/Identity/Publisher** (`CN=…`), **Package/Properties/PublisherDisplayName**. Give them to Gemini (they are public values, not secrets).
3. Tell Gemini the intended **age rating answers** (the questionnaire is done in the portal by the human).

### HC. Collaboration spike (item C)

No accounts needed. The human decides who reviews the design (the decision document needs the human's written approval before any implementation phase).

### HD. Web clipper (item D)

Node.js LTS (≥ 20) on the dev PC: `node -v`; if missing `winget install -e --id OpenJS.NodeJS.LTS` (may need administrator approval). Chrome and Edge for testing. Optional publishing: Chrome Web Store developer account (one-time USD 5, https://chrome.google.com/webstore/devconsole) and Microsoft Edge Add-ons account (free, https://partner.microsoft.com/dashboard/microsoftedge). The human decides whether to publish publicly or distribute the unpacked/zip extension only.

### HE. Plugin API (item E)

No accounts. The human decides whether plugin **installation from the internet** is ever allowed (v1 default: **local file only**).

### HF. iOS / macOS / Linux (item F) — **lead time: Apple enrolment**

1. **Apple Developer Program** (USD 99/year, https://developer.apple.com/programs/enroll/) with identity verification. Needed for TestFlight, notarization and the App Store.
2. A **Mac** with a current Xcode (App Store) for builds, **or** the human agrees to use **GitHub-hosted macOS runners** (macOS minutes cost 10× on private repositories — budget it) for CI builds; signing certificates must still be created in the Apple Developer portal and exported by the human (Gemini lists the exact clicks in 11.19/11.20).
3. A real iPhone (iOS 16+) for the iOS gate; a Mac (Apple silicon or Intel) for the macOS gate; a Linux machine or WSL2 Ubuntu 24.04 for Linux (`wsl --install -d Ubuntu-24.04`, needs administrator approval and a reboot).
4. **Legal flag for the human:** apps that include end-to-end encryption beyond the operating system's own must answer Apple's **export-compliance** questions (`ITSAppUsesNonExemptEncryption`) and may need an annual self-classification report to the US BIS (and a declaration in France). Gemini will **not** guess; the human decides with legal advice before TestFlight external testing.

### HH. Static-site publishing (item H)

None. For the demo, the human chooses a free host to try (GitHub Pages, Cloudflare Pages or Netlify drop) — or just opens the exported folder locally.

---

## What exists when done (per item)

- **11.1** build flavors + `TEPHRA_DIST` switch; store builds without updater/`REQUEST_INSTALL_PACKAGES`.
- **A** `play` flavor, signed `.aab`, listing text and assets, "All files access" declaration text + demo video script, Data safety answers derived from the real data flows, target-API compliance, closed test → production, account-deletion web page; contingency plan for a Storage Access Framework vault.
- **B** MSIX package (`msix` package) with Partner Center identity, WACK-passing, `msstore` build without updater, store listing, submission.
- **C** `docs/spikes/crdt/` — criteria, candidate evaluation, a pure-Dart RGA prototype with property tests and benchmarks, and a signed-off design document (key sharing, protocol, file integration).
- **D** `clipper/` Chrome/Edge MV3 extension (Readability → Markdown), per-vault E2EE inbox on Tephra Cloud (server endpoints, migration `m003`), the app-side inbox consumer, the `tephra://clip` handler.
- **E** QuickJS plugin runtime in an isolate, `plugin.json` manifest, permission model, API v1, plugin manager UI, three sample plugins, `docs/plugins/PLUGIN_API.md`.
- **F** `ios/`, `macos/`, `linux/` runners, platform service implementations, dependency/platform audit, signed/notarized macOS DMG, Linux `.tar.gz` + `.deb`, an iOS TestFlight build, updater/manifest additions for macOS and Linux.
- **H** `StaticSiteExporter` in `tephra_io`, site assets (CSS, search, graph), preview server, wizard, fixture vault and tests, deployment guides.

---

## Dependencies

Add each with `flutter pub add` (app) or `dart pub add` (package/server) as stated, then `flutter pub get` at the repo root and `dart run tool/check_licenses.dart`. Licences marked "verified" were checked on pub.dev when this file was written; **re-check every package's page (licence + README + API) when adding it**. Native/JS components are listed with their licences too; anything not MIT/BSD/Apache-2.0/zlib/MPL-2.0/Unlicense → stop and ask.

| Item | Package / component | Where | Licence | Why |
|---|---|---|---|---|
| A, B | none new (Gradle/MSIX tooling only) | — | — | `bundletool` (Apache-2.0), `pepk.jar` (Google) and WACK are **tools**, not shipped |
| B | `msix` (3.18.0) | app, **dev** dependency | MIT (verified) | builds the `.msix` |
| D | `app_links` (7.2.2) | app | Apache-2.0 (verified; custom schemes supported on Windows) | `tephra://clip` and other deep links |
| D | `cryptography` (already present) | app, server | Apache-2.0 | X25519 + HKDF + AES-GCM sealed boxes |
| D | `@mozilla/readability`, `turndown`, `turndown-plugin-gfm`, `esbuild` (dev) | `clipper/` (npm) | Apache-2.0, MIT, MIT, MIT — **re-check each package's `LICENSE` on npm/GitHub** | page extraction, HTML→Markdown, bundling |
| E | `flutter_js` (0.8.7) | app | MIT (verified; QuickJS on Android/Windows/Linux, JavaScriptCore on iOS/macOS) | JS runtime. QuickJS itself is MIT. **Spike 11.15 decides** whether this package or an alternative is used (candidates: `flutter_qjs`, `fjs` — check licences and maintenance) |
| F | per-platform plugin support | app | various | audited by `tool/platform_audit.dart` (11.18); replacements for unsupported plugins must stay permissive |
| F | `create-dmg` (optional tool) | dev machine | MIT | DMG creation |
| H | KaTeX (optional bundled asset), Mermaid (optional bundled asset) | `app/assets/site/` | MIT, MIT — **verify the files you copy carry their licence headers** | math/diagram rendering in exported sites (off by default) |
| C | none (spike code is pure Dart, no dependencies) | `docs/spikes/crdt/` | — | |

No other new dependencies are allowed. Copyleft is forbidden everywhere (including test images and build tools that would be linked into artifacts).

---

## Steps

Every step has **Purpose / Files / Implementation / Tests / Verify / Pitfalls**. "Verify" always also means:

```
dart format --output=none --set-exit-if-changed app/lib app/test packages server tool
flutter analyze --fatal-infos
```

plus `dart test` in every package you touched and `flutter test --exclude-tags golden` in `app/` if you touched the app. Every new Dart file starts with `// © 2026 Tephra. All rights reserved.`; user-visible strings go to `app_en.arb`. Logger names: `dist`, `clip`, `plugin`, `site`, `collab`.

---

### 11.1 — Build flavors and the `TEPHRA_DIST` switch (do this first)

**Purpose.** One code base, several distributions, with store builds that cannot update themselves.

**Files.** `app/android/app/build.gradle.kts`, `app/android/app/src/direct/AndroidManifest.xml`, `app/android/app/src/play/AndroidManifest.xml`, `app/android/app/src/main/AndroidManifest.xml` (edit), `app/lib/core/distribution.dart`, `app/lib/core/updater/` (guards), `app/lib/settings/about/about_page.dart` (edit), `tool/release/android_build.dart`, `tool/release/windows_build.dart` (edit), `.github/workflows/ci.yml` (edit), `docs/release/distributions.md`, tests `app/test/core/distribution_test.dart`, `tool/test/release_flavor_test.dart`.

**Implementation.**
1. **Dart switch:** `enum Distribution { direct, play, msstore, appstore, macosDirect, linuxDirect }` and `final distribution = Distribution.fromName(const String.fromEnvironment('TEPHRA_DIST', defaultValue: 'direct'))` in `distribution.dart`; getters `updaterAllowed` (`direct`, `macosDirect`, `linuxDirect` only), `showsDonationOrExternalLinks` (reserved, false for stores), `crashReportingAllowed` (all; unchanged). The updater (09.14–09.16), the "Check for updates" rows, the auto-check, the update snackbar and the `installApk` call are **all behind `distribution.updaterAllowed`**; add a test that `UpdateController.checkNow` returns `UpdateNotConfigured` when not allowed, and a hygiene test (`tool/test/hygiene_test.dart`) that fails if `REQUEST_INSTALL_PACKAGES` appears in `app/android/app/src/main/AndroidManifest.xml` or `src/play/`.
2. **Android flavors** (Kotlin DSL, inside `android { … }`):
   ```kotlin
   flavorDimensions += "dist"
   productFlavors {
       create("direct") { dimension = "dist" }
       create("play")   { dimension = "dist" }
   }
   ```
   **No** `applicationIdSuffix` — every flavor is `com.tephra.app` (the Google OAuth Android client matches package + signing-certificate SHA-1; Phase 3/9 setup keeps working). Move the Phase 9 additions (`REQUEST_INSTALL_PACKAGES`, the `UpdateFileProvider` `<provider>`, `res/xml/update_file_paths.xml`, `InstallerChannel.kt` registration) from `src/main` to `src/direct/` (`src/direct/AndroidManifest.xml`, `src/direct/kotlin/com/tephra/app/…`, `src/direct/res/xml/…`); `MainActivity` registers the channel through a flavor-specific hook (`src/direct/kotlin/.../DistributionHooks.kt` implements `registerExtras(flutterEngine)`; `src/play/kotlin/.../DistributionHooks.kt` is empty). `src/play/AndroidManifest.xml` contains `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" tools:node="remove" />` as a guard against plugins re-adding it.
3. **Commands change** (flutter needs `--flavor` once flavors exist): every Android build/run now reads `--flavor direct` (or `play`) and `--dart-define=TEPHRA_DIST=<dist>`: `flutter run -d <phone> --flavor direct`, `flutter build apk --release --split-per-abi --flavor direct --dart-define=TEPHRA_DIST=direct …`, `flutter build appbundle --release --flavor play --dart-define=TEPHRA_DIST=play …`. Output APK names change to `app-<abi>-direct-release.apk` (update `tool/release/android_build.dart` paths and its tests, the CI `android` job (`flutter build apk --debug --flavor direct`), the README, `.vscode/launch.json` if present). Dev Launcher's web preview is unaffected.
4. **Windows:** no flavors; the Store build passes `--dart-define=TEPHRA_DIST=msstore` (11.7); the Inno installer build passes nothing (default `direct`).
5. `docs/release/distributions.md`: a table of every distribution — package id, signing, updater yes/no, permissions differences, where built, how updated.

**Tests.** The distribution switch and updater guards; hygiene test; flavor release test (`release.dart` passes `--flavor direct` and finds the renamed APKs; fails loudly if a `play` flavor APK contains `REQUEST_INSTALL_PACKAGES` per `aapt2 dump permissions`).

**Verify.** `flutter build apk --debug --flavor direct` and `--flavor play` both build; `aapt2 dump permissions` of the play APK lacks `REQUEST_INSTALL_PACKAGES`, the direct APK has it; the direct release build still updates in-app (re-run the 09.15 manual test once).

**Pitfalls.** Forgetting `--flavor` makes Flutter fail with a confusing error — put the exact commands in the README. Do not give the flavors different `applicationId`s. Do not leave the updater code reachable in the `play` flavor even if the UI row is hidden (the guard must be in the controller, not only the widget).

---

## Item A — Google Play Store

### 11.2 — Android App Bundle, Play App Signing, target API, native symbols

**Purpose.** A Play-ready `.aab` signed correctly.

**Files.** `app/android/app/build.gradle.kts` (edit), `tool/release/play_build.dart`, `tool/release.dart` (command `play`), `docs/release/play.md`, tests.

**Implementation.**
1. **Target API:** open https://developer.android.com/google/play/requirements/target-sdk and read the **current** requirement (as of late 2026 new apps and updates must target the API level shipped one year earlier — expected **API 36 / Android 16**; Flutter 3.47's default `targetSdk` already follows). Record the required level and the date of the check in `docs/release/play.md`. `minSdk` stays 26. Confirm 64-bit (arm64-v8a is built) and that the bundle is < 200 MB (base module).
2. **Build:** `Push-Location app; flutter build appbundle --release --flavor play --obfuscate --split-debug-info=build/symbols/play --dart-define-from-file=../secrets/google_oauth.json --dart-define-from-file=../secrets/sentry.json --dart-define-from-file=../secrets/release.json --dart-define=TEPHRA_DIST=play; Pop-Location` → `app/build/app/outputs/bundle/playRelease/app-play-release.aab`. Add to `build.gradle.kts` `android { buildTypes { release { ndk { debugSymbolLevel = "SYMBOL_TABLE" } } } }` so Play Console gets native symbols (silences the "no debug symbols" warning). Check the bundle with Google's tool: `bundletool` (Apache-2.0, download the jar from https://github.com/google/bundletool/releases): `java -jar bundletool.jar validate --bundle=app-play-release.aab` and `build-apks --bundle=… --connected-device --output=tephra.apks --ks=…` + `install-apks` on the phone for a smoke test (09.5 list). R8 rules from 09.5 apply.
3. **Signing — decision with two paths (the human confirms the path before the first upload):** Play requires **Play App Signing** for new apps. **Path 1 (recommended):** in Play Console → *Setup → App signing* choose "Use the same key as the app signing key" — **upload the existing keystore key** (`secrets/tephra-upload.jks`, alias `tephra-upload`) using Google's `pepk.jar` export tool as described in the Console (the Console shows the exact command; it creates an encrypted `.zip` with `--include-cert`, run by the **human** because it needs the passwords and Google's encryption public key file). Result: the **same signing certificate** for direct APKs, Play installs and Google OAuth (no new SHA-1 needed; direct↔Play updates work without uninstalling). **Verify in the Console's requirements which key types/sizes are accepted** (the Phase 9 key is RSA 4096; if Play refuses it, use Path 2). **Path 2:** let Google generate the app signing key; the existing keystore becomes the **upload key** only (register its certificate in the Console); consequence: Play-installed apps carry Google's certificate, so **direct APKs and Play builds are not update-compatible**, and the human must add Google's app-signing SHA-1 (shown in Console → App integrity) as a second Android OAuth client in Google Cloud (like Phase 9 H6) so Drive sign-in works on the Play build. Record the chosen path and both fingerprints in `docs/release/play.md` and `KEY_BACKUP.md`.
4. `tool/release.dart play`: builds the `.aab` (flags above), runs `bundletool validate`, runs the permission check against `docs/release/permissions.md` using the **play** expected list (the play list **excludes** `REQUEST_INSTALL_PACKAGES`), copies to `dist/<version>/tephra-<version>-play.aab` + `tephra-<version>-symbols-play.zip`; version rule: Play requires a **strictly increasing `versionCode`** per upload — the Phase 9 rule (`build` ≤ 999, AAB uses `versionCode = build`, no ABI offset) keeps it monotonic; never reuse a build number.

**Tests.** `release_flavor_test.dart` extended: play permission set, no updater, aab validation parsed from captured `bundletool` output.

**Verify.** The `.aab` validates; the `bundletool`-installed build passes the smoke test; `aapt2 dump permissions` equals the play list.

**Pitfalls.** An upload key and an app signing key are different things — never lose the upload key (Play can reset it by support request, the app signing key cannot be replaced after the fact). Never upload a debug-signed bundle.

### 11.3 — "All files access" declaration, SAF contingency, other permission declarations

**Purpose.** Pass Play review for `MANAGE_EXTERNAL_STORAGE`, or have a ready fallback.

**Files.** `docs/release/play-declarations.md` (texts), `docs/release/play-demo-video.md` (script), `docs/release/saf-contingency.md`, optionally (only if needed) `app/lib/core/vault/saf/` (see below), tests.

**Implementation.**
1. **Draft the declaration** (Play Console → *Policy → App content → All files access*; **verify the current policy page text before pasting**: https://support.google.com/googleplay/android-developer/answer/10467955). Core-use-case answer, in the human's name, to adapt:
   > *Tephra is a Markdown note-taking app compatible with the Obsidian file format. A Tephra "vault" is an ordinary folder chosen by the user (for example Documents/MyNotes) that contains thousands of Markdown notes and attachments in sub-folders. The same folder is edited by other apps the user already uses on the phone — Obsidian, file managers, Syncthing and backup tools — so the data must remain plain files in shared storage and cannot live in app-private storage. Core functionality that requires All files access: (1) recursive read and write of every file and sub-folder of the user-chosen vault; (2) detecting changes made by other apps while Tephra is open (directory watching); (3) atomic saves (write a temporary file, then rename) so a crash never corrupts a note; (4) vaults of 10,000+ files, for which the Storage Access Framework (document URIs) is too slow and offers no recursive change notification or atomic rename. Tephra does not use the permission to read any file outside the vault the user selected, does not upload files except through sync features the user enables (encrypted before upload), and shows a clear explanation before sending the user to the system "All files access" screen.*
2. **Demo video** (`play-demo-video.md`: 30–60 s, screen recording from the **play** build, narrated or captioned, hosted unlisted on YouTube — the human uploads): fresh install → first-run explanation screen → tap "Allow" → system "All files access" screen → grant → pick `Documents/TestVault` → create/edit a note → open the same folder in a file manager and in another editor showing the same files → edit externally → Tephra shows the change. Gemini writes the shot list; the human records.
3. **Other declarations** (draft answers in `play-declarations.md`, each justified from `permissions.md`): `POST_NOTIFICATIONS` (reminders), `RECORD_AUDIO` (voice notes; microphone use only on user action), `SYSTEM_ALERT_WINDOW` (capture bubble; Play restricts it — explain the user-initiated floating capture button; if review is risky, make the overlay feature **absent in the `play` flavor** with the Phase 4 `OverlayService` no-op), exact alarms (**use `SCHEDULE_EXACT_ALARM` with the user-granted flow, not `USE_EXACT_ALARM`**, which Play restricts to alarm/calendar apps; if reminders do not need exact time, drop it), foreground services (declare only the types actually present; Play requires a declaration form per type), `USE_BIOMETRIC` (none needed), photo/media permissions (Tephra uses the system picker; none declared).
4. **SAF contingency (build only if the declaration is rejected twice or the human prefers to avoid the permission):** `SafVaultFileSystem implements VaultFileSystem` in the `play` flavor — a platform channel over `ContentResolver` + `DocumentsContract` with a persisted tree URI (`ACTION_OPEN_DOCUMENT_TREE` + `takePersistableUriPermission`); `list` via `buildChildDocumentsUriUsingTree` (cached tree index, background refresh), atomic write = write `name.tephra-tmp` document then `DocumentsContract.renameDocument` and delete the old one (documented as **not atomic on all providers**; the sync/merge rules tolerate it), `watch()` = polling every 2 s of the tree's `lastModified` signature + `ContentObserver` where the provider supports it. Constraints written into `saf-contingency.md`: slower indexing (target < 3× the 10k-note budget — measure), no `dart:io` paths (so features that read raw paths, e.g. OCR on attachments and external-tool integration, need copies into the cache), `MemoryVaultFileSystem`-based tests plus a fake channel. Gate for the contingency: the Phase 1 vault tests pass against the SAF implementation with a fake provider and a manual run on a phone. **Do not build it unless the decision is made** (record the decision and date).

**Tests.** The hygiene test that the `play` flavor's merged manifest declares `MANAGE_EXTERNAL_STORAGE` **only** if `play-declarations.md` has the line `ALL_FILES_ACCESS: yes` (the single switch the human flips if they choose SAF); the first-run explanation screen widget test (text states the reason, has "Allow" and "Not now").

**Verify.** Declaration text and video script reviewed by the human; the play build shows the explanation screen before the system settings page.

**Pitfalls.** Play reviewers reject generic reasons; be specific (above). Do not claim file-manager functionality. Keep the permission request lazy (only when the user opens/creates a vault).

### 11.4 — Data safety form, privacy, account deletion page, listing, assets

**Purpose.** Truthful store metadata derived from what the code does.

**Files.** `docs/release/play-data-safety.md`, `docs/release/play-listing.md`, `docs/release/play-assets/` (checklist + generator notes), server edits for the deletion page (`server/lib/src/web/pages.dart`, `server/lib/src/api/account_deletion_web.dart`, migration `m003_deletion_requests`), tests `server/test/web/account_deletion_web_test.dart`.

**Implementation.**
1. **Data safety answers — derive from data flows, not from memory.** Build the table in `play-data-safety.md` from the Phase 9 network list (`security-review.md` `hosts` block) and the privacy policy; for **each** Play data type say collected/shared, optional/required, purpose, encrypted in transit, deletion. Starting position (**re-verify against Play's current definitions and "data not considered collected" exemptions before submitting; when in doubt declare**):
   | Flow | Play data type | Answer |
   |---|---|---|
   | Notes on device only | — | not collected |
   | Google Drive sync (user's own Drive, our OAuth client) | Files and docs | not collected by us (stays between the user's device and their own Google account); mention in the description |
   | Tephra Cloud account | Personal info: **email address**; User IDs | **collected**, required **only if the user creates an account**, purpose: app functionality + account management, encrypted in transit, **user can request deletion** (in-app + web page) |
   | Tephra Cloud encrypted vault data | Files and docs (end-to-end encrypted; developer cannot read) | declare **collected, optional, encrypted in transit, deletable** unless the current Play text clearly exempts E2EE data — then document the exemption reasoning in the file |
   | Tephra Cloud metadata (device names, vault name, activity times, IP in logs) | App activity / Device or other IDs / Other | collected, optional (only with an account), purposes: functionality, security |
   | Crash reports (opt-in Sentry) | App info and performance: Crash logs, Diagnostics | collected, **optional**, shared with a service provider acting for us, purpose: analytics (stability) |
   | AI features (user's own Anthropic/Voyage key, only on user action) | Files and docs / App activity (text the user sends) | **user-initiated transfer to a third party**; describe; if Play treats it as sharing, declare "shared, optional, user-initiated" |
   | Update check | — | not applicable to the `play` flavor (no updater) |
   | Model downloads | — | none (no user data) |
   Also required: **encryption in transit = yes**; **deletion mechanism = yes** (in-app: Settings → Sync & backup → Delete account; web: the URL below); the declaration must **match** `docs/legal/PRIVACY_POLICY.md` (a test in `tool/test/` asserts that every data type named in `play-data-safety.md` is mentioned in the policy).
2. **Account-deletion web page (Play requires a web link for apps that allow account creation):** server additions (additive, API-compatible): `GET /account/delete` (static page: what is deleted, the 7-day grace, how to do it in the app, **and a form** "Request deletion by email"), `POST /account/delete-request {email}` → always `202`; if the account exists, emails a link `PUBLIC_URL/account/delete/confirm?token=…` (token kind `delete`, 1 h, single use; migration `m003` extends `email_tokens.kind` check/constraint), `GET`/`POST /account/delete/confirm` shows a confirmation button then sets `deletion_requested_at` (same job as 10.11; revokes sessions; sends the "deletion scheduled" mail). Rate limits reuse `forgot_ip`/`forgot_email` buckets. Include in `legal_pages` and the privacy policy.
3. **Store listing** (`play-listing.md`; English first): **Title** (≤ 30 chars) `Tephra – Markdown Notes`; **Short description** (≤ 80) `Obsidian-compatible Markdown notes with private sync, graph and stickies.`; **Full description** (≤ 4,000; sections: what it is, key features (links/backlinks, live preview, search, graph/canvas/bases, stickies & quick capture, encrypted sync with Google Drive or Tephra Cloud, backups & history, AI assistant (optional, your own key), OCR/voice, import/export), privacy summary, permissions explained in plain language (All files access, notifications, microphone), links to guide/privacy/support); **category** Productivity; **tags**; **contact** email, website, privacy-policy URL; **content rating** (IARC questionnaire — notes app, no violence; user-generated content: no sharing between users → answers "no"); **target audience** 18+ unless the human wants 13+ (decide; affects Families policy — choose **not** Designed for Families); **ads** none; **government/financial/health** none; **news** none.
4. **Graphics** (checklist with the exact sizes; the human or a designer supplies art, Gemini lists and validates dimensions with a tool `tool/check_store_assets.dart`): app icon **512×512 PNG** (32-bit, ≤ 1 MB), **feature graphic 1024×500**, **phone screenshots** 2–8 (JPEG/PNG, 16:9 or 9:16, 320–3,840 px per side; take them from the real app with the demo vault: editor, live preview, graph, search, sync, stickies, dark theme), **7-inch and 10-inch tablet screenshots** (recommended; the app has the ≥ 840 dp desktop layout), optional promo video (YouTube). Localisations: English only now; the structure allows Bangla later.

**Tests.** Account-deletion web flow with `TestServer` (form → mail → confirm → pending deletion → job deletes), enumeration safety (same response for unknown email), CSP/escape tests for the new pages, privacy-policy consistency test, asset-checker unit tests with sample files.

**Verify.** Staging page works end to end; the Data safety document is complete and consistent.

**Pitfalls.** Inaccurate Data safety answers are a common cause of removal — never guess; re-read the policy on the day of submission. Do not link to a page that needs the app to be installed.

### 11.5 — Closed testing → production

**Purpose.** Get the first Play release live.

**Files.** `docs/release/play-release-log.md`.

**Implementation.** (1) Create the app in the Console (default language English, app/game: App, free); complete *App content* items (privacy policy, ads, app access (**provide a test Tephra Cloud account** with verified email in "App access" instructions if reviewers need sign-in; features without an account work without it), content rating, target audience, news, data safety, government, financial features, health, **All files access** declaration, account deletion URL). (2) *Testing → Closed testing* → create a track `closed-beta`, add the tester list (HA step 3), upload the **`.aab`** (11.2), write release notes, submit. (3) Testers opt in via the link and install from Play; **keep ≥ 12 opted-in testers for 14 continuous days** (personal accounts) while collecting feedback; fix issues with new builds (new `versionCode`). (4) When eligible: *Production → Create release* → promote the tested build → staged rollout 20% → 50% → 100% over a few days while watching Play Console *Android vitals* (crash rate, ANR) and Sentry. (5) Record dates, review outcomes, policy messages and fixes in the log. If Play rejects the All-files-access declaration, follow `saf-contingency.md`.

**Verify / Gate A.** See "Gate A" in the Exit gates section.

**Pitfalls.** Review can take days to weeks the first time. A rejected declaration blocks the release — keep the SAF decision ready. Play-installed builds must never show or run the updater.

---

## Item B — Microsoft Store

### 11.6 — MSIX package

**Purpose.** A signed-by-the-Store `.msix` that passes certification tooling.

**Files.** `app/pubspec.yaml` (`msix_config`), `app/windows/runner/` (only if needed), `app/assets/store/` (tile logos), `tool/release/msix_build.dart`, `tool/release.dart` (command `msstore`), `docs/release/msstore.md`, tests.

**Implementation.**
1. `cd app; flutter pub add --dev msix` (MIT, 3.18.0 verified); re-read its README for the current config keys.
2. `app/pubspec.yaml` (values from **HB step 2**; placeholders until the human provides them):
   ```yaml
   msix_config:
     display_name: Tephra
     publisher_display_name: <Package/Properties/PublisherDisplayName>
     identity_name: <Package/Identity/Name>
     publisher: <Package/Identity/Publisher, e.g. CN=XXXXXXXX-XXXX-...>
     msix_version: 2.0.7.0          # tool/release/msix_build.dart sets <major>.<minor>.<build>.0
     logo_path: assets/store/tephra_logo_512.png
     capabilities: internetClient
     languages: en-us
     protocol_activation: tephra     # used by item D (tephra://clip)
     store: true
     install_certificate: false
   ```
   **Version rule:** the Store requires the last (4th) part to be `0` and every submission to be higher than the last: use `<major>.<minor>.<build>.0` with the Phase 9 build number (`2.0.7.0`; a new minor resets nothing because compare is lexicographic by part). The tool writes it; it never hand-edits.
3. `flutter build windows --release --obfuscate --split-debug-info=build/symbols/msstore --dart-define=TEPHRA_DIST=msstore --dart-define-from-file=../secrets/…` then `dart run msix:create --store` (the `msix` package can run the build itself; keep the same flags) → `app/build/windows/x64/runner/Release/tephra.msix`. For **local installation tests** build a second package with `install_certificate`/a self-signed test certificate (`msix:create` without `--store`, accept the generated test certificate; install with `Add-AppxPackage`; remove with `Get-AppxPackage *Tephra* | Remove-AppxPackage`). The Store signs the submitted package itself.
4. **Packaged-app behaviours to verify** (record in `msstore.md`): file access to user-chosen vault folders works (a full-trust packaged desktop app uses normal Win32 file access; **writes to `%APPDATA%`/`%LOCALAPPDATA%` are redirected into the package's private store** — settings/index/sync DB therefore live in a different place from the Inno/direct install; that is fine but means **a user moving from direct to Store starts with empty app data** → the first-run flow must offer "Reconnect sync" (the vault master key is in Credential Manager per-user and survives; the sync DB does not: the Phase 9 D3 repair path "Merge both" handles it) and Settings export/import of app settings is out of scope); `flutter_secure_storage` (Credential Manager) works; tray icon, global hotkeys, floating stickies work; `tephra://` protocol activation works (item D); the VC++ runtime is provided by the package framework dependency (`msix` adds `Microsoft.VCLibs` dependency) — no bundled DLLs needed.
5. **Windows App Certification Kit:** run `appcert.exe test -appxpackagepath <msix> -reportoutputpath wack.xml` (installed with the Windows SDK; `C:\Program Files (x86)\Windows Kits\10\App Certification Kit\appcert.exe`; run **elevated** — ask the human) and fix every failure (typical: missing/incorrect asset sizes, restricted capability use, debug-signed binaries). Save the report in `docs/release/`.
6. The `msstore` build never shows the updater (11.1) and omits the Inno-specific detection.

**Tests.** `tool/test/msix_version_test.dart` (version mapping), config-validation test (placeholders must be replaced before `--store` builds), hygiene test that the msstore build defines `TEPHRA_DIST=msstore`.

**Verify.** The test package installs and runs on this PC; WACK passes.

**Pitfalls.** The `publisher` string must match Partner Center **exactly** or the submission fails. Do not request `broadFileSystemAccess` (a restricted capability that needs a special justification) unless a real test shows normal file access is blocked.

### 11.7 — Store listing, certification and submission

**Purpose.** Publish on the Microsoft Store.

**Files.** `docs/release/msstore-listing.md`, `docs/release/msstore-log.md`.

**Implementation.** (1) Partner Center → the reserved app → **Submission**: *Pricing and availability* (free, all markets the human picks); *Properties* (category Productivity, privacy-policy URL, website, support contact; system requirements: Windows 10 1809+ x64, 4 GB RAM recommended); *Age ratings* (questionnaire: no violence/gambling; user-generated content: none shared); *Packages* (upload the `.msix`); *Store listings* (English): name, description (reuse the Play description, adapted), "What's new", search terms (markdown, notes, obsidian, knowledge base), **screenshots 1366×768 or larger** (at least 1, up to 10; real app, light/dark), optional logo assets (1:1 `1080×1080` box art, `720×1080` poster), trailer optional; *Notes for certification* (how to test: no account needed; optional Tephra Cloud test account credentials; All-files not required on Windows). (2) Submit; certification takes up to a few business days; fix feedback; publish. (3) Subsequent versions: new `.msix` with a higher version, same process. Record in `msstore-log.md`.

**Verify / Gate B.** See Exit gates.

**Pitfalls.** The first certification often fails on assets/metadata, not code — read the report. Store builds cannot self-update: remind testers that updates arrive through the Store.

---
## Item C — Real-time collaboration: design spike (no feature ships)

> **Why only a spike:** Tephra's sync is end-to-end encrypted and the server is blind. Real-time editing of shared vaults needs (1) a text CRDT that merges live keystrokes **and** edits made by other apps to the same file, (2) a way to share a vault key with another user without the server learning it, (3) a presence/transport protocol over Tephra Cloud. Getting (1) or (2) wrong corrupts notes or breaks the privacy promise, so this phase produces evidence and a signed-off design; implementation is a later phase.

### 11.8 — Criteria and candidate survey

**Purpose.** Choose the CRDT approach on written criteria, not taste.

**Files.** `docs/spikes/crdt/criteria.md`, `docs/spikes/crdt/candidates.md`.

**Implementation.**
1. `criteria.md` — a scored table (weights in brackets, total 100) the decision must fill in: **licence permissive and compatible with closed source** [gate: fail = out]; **runs on Android + Windows (+ later iOS/macOS/Linux) without a native toolchain we cannot ship** [15]; **pure Dart or small FFI** [10]; **plain-text/sequence semantics with no character interleaving of concurrent word insertions** (YATA/RGA-class guarantee) [15]; **delete/undo behaviour and tombstone growth** (can history be compacted; size after 1 M operations) [10]; **update size and encode/decode speed** (target: 100k-character document, applying 10,000 remote operations < 200 ms; average update for a typed character < 100 bytes before encryption) [10]; **offline editing and merge with long divergence** [10]; **integration with plain `.md` files** — a document is the file's text; external edits (Obsidian, git) must be absorbable as operations [15]; **maintenance/maturity/community** [5]; **encryption friendliness** — updates are opaque, order-independent messages we can wrap in `TPH1` envelopes (a new object purpose) [5]; **testability** (deterministic, property-testable) [5].
2. `candidates.md` — evaluate each candidate against the table **with evidence** (read the repository, README, licence file; link versions and dates): (a) **own pure-Dart sequence CRDT in the RGA/YATA family** (character-run IDs `(client, clock)`, origin-left/origin-right integration like Yjs YATA, tombstones with run-length encoding); (b) **Yjs** (MIT) run inside QuickJS (shared with item E's runtime) or through a Dart port — search pub.dev/GitHub for ports (`yjs`, `y_crdt`, `ydart`; record licence, completeness, last release; **do not trust a port's claims — run its tests**); (c) **Automerge** (MIT; Rust core, `automerge-dart`/FFI) — native build per platform, heavy; (d) **Loro** (MIT; Rust, text/rich-text/tree CRDT) via FFI or `flutter_rust_bridge` (Apache-2.0/MIT) — modern and fast, but a Rust toolchain in every build; (e) operation-based **LSEQ/Logoot** or **Treedoc** variants (for contrast; position identifiers grow); (f) existing Dart `crdt` packages (map/LWW CRDTs — expected **not suitable** for text; record why). For each: licence, platforms, size in the APK (measure if feasible), API fit, and an honest risk list.
3. **Recommendation to test (not a decision yet):** (a) own pure-Dart YATA-style CRDT, because it has no native dependency, is property-testable, is ~1–2k lines, and the file-integration problem (external edits → ops by diffing) needs custom logic with any candidate. The spike must try to **falsify** this: if the prototype fails the benchmarks or interleaving tests, say so and re-score (b) or (d).

**Tests / Verify.** Documents complete with sources; every licence checked.

**Pitfalls.** A candidate whose licence is GPL/AGPL/SSPL/BUSL or unclear is out regardless of quality.

### 11.9 — Prototype and benchmarks (throw-away package, reusable code)

**Purpose.** Prove or falsify the recommendation with running code.

**Files.** `docs/spikes/crdt/crdt_spike/` (a standalone Dart package **outside** the workspace; own `pubspec.yaml` with `resolution` not set, no dependencies except `test`): `lib/src/id.dart`, `item.dart`, `doc.dart` (insert/delete/apply/merge), `update.dart` (binary encode/decode, varints), `diff_to_ops.dart` (external text change → ops), `lib/crdt_spike.dart`, `test/`, `bench/`, `docs/spikes/crdt/results.md`.

**Implementation.**
1. **Data model (specification for the prototype):** `Id(client: int32, clock: int)`; each inserted **run** `Item{id, originLeft?, originRight?, length, text, deleted}`; document = linked list integrated with the YATA rule (find insertion point between `originLeft` and `originRight`, ordering conflicts by `(client id)` among items sharing the same origins); deletes are tombstones (`deleted = true`, length kept) recorded in a delete set per client as clock ranges; local `insert(index, text)` / `delete(index, length)`; `apply(Update)` is idempotent and order-tolerant (items whose origins are missing are buffered until they arrive); `stateVector()` + `diff(remoteVector)` produce minimal updates; `toString()` joins non-deleted text. Updates are length-prefixed binary (varint client/clock/length, UTF-16-safe text, delete ranges) — **opaque bytes** suitable for later encryption.
2. **Property tests** (seeded; print the seed on failure — conventions §8): 3 and 5 replicas, 10,000 random ops (insert/delete at random indices, random offline periods, random delivery order, duplicates, drops-then-resend): **all replicas converge to identical text**; **intention preservation:** concurrent insertions of whole words at the same position by two sites never interleave characters (`"hello"` and `"world"` at index 0 give either `helloworld` or `worldhello` — never mixed); a delete never removes concurrently inserted text inside the deleted range; `apply` of the same update twice is a no-op; updates generated by `diff` from any state vector bring a fresh replica to the same document; Unicode: surrogate pairs and combining characters are never split by an operation boundary created through the public API (indices are in UTF-16 code units; the API rejects splitting a surrogate pair).
3. **Benchmarks** (`bench/`, `dart run --release`; record median of 5 runs on this PC and, via a Flutter integration run or `dart compile exe` on the phone through `adb shell` if feasible, on the Android phone): (a) typing 100,000 characters sequentially, then 10,000 random edits: time and memory (RSS); (b) applying 10,000 remote single-character ops to a 100k-character doc (target < 200 ms); (c) encode/decode of a full-state update for 100k characters and for a 1 MB document (size and time); (d) tombstone growth: 1 M random insert/delete operations → in-memory items and encoded size; (e) the cost of `diff_to_ops` for a 5,000-line note where a script changed 200 lines.
4. **External-edit absorption:** `diff_to_ops(oldText, newText, siteId)` converts a whole-file change (made by another app) into delete+insert runs using a line-oriented diff followed by a character diff inside changed lines (reuse the Phase 3 `lineHunks` idea; **write the code in the spike**, do not import `tephra_sync`); property test: `apply(diff_to_ops(a, b)) == b` for 2,000 random pairs, and a **merge scenario** test: replica R1 types concurrently while an "external edit" is absorbed on R2 → both converge and neither side's edit is lost except where both edited the same characters (document that case).
5. `results.md`: tables of all numbers against the targets, the interleaving/convergence results, memory per 100k characters, update sizes, known weaknesses (tombstone GC needs peer acknowledgements; undo/redo semantics; attribution), and the **revised scores** in `criteria.md`.

**Tests.** The spike's own tests (the property tests are the deliverable).

**Verify.** `cd docs/spikes/crdt/crdt_spike; dart test; dart run --release bench/run.dart`.

**Pitfalls.** Do not optimise before the convergence tests are green. Do not import app/package code (keeps the spike self-contained and licence-clean).

### 11.10 — Design document: keys, protocol, file integration, rollout plan

**Purpose.** The artifact the human signs off before any implementation.

**Files.** `docs/spikes/crdt/design.md`, `docs/decisions/collaboration.md` (the decision record).

**Implementation.** `design.md` answers each of these with a concrete proposal **and the alternatives rejected**:
1. **Model:** a *shared vault* = a Tephra Cloud vault with multiple **members** (owner, editors; viewers later); one document = one `.md` file; the CRDT state of a note lives **next to the sync data** as encrypted objects, never in the Markdown file; the `.md` file on every device remains the interoperable source of truth (Obsidian compatibility is the product): after each remote op batch the app writes the merged text to the file with the normal atomic write.
2. **Key sharing without trusting the server:** each account has an **identity key pair** (X25519 + Ed25519 signing, generated on the device, private part in secure storage, **public part registered with the account**, verified by a visible **safety number** — hash of both public keys shown as 6 groups of 5 digits — that members compare out of band); inviting = the owner's app wraps the vault master key to the invitee's public key (**sealed box**, the same construction as the clipper inbox, item D) and uploads it as a member record; the server stores only wrapped keys and membership. Key rotation on member removal (new master key epoch; re-encrypting future objects; old objects remain readable to removed members — state this limitation plainly). Evaluate and write down why **MLS** (RFC 9420) is out of scope for v1 of collaboration.
3. **Transport:** per-document WebSocket channel on Tephra Cloud (`/v1/vaults/{id}/collab/{docId}`), encrypted CRDT updates wrapped in `TPH1` envelopes with a **new object purpose** (code 8, `tephra/v1/crdt`, frozen after approval — needs a `formatVersion`-compatible addition: unknown purposes are rejected by old readers, so collaborative notes require an updated app; spell out the compatibility story), presence/cursors as ephemeral encrypted messages, server-side **append log with compaction snapshots** (opaque), server enforces membership and size limits only.
4. **Persistence and sync interplay:** how the CRDT log coexists with the Phase 3 journals (the journal entry for the `.md` file still records the resulting hash; the CRDT state is an optimisation/transport; a device without collaboration support still syncs the `.md` file as today and **cannot** corrupt the CRDT state because the next op batch re-bases through `diff_to_ops`). Conflict semantics when someone edits the file with Obsidian while a collaborative session is open.
5. **Scope limits for v1 collaboration:** text notes only (`.md`), no canvas/base/attachment co-editing, max 10 concurrent editors per document, max 2 MB per document, no offline-only invitations.
6. **Security/abuse review** (threat table: malicious member, server compromise, replay, op-flood, key theft), **privacy** (metadata the server sees: members, document ids, op timing/size), **legal** (terms for shared vaults: who owns content, removal).
7. **Rollout plan:** phases with their own gates (CRDT package + file integration behind a flag → shared-vault server API + invites → UI → beta), effort estimate in weeks, and the list of unresolved questions.
8. `docs/decisions/collaboration.md`: the **decision** (recommended: own pure-Dart YATA-style CRDT, scored table, benchmark numbers), the conditions under which it must be revisited, the human's approval line `APPROVED <date> <name>`.

**Tests / Verify.** Documents complete; every claim in `design.md` about the prototype cites `results.md`.

**Pitfalls.** Do not start implementing the feature in the app in this phase. The signed decision, not the prototype, is the deliverable.

---

## Item D — Web clipper (Chrome/Edge MV3) with end-to-end-encrypted inbox

### 11.11 — Inbox on Tephra Cloud (server + sealed-box crypto + app consumer)

**Purpose.** Let a browser extension, which never holds the vault's keys, drop a clip that only the user's devices can read.

**Files.** Server: `server/lib/src/db/migrations/m004_inbox.dart`, `server/lib/src/api/inbox_routes.dart`, `server/lib/src/services/inbox_service.dart`, `server/lib/src/jobs/inbox_purge_job.dart`, `docs/decisions/cloud-api-v1.md` (additive section), tests `server/test/api/inbox_routes_test.dart`. Package `tephra_sync`: `lib/src/cloud/inbox_models.dart`, `lib/src/crypto/inbox_seal.dart`, `lib/src/crypto/inbox_keys.dart`, tests. App: `app/lib/capture/clip/` (`inbox_consumer.dart`, `clip_writer.dart`, `clip_payload.dart`, `providers.dart`, settings "Web clipper" page), tests.

**Implementation.**
1. **Crypto (frozen once released; test vectors in `docs/decisions/inbox-crypto-vectors.json`):**
   - **Inbox key pair per vault, derived from the vault master key:** `seed = HKDF-SHA256(ikm = masterKey, salt = UTF-8(remoteVaultId), info = UTF-8("tephra/v1/inbox-key"), L = 32)`; `X25519().newKeyPairFromSeed(seed)`; `keyId` = first 8 bytes (hex) of SHA-256(public key). Every device that has the vault derives the **same** key pair — no new remote objects, no change to `sync-format-v1`.
   - **Seal (sender = extension, anonymous):** generate an ephemeral X25519 pair; `shared = X25519(ephPriv, recipientPub)`; `key = HKDF-SHA256(ikm = shared, salt = ephPub ‖ recipientPub, info = "tephra/v1/inbox-seal", L = 32)`; AES-256-GCM with a random 12-byte nonce; **AAD** = UTF-8 `tephra-inbox-v1|<vaultId>|<keyId>`. Envelope JSON: `{"v":1,"keyId":"<hex16>","epk":"<base64 32>","nonce":"<base64 12>","ct":"<base64 ciphertext‖16-byte tag>"}`. Plaintext = UTF-8 JSON payload `{"v":1,"clipId":"<uuid>","title":"…","url":"https://…","markdown":"…","clippedAt":"<ISO>","author":"…"?,"siteName":"…"?,"tags":["…"]?}`, ≤ 200 KiB.
   - `inbox_seal.dart`: `Future<Map<String,Object?>> seal(...)` and `open(...)` (the app only needs `open`, the server tests and Dart-side test vectors need `seal`); wrong key/AAD/tampered → `TamperedDataException`.
2. **Server API (additive, `/v1`; migration `m004`: `inbox_keys(vault_id PK → vaults, key_id TEXT, public_key TEXT, updated_at)`, `inbox_items(id TEXT PK, vault_id, user_id, created_at, size, storage_ref)`; items stored through `BlobStorage`):**
   | Method + path | Request | Response |
   |---|---|---|
   | `PUT /v1/vaults/{id}/inbox-key` | `{"keyId":"<hex16>","publicKey":"<base64 32>"}` | `204` (any device of the vault; replaces) |
   | `GET /v1/vaults/{id}/inbox-key` | — | `200 {"keyId","publicKey"}` or `404 not_found` |
   | `POST /v1/vaults/{id}/inbox` | the envelope JSON (`Content-Type: application/json`, ≤ 262,144 bytes) | `201 {"id","createdAt"}`; `413 too_large`; `409 conflict` with code `inbox_full` when the vault has ≥ 200 items or ≥ 50 MiB; `404` when no inbox key is registered (`inbox_not_enabled`) |
   | `GET /v1/vaults/{id}/inbox?limit=100` | — | `200 {"items":[{"id","createdAt","size"}]}` |
   | `GET /v1/vaults/{id}/inbox/{itemId}` | — | `200` the envelope JSON |
   | `DELETE /v1/vaults/{id}/inbox/{itemId}` | — | `204` |
   WebSocket `…/events` gains the frame `{"type":"inbox","count":3}` (sent when an item is added; additive). Items expire after **30 days** (`inbox_purge` job, hourly). Server validation: JSON shape and field lengths only (`keyId` must equal the registered key's id → else `400 bad_request`); it **cannot** read the payload. New rate-limit family `inbox_user` (30 per minute). Inbox items count toward the vault's `used_bytes` while stored. Device name for the extension is "Web clipper" (a normal session: one more device against `maxDevices` — document; the plan's device limit may need `+1` for the clipper: count sessions whose `platform = 'other'` and `device_name = 'Web clipper'` separately, cap 2).
3. **App consumer (`InboxConsumer`, in the sync worker so it works in the background):** on enabling Settings → **Web clipper** (new page: toggle, "Register this vault for clipping", the **inbox address** explanation, list of recent clips, "Disconnect"), derive the key pair and `PUT inbox-key`. Triggers: WS `inbox` frame, app start/resume, every 5 minutes while foreground, manual "Check now". For each item: `GET`, `open` with the derived private key (held only in memory; never stored) → validate payload (`v == 1`, sizes, URL scheme `http`/`https` only, `markdown` ≤ 200 KiB, title ≤ 200 chars after trimming, control characters stripped) → `ClipWriter` writes `Clippings/<name>.md` (the folder is created if missing; **setting** "Clipping folder" default `Clippings`): file name = sanitised title (`WindowsNames.sanitize`, ≤ 80 chars, fallback `Clip <yyyy-MM-dd HH-mm>`), on collision ` (2)`, ` (3)`; **deterministic content** so two devices consuming the same item produce **byte-identical** files (rule zero then avoids a conflict): frontmatter via the `yaml` writer with keys `title`, `source`, `author` (if any), `clipped` (from `clippedAt`), `tags: [clippings, …]`, then a blank line and the Markdown; write with the atomic `VaultFileSystem.writeText`; **then** `DELETE` the inbox item. Idempotency: a local file `<appSupportDir>/clips/<vaultId>.seen.json` keeps the last 500 processed item ids and `clipId`s; a crash between write and delete is harmless. An item that fails validation or decryption is **left on the server** and reported in the page ("1 clip could not be read") and deleted after 7 days by the user or the TTL. Never executes HTML; Markdown is plain text.
4. l10n keys `clipperTitle`, `clipperEnable`, `clipperRegistered`, `clipperRecent`, `clipperUnreadable`, `clipperFolder`, `clipperDisconnect`, `clipSavedNotice` (`{title}`).

**Tests.** Crypto vectors: Dart `seal` → Dart `open` round trip, wrong AAD/keyId/vault id fails, 1-byte tamper fails, the same seed gives the same key pair on two "devices", a **frozen vector** (fixed ephemeral key and nonce → exact JSON) asserted forever; server integration tests for every endpoint and limit (inbox full, oversize, wrong `keyId`, foreign vault → 404, TTL purge with the fake clock, WS frame); consumer tests with `MemoryVaultFileSystem` and a fake client: happy path, filename sanitising and collisions, two consumers produce identical bytes, crash between write and delete, invalid payloads (javascript: URL, oversize, bad JSON) are not written, markdown containing `---` frontmatter-lookalikes is safe (the clip body is placed after our own frontmatter; assert Obsidian-style parse yields exactly our keys).

**Verify.** `dart test` in `server/` and `tephra_sync`; `flutter test test/capture`. Manual: register a vault on the PC, `curl` a sealed test envelope (generated by a Dart script in `tool/`) to staging, watch the file appear on both devices and sync.

**Pitfalls.** The server must never learn the payload — do not add "preview" fields. The derived private key must not be stored or logged. Re-registering the key (`PUT inbox-key`) after the vault password changes is unnecessary (the master key does not change).

### 11.12 — The browser extension (Manifest V3)

**Purpose.** One-click "clip page / selection" to the user's vault.

**Files.** `clipper/` (repo root, **not** a Dart package): `manifest.json`, `src/background.js`, `src/popup.html`, `src/popup.js`, `src/content_extract.js`, `src/convert.js` (Readability + Turndown), `src/seal.js` (WebCrypto sealed box), `src/api.js` (auth + inbox calls), `src/storage.js`, `src/options.html/js`, `build.mjs` (esbuild), `package.json`, `package-lock.json`, `THIRD_PARTY.md`, `test/*.test.mjs`, `test/fixtures/*.html`, `README.md`.

**Implementation.**
1. **Manifest:** `"manifest_version": 3`, `"minimum_chrome_version": "133"` (WebCrypto **X25519** support; verify against https://developer.mozilla.org/docs/Web/API/SubtleCrypto and Chrome release notes — if the Edge version lags, document), `"permissions": ["activeTab","scripting","storage","contextMenus"]`, `"optional_host_permissions": ["https://*/*"]` (requested at runtime for the chosen **server origin only**; the extension never gets blanket host access), `"action": {"default_popup": "popup.html"}`, `"background": {"service_worker": "background.js", "type": "module"}`, a content-security-policy without remote code (MV3 default). **Do not** use `<all_urls>` content scripts: extraction runs via `chrome.scripting.executeScript` on the active tab on user click (`activeTab`).
2. **Popup flow:** first run: server address (default from the build-time constant; must be `https`), email, password → `POST /v1/auth/login` (`deviceId` = a UUID generated once and stored, `deviceName: "Web clipper"`, `platform: "other"`) → tokens stored: **access token in `chrome.storage.session`**, **refresh token in `chrome.storage.local`** (browser storage is not encrypted at rest — state this in the options page and README; "Sign out" deletes it); automatic refresh on 401 with the Phase 10 rules (single-flight; the 30-s server grace covers popup/service-worker races). Then a vault dropdown (`GET /v1/vaults`, only vaults whose `GET …/inbox-key` returns 200, others greyed with "Enable Web clipper in the Tephra app"), tag field, buttons **Clip page**, **Clip selection**, and a status line. Context-menu entry "Clip selection to Tephra".
3. **Extraction and conversion:** inject `content_extract.js`: for *page* run `new Readability(document.cloneNode(true)).parse()` (title, byline, content HTML, siteName); for *selection* take `window.getSelection().getRangeAt(…).cloneContents()` serialised to HTML; resolve every `href`/`src` to an **absolute URL**; send `{title,url,html,byline,siteName,clippedAt}` to the popup. `convert.js`: Turndown with `headingStyle: 'atx'`, `codeBlockStyle: 'fenced'`, `bulletListMarker: '-'`, `turndown-plugin-gfm` (tables, strikethrough, task lists); rules: drop `script/style/iframe/form/svg`, keep images as `![alt](absolute-url)`, keep links, `<mark>` → `==text==`; output size cap **200 KiB** (truncate at a block boundary and append `\n\n> [!note] Clip truncated`); no images are downloaded in v1. Build the payload of 11.11 (`clipId` = `crypto.randomUUID()`).
4. **Seal in the browser (`seal.js`):** `crypto.subtle.generateKey({name:'X25519'}, true, ['deriveBits'])`, import the recipient public key (`importKey('raw', pub, {name:'X25519'}, false, [])`), `deriveBits({name:'X25519', public: recipientKey}, ephPriv, 256)`, HKDF (`{name:'HKDF', hash:'SHA-256', salt: ephPub‖recipientPub, info: utf8('tephra/v1/inbox-seal')}` → AES-GCM 256 key), AES-GCM with the AAD of 11.11, output the envelope JSON. **Cross-language known-answer test:** `test/seal.test.mjs` loads `docs/decisions/inbox-crypto-vectors.json` (generated by the Dart implementation) and must `open` (via a JS re-implementation of the opener used only in tests) and **produce the same envelope** for the vector's fixed ephemeral key and nonce (inject them through a test-only parameter).
5. `POST /v1/vaults/{id}/inbox` with the envelope; show success ("Saved to <vault>"; the app writes it when it next syncs/checks) or the error text (`inbox_full`, `inbox_not_enabled` → "Open Tephra, Settings → Web clipper → Enable", `rate_limited`, offline). **Offline/not signed in fallback:** button "Send to the Tephra app instead" → builds the `tephra://clip` URL of 11.13 (only if the converted Markdown ≤ 24,000 characters; otherwise explains and offers to copy the Markdown to the clipboard).
6. **Build:** `npm ci && npm run build` (esbuild bundles to `dist/`), `npm run pack` zips `dist/` as `tephra-clipper-<version>.zip` (version from `manifest.json`, kept equal to the app's semver by `tool/test`); `THIRD_PARTY.md` lists Readability (Apache-2.0), Turndown (MIT), turndown-plugin-gfm (MIT), esbuild (dev, MIT) with licence texts; add them to the app's notices page too (the extension is part of the product). `package-lock.json` is committed; `npm audit --omit=dev` must report no high/critical issues (record the result).
7. Load unpacked: Chrome `chrome://extensions` → Developer mode → **Load unpacked** → `clipper/dist`; Edge `edge://extensions` likewise. Optional store publishing (HD): Chrome Web Store and Edge Add-ons listings need a privacy statement (reuse the app policy + a section "the extension sends clips only to the Tephra server you configure, encrypted"), screenshots 1280×800, small tile 440×280; **a store extension must not load remote code** (we don't).

**Tests.** `node --test clipper/test/` (CI ubuntu has Node): conversion fixtures — 10 saved HTML pages (news article, blog with code blocks, table-heavy docs page, GitHub README, Wikipedia article, page with relative links/images, page with `<mark>`, page with scripts/iframes, tiny page, non-English page) → Markdown **snapshot** files reviewed once by a human, then frozen; absolute-URL resolution; size cap and truncation notice; `seal.test.mjs` known-answer test; API client tests with a fake `fetch` (login, refresh single-flight, 401 → refresh → retry, error mapping); no network access in tests.

**Verify.** Build and load unpacked in Chrome and Edge; clip a real article on the PC; the note appears in `Clippings/` on the PC and the phone with correct frontmatter, readable Markdown, and syncs.

**Pitfalls.** WebCrypto X25519 is new — verify availability in the installed browsers before coding; if unavailable, **stop** and ask (fallback: ship `@noble/curves` (MIT) bundled — only with the human's OK, as it adds a dependency). Never store the password. Never request broader host permissions than the chosen server.

### 11.13 — `tephra://clip` handler (desktop and Android), installer registration, confirmation UX

**Purpose.** A no-account fallback and a "send to desktop app" path.

**Files.** `app/lib/capture/clip/clip_link_handler.dart`, `clip_confirm_dialog.dart`, `app/lib/core/deep_links.dart`, `app/android/app/src/main/AndroidManifest.xml` (intent filter), `app/windows/runner/main.cc` (single-instance forwarding, per the `app_links` README), `installer/tephra.iss` (edit), `app/pubspec.yaml` (`msix_config.protocol_activation: tephra`, item B), tests.

**Implementation.**
1. `flutter pub add app_links` (Apache-2.0, verified; custom schemes work on Windows); follow its README exactly for Windows single-instance forwarding (the second launch started by the protocol must pass the URL to the running instance and exit).
2. **URL format:** `tephra://clip?v=1&title=<percent-encoded>&url=<percent-encoded>&md=<base64url(UTF-8 markdown)>[&tags=a,b]`, total length ≤ 24,000 characters (below the Windows command-line limit with margin). Strict parser: unknown `v` → ignore; any parse error → a harmless "Invalid link" notice; no other `tephra://` host is accepted yet.
3. **Security rule — always confirm:** any web page or app can open a `tephra://` link, so the handler **never writes silently**: it shows `ClipConfirmDialog` (title, source URL, first 600 characters of the Markdown, a **vault chooser** defaulting to the last used, the target `Clippings/` folder, buttons "Save" and "Discard"), enforces a **64 KiB** limit after decoding, strips control characters, writes only through `ClipWriter` (11.11: sanitised name, no overwrite, deterministic content), and rate-limits to 1 prompt per 3 seconds (extra links are queued up to 5, then dropped). It works with no account at all.
4. **Windows registration:** `installer/tephra.iss` `[Registry]`:
   ```
   Root: HKA; Subkey: "Software\Classes\tephra"; ValueType: string; ValueName: ""; ValueData: "URL:Tephra Protocol"; Flags: uninsdeletekey
   Root: HKA; Subkey: "Software\Classes\tephra"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
   Root: HKA; Subkey: "Software\Classes\tephra\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\tephra.exe"" ""%1"""
   ```
   (`HKA` = HKCU for per-user installs and HKLM for all-users installs, matching the Phase 9 installer; add `ChangesAssociations=yes` in `[Setup]`.) The Store build declares the protocol through `msix_config` (item B); the portable zip does not register it (document). **Android:** inside the main activity add
   `<intent-filter><action android:name="android.intent.action.VIEW"/><category android:name="android.intent.category.DEFAULT"/><category android:name="android.intent.category.BROWSABLE"/><data android:scheme="tephra" android:host="clip"/></intent-filter>` (the activity is already exported for launcher/share).
5. The extension (11.12) uses the link on desktop via `chrome.tabs.update`/`window.location` to `tephra://clip…`; Chrome shows its own "Open Tephra?" prompt (once per origin, the user may tick "always allow" — acceptable because the app still confirms every clip).

**Tests.** Parser table tests (valid, oversized, wrong version, bad base64, control characters, extra hosts); dialog widget tests (both widths: nothing written until Save; Discard writes nothing; queue limit); writer collision tests; Windows installer registry lines checked by a `tool/test` text assertion; manual: click a prepared link in the browser on Windows and Android → prompt → saved.

**Verify.** Manual on both platforms; confirm that a malicious page link (`md` with `---` YAML tricks, a 100 KB payload, `title` with `../`) cannot write outside `Clippings/` or without the dialog.

**Pitfalls.** Do not accept `file`, `javascript` or path parameters. Do not auto-open the app window to the front for each queued link. Do not log the Markdown.

---

## Item E — Sandboxed plugin API (QuickJS)

### 11.14 — Runtime spike: choose the JS engine and the isolation model

**Purpose.** Pick the runtime on evidence; the rest of the item depends on it.

**Files.** `docs/spikes/plugins/runtime.md`, `docs/spikes/plugins/spike_app/` (throw-away Flutter app, Android + Windows), `docs/decisions/plugin-runtime.md`.

**Implementation.**
1. **Candidates (check licence, maintenance, QuickJS version, platforms — record with links and dates):** (a) `flutter_js` 0.8.7 (MIT; QuickJS on Android/Windows/Linux, JavaScriptCore on iOS/macOS) — find **which QuickJS version it bundles** (older versions have known CVEs; compare against QuickJS's changelog and the NVD/OSV advisories) and which engine controls it exposes; (b) `flutter_qjs` (check licence — historically ISC — and last release); (c) `fjs`/other Rust-based QuickJS wrappers (check licences of the Rust crates too); (d) **our own thin FFI plugin `app/plugins/tephra_quickjs`** compiling a current **QuickJS** (Fabrice Bellard's `quickjs`, MIT, or the maintained fork `quickjs-ng`, MIT) with CMake for Android (NDK) and Windows (MSVC), exposing exactly the calls we need — most control (`JS_SetMemoryLimit`, `JS_SetMaxStackSize`, `JS_SetInterruptHandler`), most work. Out of scope: V8 (large), Hermes (build complexity), WebView JS (no isolation guarantees).
2. **Spike tasks (measure, do not assume):** run "hello world", a Promise chain, `JSON`, `Intl` availability, a 50k-iteration loop timing, **an infinite loop** (can the host interrupt it?), **a memory bomb** (`new Array(1e9)` / string doubling — can a limit be set and does the host survive?), deep recursion, calling a Dart function from JS and getting an async result back (bridge round trip µs), startup time of a fresh runtime, APK size delta per ABI and Windows size delta, behaviour under R8 and in a `--release --obfuscate` build, and on the 4 GB phone.
3. **Isolation model to validate (recommended):** each **plugin runs in its own Dart isolate** with its own JS runtime; the main isolate talks to it by messages only; a watchdog in the main isolate **kills the isolate** (`Isolate.kill(priority: Isolate.immediate)`) when a call exceeds its time limit — this works with **any** engine, even one without an interrupt handler; memory limits require engine support (`JS_SetMemoryLimit`) — if the chosen engine has none, the limit is **not enforceable** and the document must say so (and plugin installation shows that plugins can use memory/CPU within the watchdog limits).
4. `plugin-runtime.md` decision: engine, version pinned, isolation model, which limits are **hard** (enforced: wall-clock per call, call rate, payload sizes, API surface) and which are **best-effort** (memory), how the engine is updated when advisories appear, licence notes. Human approval line required before 11.15 starts.

**Tests / Verify.** The spike app results are tabulated in `runtime.md`; the decision cites them.

**Pitfalls.** An engine that cannot be interrupted is acceptable **only** with the kill-isolate watchdog. An unmaintained QuickJS fork with known CVEs is not acceptable for running third-party code — then choose (d).

### 11.15 — Plugin manifest, permission model, API surface (specification)

**Purpose.** Freeze the contract **before** implementing it.

**Files.** `docs/plugins/PLUGIN_API.md` (the spec, also copied into the user guide later), `docs/plugins/plugin.schema.json`, `docs/decisions/plugin-api-v1.md`.

**Implementation.**
1. **Package format:** a `.tephraplugin` file = a ZIP (forward-slash entries, ≤ 2 MiB, ≤ 200 files, no entry path containing `..`, absolute paths or drive letters) containing `plugin.json`, `main.js` (single ES2020 script file, **no modules/imports** in v1; bundlers allowed), optional `assets/` (read-only files readable by the plugin through `tephra.assets.read`), `LICENSE`.
2. **`plugin.json`** (exact fields; unknown fields rejected):
   ```json
   {
     "manifestVersion": 1,
     "id": "com.example.wordcount",
     "name": "Word Count",
     "version": "1.0.0",
     "author": "Example Dev",
     "description": "Counts words in the current note.",
     "apiVersion": 1,
     "minTephraVersion": "2.2.0",
     "main": "main.js",
     "permissions": ["editor.read", "ui.notice"],
     "network": { "hosts": [] },
     "vaultScopes": { "read": [], "write": [] },
     "commands": [
       { "id": "count", "title": "Count words in this note", "icon": "calculate", "hotkey": "Ctrl+Alt+W", "palette": true, "mobileToolbar": false }
     ],
     "events": ["note.saved"],
     "settings": [
       { "key": "countCode", "type": "boolean", "title": "Count code blocks", "default": false }
     ]
   }
   ```
   `id` = reverse-DNS, lower-case `[a-z0-9.-]`, 3–100 chars; `version` semver; `apiVersion` = the API the plugin targets (the host supports `1`); setting types `boolean|string|number|choice`; every command gets a registry command `plugin.<id>.<commandId>` (conventions §7.8).
3. **Permissions (all explicit, shown to the user at install, individually revocable later):**
   | Permission | Grants | Notes |
   |---|---|---|
   | `vault.read` | `tephra.vault.read/list/exists/stat` | limited to `vaultScopes.read` folders (empty = whole vault); `.obsidian/`, `.tephra/`, `.trash/`, hidden paths **never** readable |
   | `vault.write` | `create/write/rename/delete` (delete = vault trash) | limited to `vaultScopes.write`; max 5 MiB per file; every write goes through the normal atomic path and local history snapshot |
   | `vault.metadata` | `tephra.notes.parse/backlinks/search/resolveLink/tags` | read-only index queries |
   | `editor.read` | `tephra.editor.getText/getSelection/getCursor/activeNote` | |
   | `editor.edit` | `replaceSelection/insertAtCursor/replaceRange` | undoable as one editor transaction |
   | `ui.notice` | `tephra.ui.notice` | |
   | `ui.modal` | `prompt/confirm/choose` | host-drawn dialogs only (no custom widgets) |
   | `storage` | `tephra.storage.get/set/remove/keys` | per-plugin key-value, ≤ 1 MiB total |
   | `network` | `tephra.http.fetch` | **https only**, hosts must be listed in `network.hosts` (exact host match), no redirects to unlisted hosts, ≤ 5 MiB response, 20 requests/minute/host |
   | `clipboard.write` | `tephra.clipboard.writeText` | user-gesture commands only |
   | `events` | `tephra.events.on` for the events listed in the manifest | `note.opened`, `note.saved`, `note.created`, `note.deleted`, `vault.synced` |
   Never grantable: filesystem outside the vault, processes, environment, secrets/keys/tokens, sync internals, other plugins, platform channels, arbitrary Dart calls, `eval` of host strings. Calls without permission throw `TephraPermissionError` (a JS `Error` subclass) and are counted; 5 violations disable the plugin and notify the user.
4. **JS API v1** (all functions return Promises; arguments/results are JSON-serialisable; the global is `tephra`; there is **no** DOM, `require`, `process`, `fetch`, `XMLHttpRequest`, `setTimeout` (use `tephra.timer.sleep(ms)`), `eval` is allowed but sees only the sandbox):
   ```
   tephra.app.{version, apiVersion, platform}                         // strings/numbers, synchronous constants
   tephra.log.{info, warn, error}(...args)                             // to the plugin's log ring buffer (last 500 lines)
   tephra.vault.read(path) -> string                                    tephra.vault.exists(path) -> bool
   tephra.vault.list(folder?) -> [{path, isFolder, size, mtime}]        tephra.vault.stat(path) -> {size, mtime}|null
   tephra.vault.create(path, text) -> void   (fails if exists)          tephra.vault.write(path, text) -> void
   tephra.vault.rename(from, to) -> void                                tephra.vault.delete(path) -> void
   tephra.notes.activeNote() -> {path, title}|null                      tephra.notes.parse(text) -> {frontmatter, headings[], links[], tags[], tasks[]}
   tephra.notes.backlinks(path) -> [{source, line, context}]            tephra.notes.search(query, {limit}) -> [{path, matches[]}]
   tephra.notes.resolveLink(target, fromPath) -> path|null              tephra.notes.tags() -> [{tag, count}]
   tephra.editor.getText() -> string                                    tephra.editor.getSelection() -> {text, from, to}
   tephra.editor.getCursor() -> {line, ch}                              tephra.editor.replaceSelection(text) -> void
   tephra.editor.insertAtCursor(text) -> void                           tephra.editor.replaceRange(from, to, text) -> void
   tephra.commands.on(commandId, handler)                               // register the handler for a command declared in plugin.json
   tephra.events.on(eventName, handler)                                 // only for events declared in plugin.json
   tephra.ui.notice(message, {timeoutMs}) -> void                       tephra.ui.prompt({title, placeholder, defaultValue}) -> string|null
   tephra.ui.confirm({title, message}) -> bool                          tephra.ui.choose({title, items:[{id,label}]}) -> id|null
   tephra.storage.get(key) / set(key, json) / remove(key) / keys()      tephra.settings.get(key) -> value   // values from the manifest `settings`
   tephra.http.fetch(url, {method, headers, body}) -> {status, headers, text, json?}
   tephra.clipboard.writeText(text) -> void                             tephra.assets.read(path) -> string
   tephra.timer.sleep(ms) -> void   (≥ 100 ms, ≤ 10 s)
   ```
   Paths are vault-relative with `/`; the host normalises them with `VaultPath` and rejects anything escaping the vault or hitting forbidden folders.
5. **Limits (v1, constants in one file):** per command/event handler invocation **2 s** wall-clock (timers count) → the isolate is killed and restarted, strike counter +1; **3 strikes in 10 minutes disable the plugin**; plugin start-up (`main.js` evaluation) 1 s; host calls ≤ 200/s and ≤ 2,000 per invocation; payload per call ≤ 5 MiB; vault writes ≤ 50 per invocation; memory limit **64 MB if the chosen engine enforces it** (11.14) else best-effort; total plugin code ≤ 2 MiB; ≤ 20 plugins enabled at once; plugins never run while the app is locked (Phase 8 app lock) or when a vault is encrypted-locked.
6. **Lifecycle & storage:** plugins live in `<appSupportDir>/plugins/<id>/` (**device-local; never inside a vault, never synced** — otherwise sync would distribute code between devices without the user installing it); enabled state per device; **vault-level opt-in:** a plugin gets access only to vaults the user enabled it for. Updating a plugin re-asks for any **new** permission. Plugin settings values are stored in `<appSupportDir>/plugins/<id>/settings.json` (device-local).
7. **Trust model, written for users and developers:** plugins are **untrusted code with declared powers**; v1 distribution is **sideload only** (install from a `.tephraplugin` file the user chose); no store, no auto-update, no remote code loading enforced by the host except through `tephra.http.fetch` data (a plugin that `eval`s downloaded text is outside our control — the permission prompt for `network` says "can download data from <hosts>"); the manifest `author` is unauthenticated.
8. **Compatibility promise:** the API is versioned by `apiVersion`; additions are additive; removals only in a new `apiVersion` with a deprecation period of two minor releases.

**Tests.** A JSON-schema file validates `plugin.json`; valid/invalid fixtures (30 cases) live with the spec; the spec contains **no** TODO.

**Verify / human approval.** The human reads `PLUGIN_API.md` and writes `APPROVED <date>` in `docs/decisions/plugin-api-v1.md`; implementation starts only then.

**Pitfalls.** Do not add convenience APIs "while you're there" (rule 9 of GEMINI.md). Do not let plugins touch the sync folder `.tephra/`.

### 11.16 — Plugin host: runtime, bridge, permission enforcement, limits

**Purpose.** Implement the spec exactly.

**Files.** `app/lib/plugins/` — `plugin_manifest.dart`, `plugin_package.dart` (unzip + validation), `plugin_store.dart` (install/remove on disk), `plugin_host.dart`, `plugin_runtime_isolate.dart`, `plugin_bridge.dart`, `permission_gate.dart`, `plugin_api_handlers/` (one file per API group), `plugin_limits.dart`, `plugin_log.dart`, `providers.dart`; `app/assets/plugin/tephra_api.js` (the JS shim); if 11.14 chose (d): `app/plugins/tephra_quickjs/` (CMake, C wrapper, Dart FFI bindings); tests `app/test/plugins/*`, `app/test/plugins/fixtures/*.tephraplugin`.

**Implementation.**
1. **Package install:** read the zip with `package:archive` (already a transitive/dev dependency; add as app dependency if needed — MIT, re-check) **in an isolate**, enforce the format limits (size, entries, path rules → **zip-slip tests from 09.6 apply**), validate `plugin.json` against the schema, check `apiVersion`/`minTephraVersion`, show the permission list, then copy files to `<appSupportDir>/plugins/<id>/` atomically (temp folder + rename); reject duplicate ids unless upgrading (then keep settings, re-ask new permissions).
2. **Runtime isolate:** `Isolate.spawn(pluginIsolateMain, init)`; inside: create the engine runtime (per 11.14), evaluate `assets/plugin/tephra_api.js` (our shim defining `tephra.*` as thin wrappers over one native function `__tephraCall(name, argsJson) -> id`), then the plugin's `main.js`. **Bridge:** requests `{id, api, args}` go to the host (main isolate); responses `{id, ok, value|error}` come back and resolve/reject the JS Promise; the shim pumps the engine's pending-job queue after each resolution. Args/results are JSON text only (no object references cross the boundary). Handler registration (`tephra.commands.on`, `tephra.events.on`) stores callbacks inside the JS runtime; the host triggers them with `{type:'invoke', handlerId, payload}`.
3. **`PermissionGate`:** a single function `allow(pluginId, api, args)` consulted for **every** bridge call: permission present, scopes (`vaultScopes` prefix match after normalisation, forbidden folders), network host exact match, rate limits, payload sizes, write quota; denial → `TephraPermissionError` to the plugin + counter. The gate and the handlers are **pure Dart with injected services** (vault FS, index, editor controller, UI service, HTTP client) so tests need no Flutter.
4. **Watchdog:** every invocation (start-up, command, event) has a deadline (2 s / 1 s start-up); on expiry the host kills the isolate, marks the call `timeout`, increments strikes, restarts lazily on the next invocation; 3 strikes/10 min → plugin disabled with a notification. Calls that are waiting on a **user dialog** (`ui.prompt/confirm/choose`) pause the deadline (the user's time is not CPU time) up to 5 minutes.
5. **Editor/UI integration:** commands register in the Phase 1 command registry as `plugin.<id>.<command>` with the manifest title/icon/hotkey (conflicts with existing hotkeys are shown in settings, not silently overridden); `editor.*` handlers operate on the active editor controller through its transaction API (one undo step per plugin call group); `ui.*` uses host dialogs/snackbars; `notes.*` use `NoteIndex`/`MarkdownParser`; `vault.*` use the session `VaultFileSystem` (writes also trigger the usual `onChange` so index/sync see them).
6. **Disabled contexts:** no plugin runs on web builds; no plugin invocation while the app is locked; per-vault enablement checked before each call.
7. Logging: `Logger('plugin.<id>')` (info for lifecycle, fine for calls); **plugin log lines are stored in the ring buffer and shown in the manager, never forwarded to Sentry**; never log vault contents.

**Tests.** Unit tests of `PermissionGate` for every row of the permission table (allowed/denied/scoped/forbidden folders/`../`/hidden/`.obsidian`/`.tephra`/network host mismatch/redirect to an unlisted host/rate limit/oversize/write quota); package validation (zip slip, oversize, bad schema, duplicate id, upgrade with new permission); **sandbox escape attempts** in JS fixtures: access `process`, `require`, `Deno`, `globalThis.fetch`, `XMLHttpRequest`, `importScripts`, `Function('return this')()` — none exposes host power; **limits:** `while(true){}` is killed within 2.5 s and counted; a plugin that allocates in a loop is killed or contained (per 11.14 outcome); 3 strikes disable; a handler waiting for `ui.prompt` is not killed during the wait; bridge: concurrent calls resolve to the right promises; JSON-only boundary. Integration: a fixture plugin using `vault.read/write`, `notes.parse`, `editor.replaceSelection` against an in-memory vault and a fake editor.

**Verify.** `flutter test test/plugins`; manual on Windows and the phone with the sample plugins (11.17).

**Pitfalls.** The shim is part of the trusted computing base — keep it ≤ 300 lines, reviewed line by line, no `eval`. Never pass Dart object handles into JS. Do not cache permission decisions across plugin upgrades.

### 11.17 — Plugin manager UI, sample plugins, developer documentation

**Purpose.** Installable, understandable, documented.

**Files.** `app/lib/plugins/ui/plugin_manager_page.dart`, `plugin_install_dialog.dart`, `plugin_detail_page.dart`, `plugin_log_page.dart`, `app/lib/settings/…` entry, command `plugins.open-manager`, l10n `plugin*` keys, `plugins-samples/` (repo root: `word-count/`, `insert-date/`, `task-summary/` each with `plugin.json`, `main.js`, `README.md`), `tool/pack_plugin.dart` (zip with forward slashes), `docs/plugins/DEVELOPER_GUIDE.md`, `app/assets/guide/` page `Plugins.md`, tests.

**Implementation.**
1. **Manager (Settings → Plugins; phone and desktop layouts):** warning banner "Plugins can read and change your notes. Install only plugins you trust."; list (name, version, author, enabled switch, status: running/idle/disabled-by-strikes); **Install from file…** (`file_picker`, `.tephraplugin`) → install dialog listing **every permission in plain language** (e.g. "Read all notes in the folders: Daily/", "Download data from: api.example.com") with "Install" / "Cancel"; per-plugin detail: description, permissions (each switch can be turned off → the gate denies it), vault enablement (which vaults), settings form generated from `settings`, **Log** viewer (last 500 lines), "Reset strikes", "Remove" (deletes the folder after confirmation). Plugins are **off by default for each vault** until the user enables them.
2. **Sample plugins:** `word-count` (permissions `editor.read`, `ui.notice`: counts words/characters of the note), `insert-date` (`editor.edit`: inserts today's date; setting for the format), `task-summary` (`vault.read`, `vault.write` scoped to `Summaries/`, `vault.metadata`: writes `Summaries/Open tasks.md` listing open tasks from all notes — demonstrates scopes and `notes.parse`). Each has a README and a unit test in `tool/test/` that packs it and validates the manifest.
3. `docs/plugins/DEVELOPER_GUIDE.md`: quick start (create `plugin.json` + `main.js`, pack with `dart run tool/pack_plugin.dart plugins-samples/word-count`, install), the complete API reference (generated from `PLUGIN_API.md`, kept in one place — a test asserts every API name in the spec appears in the guide), debugging (log viewer, strikes), limits, security model, compatibility policy. The user-guide page `Plugins.md` explains installing safely.

**Tests.** Widget tests (both widths): install dialog shows each permission text and nothing is installed on Cancel; toggling a permission off makes a call fail; strikes display; removal deletes files; vault enablement default off; the three samples install and run through the host in an integration test with an in-memory vault (word count result notice; date inserted; summary file created only under `Summaries/`).

**Verify.** On the Android phone and Windows: install the three samples, run commands, see logs, remove them; confirm a plugin cannot be installed on the web preview.

**Pitfalls.** Never auto-enable a plugin after install. Never show a permission as "granted" that is not enforced by the gate.

---
## Item F — iOS, macOS and Linux builds

### 11.18 — Platform folders, dependency/platform audit, platform services

**Purpose.** Add the three platforms to the shared code base and find out exactly what does not port.

**Files.** `app/ios/`, `app/macos/`, `app/linux/` (generated), `tool/platform_audit.dart`, `docs/release/platform-audit.md`, `app/lib/core/platform/` (new implementations/no-ops per conventions §5.9), `app/lib/core/distribution.dart` (edit), `.github/workflows/ci.yml` (jobs `linux`, `macos`), `docs/release/platforms.md`, tests.

**Implementation.**
1. **Create the runners** (conventions §1 said "Web is only a dev preview"; this item **extends** the target list — record it in `PROGRESS.md` as a contract addition and update `docs/release/distributions.md`): `Push-Location app; flutter create --platforms=ios,macos,linux --org com.tephra --project-name tephra .; Pop-Location` (the project name and org must reproduce the existing id `com.tephra.app`; check that `flutter create` did **not** overwrite existing Android/Windows files — review `git status`/`git diff` and revert any unintended change). Set the bundle id `com.tephra.app` for iOS/macOS and the application id `com.tephra.app` in `linux/CMakeLists.txt`.
2. **Audit:** `dart run tool/platform_audit.dart` reads every `pubspec.yaml` and `pubspec.lock`, queries `https://pub.dev/api/packages/<name>/score` for the `platform:android|ios|linux|macos|windows|web` tags and prints a matrix (package, version, licence, platforms, direct/transitive, where used). Save as `docs/release/platform-audit.md`. For every plugin **unsupported** on a target platform: either (a) find a permissive replacement, (b) put the feature behind the existing platform-service interface with a **no-op/limited implementation** (conventions §5.9) and hide its UI on that platform, or (c) record "feature unavailable on <platform>" in the feature table. Known candidates to check first: `workmanager` (iOS uses BGTaskScheduler with strict limits; none on Linux/macOS → in-process timers only), `google_sign_in` (iOS/macOS need a client id and URL scheme; Linux unsupported → use the Windows loopback flow `DesktopOAuthFlow` from 03.14 on Linux and macOS), `flutter_secure_storage` (Linux needs `libsecret`), `tray_manager`/`window_manager`/global hotkeys (desktop only; Wayland limits global hotkeys), Phase 4 overlay/widgets (Android-only), ML Kit OCR (Android + iOS, not desktop), the Windows OCR plugin (Windows-only → Linux/macOS use none or Tesseract only if licence-clean and size-acceptable; default: no OCR), voice/ONNX runtime (check each target), `file_picker`, `local_auth` (iOS/macOS biometrics; Linux none), `permission_handler` (no `MANAGE_EXTERNAL_STORAGE` on iOS/macOS/Linux — `StoragePermissionService` no-op).
3. **Distribution switch:** extend `Distribution` with `appstore` (iOS), `macosDirect`, `linuxDirect`; the updater is allowed only for `macosDirect` and `linuxDirect` (11.20/11.19).
4. **CI:** `linux` job (ubuntu): `sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libjsoncpp-dev libayatana-appindicator3-dev libsqlite3-dev` then `flutter build linux --release`; `macos` job (`macos-latest`): `flutter build macos --release --no-codesign`; **iOS** compile check: `flutter build ios --release --no-codesign` on the same runner. Jobs run on push to `main` and `phase-*` only (cost).
5. **Pure-Dart packages** need no changes; run `dart test` for all packages on Linux in CI (already the case). Any path code that assumed `\` or drive letters is a bug here (Phase 1 uses `package:path`; the audit greps for `'\\'` and `Platform.isWindows` outside `core/platform`).

**Tests.** `tool/test/platform_audit_test.dart` (parser on captured sample API responses); platform-service selection tests per OS using the injected `TargetPlatformInfo`/override pattern from 03.14; all existing tests pass unchanged on Linux CI.

**Verify.** `flutter analyze` clean with the new folders; `flutter build linux --release` succeeds in CI (and locally in WSL2 if the human set it up).

**Pitfalls.** Do not edit generated platform files beyond what is needed (keep diffs reviewable). A plugin listed as supporting a platform on pub.dev may still be broken — the smoke tests below decide.

### 11.19 — Linux (tar.gz + .deb, secure storage, tray, inotify)

**Purpose.** A direct-download Linux build.

**Files.** `app/linux/` (edits), `installer/linux/` (`tephra.desktop`, `tephra.png` sizes, `deb/` control files, `build_deb.dart`), `tool/release/linux_build.dart`, `tool/release.dart` (command `linux`), `docs/release/linux.md`, `app/lib/core/platform/linux/…`, manifest/update additions (step 11.22), tests.

**Implementation.**
1. **Build** (on Ubuntu 24.04 — GitHub runner or WSL2; the human's Windows machine cannot cross-build Flutter Linux): `flutter build linux --release --obfuscate --split-debug-info=build/symbols/linux --dart-define=TEPHRA_DIST=linuxDirect --dart-define-from-file=…` → `app/build/linux/x64/release/bundle/` (+ `tephra` executable, `lib/`, `data/`). arm64 Linux is **not** a target in this item (record as Ideas).
2. **Packaging (decision: tar.gz + .deb; Flatpak/Snap later):** `tephra-<version>-linux-x64.tar.gz` (the bundle under `Tephra/` + `tephra.desktop` + icon + README); `.deb` built with `dpkg-deb --build` from a staged tree (`/opt/tephra/…`, `/usr/share/applications/tephra.desktop`, `/usr/share/icons/hicolor/<size>/apps/tephra.png`, symlink `/usr/bin/tephra`); `control` file: `Package: tephra`, `Version: <semver>`, `Architecture: amd64`, `Depends: libgtk-3-0, libsecret-1-0, libjsoncpp25 | libjsoncpp1, libayatana-appindicator3-1 | libappindicator3-1, libsqlite3-0`, `Maintainer`, `Description`; `postinst` runs `update-desktop-database`/`gtk-update-icon-cache` if present. Test install on a clean Ubuntu 24.04 container/VM (`apt install ./tephra_*.deb` pulls dependencies; start with a virtual display (`xvfb-run`) for a smoke launch in CI; real launch on a desktop VM for the gate).
3. **Linux specifics to implement/verify:** secure storage via **libsecret** (needs a running keyring: GNOME Keyring/KWallet; headless fallback = ask the user for a passphrase-protected file store is **out of scope** → show "A system keyring is required" with instructions); tray (`tray_manager` with ayatana appindicator; on GNOME needs the AppIndicator extension — document); window management; **global hotkeys unavailable on Wayland** (feature hidden when `XDG_SESSION_TYPE=wayland`); file watching via inotify — large vaults hit `fs.inotify.max_user_watches`: detect the error, fall back to the Phase 1 polling watcher, and show a hint with the `sysctl` command; folder picker via `file_picker` (GTK/xdg-desktop-portal); paths use `XDG_*` (`path_provider` handles it); font fallback for CJK/Bangla (test with Bangla sample text); HiDPI scaling; Wayland and X11 both smoke-tested.
4. **Updater for Linux direct builds:** `UpdateController` downloads nothing automatically; it shows "Version X is available — open the download page" (`url_launcher`) because package-manager/permission models differ; the manifest gains `platforms.linux.x64 {url, sha256, size, deb:{url,sha256,size}}` (additive; the Phase 9 parser ignores unknown platform keys; the verifier and signature rules are unchanged). `release.dart` writes it.

**Tests.** `build_deb.dart` unit test (control file fields, file list, permissions 0755/0644); the inotify-limit fallback with a fake watcher error; secure-storage unavailable path widget test.

**Verify.** `.deb` and tarball install and run on a clean Ubuntu 24.04 VM; core flows below.

**Pitfalls.** Do not bundle system libraries (`libgtk`, `libsecret`) — depend on them. Do not ship without testing on **both** X11 and Wayland sessions.

### 11.20 — macOS (Developer ID, notarization, DMG, sandbox decision)

**Purpose.** A signed, notarized macOS app for direct download. Needs **HF**.

**Files.** `app/macos/Runner/DebugProfile.entitlements`, `Release.entitlements`, `Info.plist` (edits), `installer/macos/` (`make_dmg.sh` is **not** used; `tool/release/macos_build.dart` drives commands, optional `create-dmg` config), `tool/release.dart` (command `macos`), `docs/release/macos.md`, tests.

**Implementation.**
1. **Decision:** ship **non-sandboxed, hardened-runtime, Developer-ID-signed, notarized** DMG first (a sandboxed Mac App Store build is a later, separate decision because vaults in arbitrary folders need security-scoped bookmarks everywhere). Bundle id `com.tephra.app`. `Release.entitlements`: `com.apple.security.app-sandbox` = **false**, `com.apple.security.network.client` = true, `com.apple.security.device.audio-input` = true (voice notes), `com.apple.security.cs.allow-jit` only if the chosen JS engine needs it (QuickJS does **not**; leave out), no `files.user-selected` keys needed when not sandboxed. `Info.plist`: `NSMicrophoneUsageDescription`, `NSCameraUsageDescription` (only if used), `CFBundleURLTypes` for `tephra` (item D), `LSMinimumSystemVersion` 11.0, `ITSAppUsesNonExemptEncryption` **left for the human's export-compliance decision (HF step 4) — do not set it yourself**.
2. **Build:** `flutter build macos --release --obfuscate --split-debug-info=build/symbols/macos --dart-define=TEPHRA_DIST=macosDirect --dart-define-from-file=…` (universal arm64 + x86_64 by default; verify with `lipo -archs Tephra.app/Contents/MacOS/Tephra`).
3. **Sign and notarize (commands the human/CI runs on the Mac; credentials never in the repo):** import the **Developer ID Application** certificate into the keychain (human, from the Apple Developer portal → Certificates); `codesign --force --deep --options runtime --timestamp --entitlements macos/Runner/Release.entitlements --sign "Developer ID Application: <Name> (<TEAMID>)" build/macos/Build/Products/Release/Tephra.app` (sign nested frameworks inside-out if `--deep` is insufficient: sign every `.framework`/`.dylib` first); `ditto -c -k --keepParent Tephra.app Tephra.zip`; `xcrun notarytool submit Tephra.zip --apple-id <id> --team-id <TEAMID> --password <app-specific password> --wait` (store credentials once with `xcrun notarytool store-credentials "tephra-notary"` and use `--keychain-profile tephra-notary`); `xcrun stapler staple Tephra.app`; build the DMG (`hdiutil create -volname Tephra -srcfolder Tephra.app -ov -format UDZO tephra-<version>-macos-universal.dmg` or `create-dmg`), sign the DMG (`codesign --sign …`), notarize and staple it too; verify: `spctl --assess --type execute --verbose Tephra.app` ("accepted, source=Notarized Developer ID") and `spctl --assess --type open --context context:primary-signature -v tephra.dmg`.
4. **macOS specifics:** Keychain via `flutter_secure_storage`; tray/menu bar and global hotkeys (accessibility permission prompt; document); first-run Gatekeeper behaviour; vault folder access in non-sandboxed mode needs no bookmark; the **Documents/Desktop/Downloads TCC prompts** appear on first access to those folders (explain in the first-run screen); updater for `macosDirect`: download the signed DMG, verify SHA-256 (manifest `platforms.macos.universal`), **open the DMG** and tell the user to drag to Applications (no silent install; Sparkle is not used); `release.dart macos` writes the manifest entry.

**Tests.** `tool/test` for the command construction (no secrets echoed), the manifest addition, entitlements hygiene (sandbox false; no unexpected entitlements). Manual on a Mac (Apple silicon and, if available, Intel): the gate flows; Gatekeeper accepts the DMG on a **different Mac** after download via a browser (quarantine attribute set).

**Verify.** `spctl` outputs recorded in `docs/release/macos.md`.

**Pitfalls.** Notarization fails for unsigned nested binaries or missing hardened runtime — read the `notarytool log <id>` output. Never commit the app-specific password or certificate.

### 11.21 — iOS (TestFlight)

**Purpose.** A working iPhone build in TestFlight. Needs **HF**.

**Files.** `app/ios/Runner/Info.plist`, `Runner.entitlements`, `app/ios/Podfile` (edits), `app/lib/core/vault/ios/` (security-scoped bookmark channel + Swift `BookmarkChannel.swift`), `docs/release/ios.md`, tests.

**Implementation.**
1. **Vault location model (decision):** (a) **default** vault folder inside the app's `Documents` (visible in the Files app under "On My iPhone → Tephra" with `UIFileSharingEnabled` = true and `LSSupportsOpeningDocumentsInPlace` = true in `Info.plist`); (b) **external folders** (iCloud Drive, other providers) via the system folder picker with **security-scoped bookmarks**: a small Swift channel `BookmarkChannel` (`pickFolder` → `UIDocumentPickerViewController` for folders, `bookmarkData(options: .minimalBookmark)` stored in `UserDefaults` by vault id; `resolve(vaultId)` → `URL(resolvingBookmarkData:)` + `startAccessingSecurityScopedResource()` held for the session; `stop`), used by `IoVaultFileSystem` through the resolved path. Document the limits (iCloud "optimize storage" can leave files un-downloaded — call `FileManager.startDownloadingUbiquitousItem` for placeholders, show "Downloading…" state).
2. **Background:** no always-on sync; use foreground sync on launch/resume + `BGAppRefreshTask` via `workmanager`'s iOS support **only if** the audit shows it is maintained; otherwise none. Local notifications via the existing `NotificationService` (iOS implementation using `flutter_local_notifications` if that is what Phase 4 chose — check). Biometrics: `NSFaceIDUsageDescription`. Microphone: `NSMicrophoneUsageDescription`. No overlay/bubble/widgets (Android-only services stay no-op).
3. **Google sign-in on iOS** needs an **iOS OAuth client** in the same Cloud project (bundle id `com.tephra.app`) and the reversed-client-id URL scheme in `Info.plist` (human creates the client; Gemini adds the plist entries) — or use the loopback/PKCE flow via `ASWebAuthenticationSession` (the custom-scheme redirect needs a client type that supports it); pick the plugin-supported path and document it. App Store guideline 4.8 (Sign in with Apple) applies to apps that use a third-party **login** service to authenticate the primary account; Tephra's primary account is Tephra Cloud (email) and Google is only a **storage authorisation** — note the interpretation in `ios.md` and re-check when submitting.
4. **Signing and TestFlight (human + Gemini):** Apple Developer portal → Identifiers → App ID `com.tephra.app` (capabilities: none special; iCloud not used); App Store Connect → create the app record; Xcode (`open app/ios/Runner.xcworkspace`) → Signing & Capabilities → team; `flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios --dart-define=TEPHRA_DIST=appstore …` (or Archive in Xcode) → upload with Transporter/`xcrun altool`/Xcode Organizer → App Store Connect → TestFlight → internal testers (the human's Apple ID) → install on the iPhone. External TestFlight and App Store submission additionally need: privacy nutrition labels (derive from `play-data-safety.md`), screenshots (6.7", 6.1", iPad if supported), export-compliance answers (**HF step 4**), age rating, review notes with a test account, privacy policy URL. App Store submission is **documented in `ios.md` as the follow-up**, not performed here.
5. **iOS minimum:** 16.0 (check the audit; raise only with a reason). Remove desktop-only UI paths; `Platform.isIOS` allowed only inside `core/platform` implementations.

**Tests.** Bookmark channel with a fake (store/resolve/stale-bookmark refresh); platform-service selection; widget tests at phone width for iOS-specific first-run text; all unit tests unchanged.

**Verify.** TestFlight build installs on the iPhone; gate flows pass.

**Pitfalls.** Security-scoped access must be started before and stopped after file operations or access randomly fails after a relaunch. iOS kills background work aggressively — never promise background sync.

### 11.22 — (Item F) common smoke test, performance and release wiring

**Purpose.** Make "supported platform" mean the same thing everywhere.

**Files.** `docs/release/platform-smoke-test.md`, `docs/release/perf-platforms.md`, `tool/release.dart` (commands `linux`, `macos`; manifest additions), `tool/make_site.dart` (download page rows for macOS and Linux), tests.

**Implementation.** **Smoke list** (each item pass/fail per platform, recorded): first run; open a vault (Documents location and an external folder); create/edit/save/reopen a note; links/backlinks/search; sync with Google Drive **and** Tephra Cloud (sign in, two-device edit, conflict); encrypted notes; backup now/restore; export a PDF; import a zip; plugins (item E, where supported); web clipper link (item D); update check behaviour for that distribution; accessibility basics (VoiceOver on macOS/iOS; keyboard-only on Linux/macOS). **Performance:** the conventions §10 budgets on one real device per platform with the 10k bench vault (Linux/macOS use the Windows budgets; iPhone uses the Android mid-range budgets): record numbers. **Release wiring:** manifest keys `platforms.macos.universal` and `platforms.linux.x64` (+ `deb`) generated and signed by `release.dart`; the download page shows them; the privacy policy mentions the platforms' secure-storage use.

**Verify / Gate F.** See Exit gates.

---

## Item H — Static-site publishing

### 11.23 — Exporter core: selection, rendering, links, backlinks, privacy rules

**Purpose.** Turn a vault (or part of it) into a self-contained website.

**Files.** `packages/tephra_io/lib/src/site/` — `site_options.dart`, `site_selection.dart`, `site_builder.dart`, `site_page.dart`, `link_resolver.dart`, `html_page_renderer.dart` (reuses the Phase 5 AST→HTML renderer; extend it only through composition), `backlinks.dart`, `slugger.dart`, `static_site_exporter.dart` (implements `Exporter`: `id 'static-site'`, `label 'Static website'`, `fileExtension ''`), `site_report.dart`; assets `packages/tephra_io/assets/site/` (CSS, JS, optional KaTeX/Mermaid copies); fixture vault `test_vaults/publish/`; tests `packages/tephra_io/test/site/*`.

**Implementation.**
1. **Options (`SiteOptions`, immutable, JSON-serialisable, stored in `.tephra/site.json` per vault — it is a settings file inside `.tephra/`, conventions §6.6 allows `.tephra` data):** `title`, `description`, `baseUrl` (optional, for canonical/sitemap), `mode` (`flagged` default | `folder` | `all`), `publishKey` (default `publish`; a note is included in `flagged` mode when frontmatter `publish: true`), `folders` (for `folder` mode), `excludeFolders`, `homeNote` (default: a note named `index`/`Home`, else a generated index), `theme` (`auto|light|dark`), `accent` (`#RRGGBB`), `showBacklinks` (true), `showTags` (true), `showGraph` (true), `searchDepth` (`titles|summary|full`, default `summary`), `math` (`none|katex`), `mermaid` (false), `frontmatterKeysShown` (default `title, date, tags, description`), `outputFolder`.
2. **Selection and privacy rules (all enforced, none optional):** include only `.md` notes selected by the mode; **always exclude**: notes with `publish: false`, `.tephraenc` (encrypted) files and anything in an unlocked encrypted area, hidden folders, `.trash`, `.obsidian`, `.tephra`, the excluded folders, stickies (`tephra-sticky: true`) unless explicitly flagged; **strip** `%%comments%%`, the Tephra-owned frontmatter keys, and every frontmatter key not in `frontmatterKeysShown`; **never** copy attachments that are referenced only by unpublished notes; links to unpublished notes render as plain text with `class="unpublished"` **without** exposing the target's title (the alias text the author wrote is kept; for `[[Target]]` without alias the displayed text is the target name as written in **this** note — document that authors who do not want a name visible should use an alias); embeds `![[Private note]]` of unpublished notes → a visible placeholder `[unpublished note]`; transclusion `![[Published note]]` inlines it (depth ≤ 3, cycle guard); `![[image.png|300]]` → `<img width="300" loading="lazy" alt>`; PDFs/other attachments are copied and linked.
3. **Rendering:** reuse the renderer for CommonMark/GFM/Obsidian syntax (callouts → `<div class="callout callout-<type>">` with `<details>` for foldable ones, tasks → disabled checkboxes, footnotes, highlights `<mark>`, tags → links to `tags/<tag>.html`, block IDs → `id` anchors, `==`, math → `<span class="math">` + KaTeX when enabled, ` ```mermaid ` → `<pre class="mermaid">` when enabled else a code block, ` ```query/base ` blocks → a code block (not executed), raw HTML → **escaped** (never emitted as live HTML; a note's `<script>` must not become a script on the site)). Heading anchors with slug ids (collisions ` -1`). Each page: title (frontmatter `title`, else first H1, else file name), breadcrumb from folders, tags, a **"Linked from"** list (backlinks among published notes with the line context), previous/next in folder (optional), meta description (`description` key or the first 160 chars of text), Open Graph tags, `<link rel="canonical">` when `baseUrl` is set.
4. **Paths and slugs:** `Folder/My Note.md` → `Folder/my-note.html` (lower-case, spaces → `-`, Unicode letters kept (percent-encoded in URLs), characters `\ / : * ? " < > |` removed, collisions disambiguated with `-2`); the mapping table is deterministic (sorted by original path) so rebuilds are stable; `index.html` is the home; `404.html`; `tags/index.html` + `tags/<tag>.html`; `sitemap.xml` and `robots.txt` when `baseUrl` is set; `.nojekyll` always (GitHub Pages).
5. **Link resolution** uses the Phase 2 `NoteIndex.resolveLink` rules, restricted to published notes; unresolved links get `class="broken"` and are listed in the report. **Report (`SiteReport`):** counts (pages, attachments, bytes), per-category warnings (broken links, unpublished targets, embeds replaced, attachments missing, oversized images > 5 MB, duplicate slugs), and the exact list of **included and excluded notes** (shown in the wizard preview before publishing — the user's last chance to see what goes public).

**Tests.** Fixture vault `test_vaults/publish/` with: published/unpublished/`publish: false`/encrypted placeholder notes, a note whose title is the sentinel `SECRET-TITLE-XYZ` that is unpublished but linked from a published note with and without alias, embeds (published, unpublished, image with size, cyclic transclusion), callouts (all types, folded), tasks, footnotes, tags (nested), math, mermaid, raw HTML `<script>alert(1)</script>`, Unicode and space file names, deep folders, duplicate slugs, comments. Assertions: **privacy** (the sentinel and every excluded note's body text appear in **no** output file; `.tephra`/`.obsidian` contents absent; Tephra frontmatter keys absent; no `<script>` from note HTML; attachments only referenced by unpublished notes not copied); **link checker** (crawl every output HTML: all `href`/`src` internal targets exist, all `#anchors` exist, no `..` escapes); golden HTML for 8 representative pages (text goldens, regenerated with `--update-goldens`); deterministic output (two builds byte-identical); slug collision handling; report contents; renderer reuse does not change Phase 5 exports (their tests pass).

**Verify.** `dart test` in `tephra_io`; build the `syntax` fixture vault with `mode: all` and open the result in a browser (via the preview server, 11.24).

**Pitfalls.** Privacy is the feature: a leak test failing is a **release blocker**, never a flake. Do not emit raw HTML from notes. Do not depend on JavaScript for basic reading (pages must read fine without JS).

### 11.24 — Search index, graph data, site assets, preview server, wizard, incremental builds, guides

**Purpose.** Make the site useful (search, graph) and publishing safe and easy.

**Files.** `packages/tephra_io/lib/src/site/search_index.dart`, `graph_data.dart`, `site_manifest.dart`, `incremental_writer.dart`, `preview_server.dart`; assets `site.css`, `site.js` (search + graph + theme toggle; **own code, no libraries**), optional `katex/` and `mermaid/` copies with licence files; app UI `app/lib/import_export/site/` (`publish_site_wizard.dart`, `site_preview_page.dart`, `site_settings_page.dart`), command `export.static-site`, l10n `site*` keys, `docs/user/PUBLISHING.md` (also a guide page), tests (Dart + `node --test` for `site.js`).

**Implementation.**
1. **Search index** (`_tephra/search-index-<n>.json`, sharded ≤ 1 MB each, plus `search-meta.json` with shard list and page table): pages `{id, title, url, tags[], headings[], summary}`; tokens: lower-case, Unicode word split on `[^\p{L}\p{N}]+`, no stemming; per-shard postings `term → [[pageId, weight]]` with weights title ×5, heading ×3, tag ×3, body ×1 (body limited by `searchDepth`: `titles` = title/headings/tags only; `summary` = first 1,000 characters; `full` = whole text, still sharded); `site.js` loads `search-meta.json` lazily on first keystroke/focus, loads needed shards by term prefix bucket (first two characters), scores by summed weights with prefix matching for the last typed term, shows title + snippet (first occurrence in the summary), keyboard navigation (`/` focuses, arrows, Enter), works offline once loaded. Target: 10k-note vault index total < 12 MB at `summary`.
2. **Graph:** `_tephra/graph.json` `{nodes:[{id,title,url,tags,degree}], edges:[[sourceId,targetId]]}` (published notes only; edges only between published notes); `graph.html` draws a force-directed layout on `<canvas>` with `site.js` (own implementation, Barnes-Hut optional, capped at **3,000 nodes**; above that only the **local graph** (depth 1–2 neighbours of the current page) is offered); each page shows a small local graph when `showGraph` is on; no layout libraries.
3. **Assets and offline behaviour:** `site.css` (system font stack, `prefers-color-scheme` + manual toggle stored in `localStorage` guarded by try/catch, responsive, print styles, callout colours, ≥ 4.5:1 contrast), `site.js` (≤ 400 lines total, no dependencies, ES2020), optional KaTeX (`math: katex`: copy `katex.min.css`, `katex.min.js`, `auto-render` and the woff2 fonts with their licence files from `app/assets/site/katex/`; **verify each file's licence header**; fonts are OFL/MIT — keep the notices) and Mermaid (`mermaid: true`: `mermaid.min.js` MIT copy). **No CDN links, no analytics, no external fonts** in any generated page (test greps output for `http://`/`https://` hosts other than links authored in notes).
4. **Incremental builds:** `site-manifest.json` in the output (hash of each generated file, source path, options hash); a rebuild writes only changed files, deletes files it generated earlier that no longer exist (never anything it did not generate), and reports changed/unchanged counts. Output path safety: refuses to write into a folder that is non-empty and has **no** `site-manifest.json` unless the user confirms "Use this folder anyway" (never deletes foreign files).
5. **Preview server (`PreviewServer`):** `HttpServer` bound to `127.0.0.1` on a random port serving the temp build folder (read-only, no directory listing, `Cache-Control: no-store`, path traversal-safe), opened in the system browser (`url_launcher`); `file://` is **not** used because browsers block `fetch()` of local JSON. Stops when the wizard closes.
6. **Wizard (`export.static-site`, Settings → Import & export → "Publish as website…"):** step 1 *What to publish* (mode, folders, `publish` key help); step 2 *Look & features* (title, description, theme, accent, graph, search depth, math/mermaid); step 3 **Review** — the included/excluded lists and warnings from `SiteReport` with counts, "Open preview" (builds to a temp folder and opens the preview server); step 4 *Output* (choose folder or **zip**; `baseUrl`; `CNAME` text for custom domains; **Build**); step 5 *Done* — result summary, "Open folder", and the **deployment guide** for the chosen target. Everything runs in `Isolate.run` with progress; cancelling leaves the output untouched (build to temp, then incremental copy).
7. **Guides (`docs/user/PUBLISHING.md` → shipped as a guide page):** GitHub Pages (create a repo, push the folder to `main:/docs` or `gh-pages`, enable Pages; `.nojekyll` is included); Cloudflare Pages (direct upload of the folder or Git); Netlify (drag-and-drop); any static host (`rsync`/SFTP); custom domain notes; **privacy reminder** ("Everything you publish is public. Review the included list. Encrypted notes and unpublished notes are never exported, but a note you published may mention them").

**Tests.** Index/graph builders (sizes, sharding, weights, determinism); `node --test packages/tephra_io/assets/site/test/` for `site.js` search scoring (fixture shards), keyboard handling logic and graph layout stability (pure functions extracted into modules testable in Node; CI ubuntu has Node; locally skipped with a notice if Node is absent); preview server (traversal attempts `../`, encoded variants, symlinks → 404/403; binds only to loopback); incremental writer (changed/unchanged/deleted, refuses foreign files, manifest round trip); wizard widget tests at both widths (review lists render, Build disabled until a folder is chosen, cancel leaves nothing); the no-external-requests test; the 10k-note bench vault in `mode: all` builds in **< 60 s** on this PC (record time and output size; run in the `perf` tag).

**Verify.** Build the `publish` fixture and the user's real vault (copy) with a few notes flagged `publish: true`; browse locally via preview: search finds notes, graph opens, backlinks work, unpublished notes absent, dark mode works, mobile width usable; deploy once to a free static host.

**Pitfalls.** Never write outside the chosen output folder. Never serve the preview on `0.0.0.0`. Keep `site.js` dependency-free (the licence and audit story depends on it).

---

## Demo script (per item — run the one(s) you completed; record results in `PROGRESS.md`)

- **A Play:** install the closed-test build from the Play link on a phone; first run shows the All-files-access explanation → grant → open `Documents/TestVault` → edit; Settings → About has **no** "Check for updates"; Drive sign-in works; the Data safety page in the Console matches `play-data-safety.md`; open the account-deletion web page on staging.
- **B Microsoft Store:** install the Store build (from the Store or the test package) → opens a vault, edits, tray works; no "Check for updates"; `tephra://clip` link opens the confirm dialog; WACK report green.
- **C Collaboration spike:** run the property tests live (`dart test`), show `results.md` numbers, show two replicas typing concurrently in the prototype's console demo converging, read the decision record aloud.
- **D Clipper:** load the extension in Chrome, sign in to Tephra Cloud, clip an article → it appears in `Clippings/` on the PC and the phone within seconds; clip a selection; click "Send to the Tephra app instead" while signed out → confirmation dialog → saved; try a hostile link → confirmation shown, nothing outside `Clippings/`.
- **E Plugins:** Settings → Plugins → install `word-count` (permission list shown) → run its command → notice; install `task-summary` scoped to `Summaries/` → file created; revoke its write permission → command fails with a clear error; run an infinite-loop test plugin → killed within ~2 s and disabled after 3 strikes.
- **F Platforms:** Linux `.deb` on Ubuntu (X11 and Wayland) — edit, search, Drive/Cloud sync; macOS notarized DMG opened on a second Mac — edit, search, sync; iPhone TestFlight build — create a vault, edit, sync with Cloud.
- **H Static site:** flag five notes `publish: true`, run Publish as website, review the lists, preview (search, graph, backlinks), build to a folder, deploy to a free host, open the public URL on the phone.

---

## Exit gates (one per item; each is independent — tick only the items you chose to do)

**Gate 11.1 (flavors)**
- [ ] `play` and `direct` flavors build; `play` has no `REQUEST_INSTALL_PACKAGES` and no reachable updater code (hygiene tests green); the direct in-app update still works (09.15 manual test repeated); `release.dart` uses the flavor paths.

**Gate A (Google Play)**
- [ ] Signed `.aab` validates with `bundletool`, targets the **currently required API level**, passes the smoke test from a `bundletool`-installed build; signing path (1 or 2) recorded with fingerprints.
- [ ] "All files access" declaration text + demo video accepted by Play, **or** the SAF contingency decision recorded and its gate passed.
- [ ] Data safety answers derived from the real data flows and consistent with the privacy policy (consistency test green); account-deletion web page works end to end on staging and production; listing, graphics and content rating complete.
- [ ] Closed test ran with ≥ 12 opted-in testers for 14 continuous days (if the account type requires it); production release live with a staged rollout; Android vitals crash and ANR rates within Play's "bad behaviour" thresholds for 7 days.

**Gate B (Microsoft Store)**
- [ ] `.msix` built with the exact Partner Center identity, installs and runs on a clean Windows 10/11 machine; **WACK passes**; no updater in the Store build; app data location behaviour documented and the "reconnect sync" path tested.
- [ ] Certification passed and the app is live (or in a published state the human accepts); listing complete with screenshots.

**Gate C (collaboration spike)**
- [ ] `docs/spikes/crdt/` has criteria, evidence-based candidate evaluation with licence checks, a pure-Dart prototype whose property tests pass (3 and 5 replicas × 10,000 ops, no interleaving, idempotent apply, external-edit absorption `apply(diff_to_ops(a,b)) == b` for 2,000 pairs) and benchmarks at or better than the targets (or a documented re-scoring that picked another candidate).
- [ ] `design.md` answers all eight questions (key sharing, transport, persistence interplay, scope, threats, rollout) and `docs/decisions/collaboration.md` carries the human's `APPROVED` line. **No collaboration code ships.**

**Gate D (web clipper)**
- [ ] Inbox crypto passes the frozen vectors in Dart **and** in the extension (cross-language known-answer test); the server cannot decrypt (a test asserts the stored bytes contain no plaintext marker); inbox limits, TTL and rate limits tested.
- [ ] The extension clips a page and a selection to a vault on Chrome **and** Edge; the resulting note has correct frontmatter, readable Markdown, absolute links, appears on two devices **byte-identical**, and syncs; fixture conversion snapshots reviewed; `npm audit --omit=dev` clean of high/critical.
- [ ] `tephra://clip` always asks for confirmation, writes only under the clipping folder, enforces size limits, and survives the hostile-link tests on Windows and Android; the Windows installer registers the protocol and the uninstaller removes it.

**Gate E (plugins)**
- [ ] Runtime decision record approved; API spec approved (`APPROVED` lines); host implements the spec exactly (spec-vs-guide test green).
- [ ] Every permission row has allow/deny tests; all sandbox-escape fixtures fail to reach host power; an infinite loop is killed within 2.5 s and the plugin is disabled after 3 strikes; paths cannot escape the vault or reach `.obsidian/`/`.tephra/`; zip-slip and oversize packages are rejected.
- [ ] Three sample plugins install and run on Windows and Android; plugins are off per vault by default; plugin files are never in a vault and never synced; no plugin runs when the app is locked.

**Gate F (iOS / macOS / Linux)** — per platform you built
- [ ] `docs/release/platform-audit.md` complete; every unsupported plugin has a replacement or a hidden/no-op feature; CI builds Linux and macOS/iOS (no-codesign) green.
- [ ] **Linux:** `.deb` and tarball install on a clean Ubuntu 24.04 and pass the smoke list on X11 and Wayland; hotkeys hidden on Wayland; inotify fallback works.
- [ ] **macOS:** DMG notarized and stapled; `spctl` accepts both app and DMG on a second Mac after a browser download; smoke list passes (Apple silicon at minimum).
- [ ] **iOS:** TestFlight build installed on a real iPhone; smoke list passes including external-folder bookmarks and Cloud/Drive sync; export-compliance decision recorded by the human.
- [ ] Performance budgets (conventions §10) met on one real device per platform; updater behaviour correct per distribution (Linux: opens download page; macOS: DMG; iOS: none); the signed manifest additions verify in the app.

**Gate H (static-site publishing)**
- [ ] Privacy tests green: the sentinel unpublished title and every excluded note's text appear in **no** output file; encrypted/hidden/`.tephra` content absent; no raw note HTML becomes live HTML; attachments referenced only by unpublished notes are not copied.
- [ ] Link checker reports 0 broken internal links on the fixture and on a real vault copy (excluding links the report lists as broken in the source); output is deterministic (two builds identical); the incremental writer never touches foreign files.
- [ ] Search finds expected notes, graph renders (≤ 3,000 nodes; local graph above), backlinks correct, dark mode and mobile layout work, pages readable without JS; the 10k-note vault builds in < 60 s and the output size is recorded; no external requests in any generated page.
- [ ] Deployed once to a free static host and viewed on the phone.

**Phase-level:** `flutter analyze --fatal-infos` 0 issues; all tests green; `dart run tool/check_licenses.dart` passes (including npm packages listed in the notices); `THIRD_PARTY_NOTICES.md` regenerated; privacy policy updated for every new data flow (clipper inbox, platforms, plugins' network permission wording); contract additions listed in `PROGRESS.md`; each completed item merged with `--no-ff` and tagged; stop and report to the human after **each item**.

---

## Hand-off

1. **Per-item outcomes** go in `PROGRESS.md` (what shipped, gate numbers, store review outcomes, open issues). Unfinished or deferred items stay listed under "Phase 11 backlog" with the reason.
2. **Contract additions to fold into `00-conventions.md` when the human approves:** target platforms (iOS, macOS, Linux added to §1), `Distribution`/`TEPHRA_DIST`, product flavors `direct`/`play`, the `tephra://clip` URL scheme, `.tephra/site.json`, the plugin API v1 and `plugin.json` schema, the inbox endpoints and `inbox-crypto-vectors.json`, new server migrations `m003`/`m004`, additive manifest platform keys (`macos`, `linux`), `StaticSiteExporter` in `tephra_io`.
3. **What a future collaboration phase relies on:** the approved decision record, the prototype code in `docs/spikes/crdt/crdt_spike/` (to be promoted into a real package with a conventions update), the sealed-box construction from the inbox (reused for key wrapping), Tephra Cloud WebSocket infrastructure, and the plugin runtime (if Yjs-in-JS was chosen).
4. **Extra sync targets** (WebDAV/Nextcloud, S3-compatible, Dropbox, OneDrive, Git — PHASE_PLAN Phase 11) remain **unstarted**: each is a new `SyncProvider` + the contract suite + a wizard card; estimate and order are in `PROGRESS.md` → Ideas.
5. **Known limitations to carry:** plugins are sideload-only and device-local; collaboration is design-only; the clipper needs Chrome/Edge ≥ 133 (WebCrypto X25519); macOS is non-sandboxed (Mac App Store later); iOS has no background sync; Linux global hotkeys do not work on Wayland; Play-installed and direct-installed apps are update-compatible only if the Play signing path 1 was used.
