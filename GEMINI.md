# GEMINI.md — Rules for building Tephra

You are building **Tephra**, an Obsidian-compatible Markdown notes app for **Android and Windows**, written in Flutter.
This file is your standing instruction set. Read it fully at the start of every session, and follow it exactly.

## 0. Read these first, in this order

1. `GEMINI.md` (this file) — how you must work.
2. `instructions/00-conventions.md` — the technical contract: folder layout, package boundaries, interfaces, coding rules.
   **Every phase depends on it. Never contradict it.** If a phase file and the conventions disagree, the conventions win; note the conflict in `PROGRESS.md`.
3. `PROGRESS.md` — where the build currently is. Continue from the first unchecked step.
4. The instruction file for the current phase: `instructions/phase-NN-*.md`. Its "Before you start" section lists what must already exist;
   check it against the repository before step 1, and record any mismatch in `PROGRESS.md` before continuing.
   Phase files were written to fit together, but if a later phase names something differently from what an earlier phase built,
   **keep what was built** (the earlier phase's name), adapt the new code to it, and note the mapping in `PROGRESS.md`.
5. Background only (do not implement from these directly): `docs/plan/IMPLEMENTATION_PLAN.md` (what the product is) and
   `docs/plan/PHASE_PLAN.md` (the phase overview). The `instructions/` files are the detailed, authoritative version.

## 1. Where you work

- **Work only inside `D:\script\tephra-gemini\`.** This folder is the Git repository root and the project root.
- **Never read from, copy from, or write to `D:\script\note taking app\`.** That is a separate build by another agent. Keep the two independent.
- Never modify anything under `D:\dev\` (the shared Flutter and Android SDKs) except through normal `flutter`/`sdkmanager` commands.

## 2. The machine (already set up — do not reinstall)

| Tool | Location / version |
|---|---|
| OS | Windows 11, shell: PowerShell 5.1 (no `&&`; use `;` or `if ($?) { ... }`) and Git Bash |
| Flutter | `D:\dev\flutter` — Flutter **3.47.7** stable, Dart **3.13.5** (on the user PATH) |
| Android SDK | `D:\dev\android-sdk` (`ANDROID_HOME` set) — platform `android-36`, build-tools `36.0.0`, platform-tools; licences accepted |
| Java | JDK 17 (`C:\Program Files\Java\jdk-17`) |
| Windows C++ toolchain | Visual Studio Build Tools 2022 (17.14) with the C++ workload + Windows SDK + ATL (`VC.ATL`, needed by flutter_secure_storage; added 2026-10-20) |
| Windows Developer Mode | **On** (needed: Flutter plugins use symlinks) |
| Git | 2.55 |
| Dev Launcher | running at `http://127.0.0.1:7799` (see Phase 0) |

If `flutter` is not found in a new terminal, use the full path `D:\dev\flutter\bin\flutter.bat`.
`flutter doctor` was fully green when these instructions were written.

## 3. How you work — the phase loop

Phases run strictly in order: 0, 1, 2, … Never start a phase until the previous phase's **exit gate** is fully checked in `PROGRESS.md`.

For every phase:

1. Create a branch `phase-NN` from `main`.
2. Do the steps **in the order written** in the phase file. Each step lists files, code contracts, tests and a "Verify" block.
3. **After every step**:
   - run the step's Verify commands, and always:
     ```
     dart format --output=none --set-exit-if-changed app/lib app/test packages tool
     flutter analyze --fatal-infos
     ```
     plus the tests of every package you touched;
   - fix every failure before moving on — **never** skip, comment out, or weaken a test or lint to make it pass;
   - tick the step in `PROGRESS.md` and add one line of notes (what you built, anything surprising);
   - commit: `git add -A` then `git commit -m "phase NN.S: <short summary>"`.
4. When all steps are done, run the phase's **Demo script** and **Exit gate** checks. Record results (numbers for performance budgets) in `PROGRESS.md`.
5. Merge `phase-NN` into `main` (`git merge --no-ff`), tag `v0.NN.0` (exceptions: Phase 9 tags `v1.0.0`, Phase 10 tags `v2.0.0`), and **stop**. Report to the human what was built and the gate results.
   Wait for the human to say "continue" before starting the next phase.

## 4. Non-negotiable rules

1. **Never lose or corrupt user data.** All file writes are atomic (write temp file → flush → rename). Never write a note that has not changed.
   Never delete without moving to trash/history first. When unsure, keep both copies.
2. **Obsidian compatibility is the product.** A vault edited by Tephra must open in Obsidian unchanged, and vice versa.
   Never reformat a file the user did not edit. Never add Tephra-specific syntax to note bodies (Tephra data goes in frontmatter keys
   defined in the conventions, or in the `.tephra/` folder).
3. **Both platforms, every step.** Code must work on Android and Windows. Use the adaptive layout rules in the conventions;
   never branch on `Platform.isAndroid` for layout — branch on screen width. Platform checks are allowed only for platform-only features
   (tray, global hotkeys, widgets, overlays, permissions).
4. **Core packages are pure Dart.** Nothing in `packages/` may import `package:flutter`. They are tested with `dart test`.
5. **Strict code quality.** `flutter analyze --fatal-infos` must report zero issues. No `dynamic` (except decoding JSON, immediately cast).
   No `print` (use `package:logging`). No `// ignore:` without a comment explaining why.
6. **Licences.** Only add dependencies whose licence is MIT, BSD, Apache-2.0, zlib, MPL-2.0 or Unlicense. Run
   `dart run tool/check_licenses.dart` after adding any dependency. GPL/LGPL/AGPL is forbidden. The code is closed-source (private).
7. **No secrets in the repo.** OAuth client IDs, signing keys, passwords go in the git-ignored `secrets/` folder or environment variables.
8. **No copied code** from Obsidian, other note apps, or GPL projects. Write it yourself. Using a permissive package as a dependency is fine.
9. **Do not invent scope.** Build exactly what the phase file says. Ideas for extra features go in `PROGRESS.md` under "Ideas", not in code.
10. **Do not change the contracts** in `00-conventions.md` (interfaces, folder layout, file formats). If a contract is genuinely wrong,
    stop and ask the human, explaining why.
11. **Every user-visible string** goes in `app/lib/l10n/app_en.arb`, never hard-coded in widgets.
12. **Write tests with the code**, in the same step. A step without its tests is not done.

## 5. When to stop and ask the human

Stop, explain, and wait if:
- an exit-gate check fails and you cannot fix it within the step's scope;
- a step needs something only the human has: a real Android phone connected, a Google account / OAuth client ID, a signing key,
  a payment or hosting decision, Windows admin approval;
- a dependency you need has a non-allowed licence and no allowed alternative exists;
- a performance budget is missed by more than 25% after a reasonable optimisation attempt;
- you would need to change a contract in `00-conventions.md`;
- a command would delete files outside the repo, or rewrite Git history on `main`.

Never pretend something works. If you could not test something on a real Android device, write that in `PROGRESS.md` as "not verified on device".

## 6. Shell tips for this machine

- PowerShell 5.1: chain with `;`, not `&&`. Quote paths with spaces.
- Prefer your file-writing tool over shell heredocs/`echo` for creating source files (heredocs mangle quotes and `$`).
- YAML: quote any string value containing `: ` (e.g. pubspec `description: "Sync: engine"`), or `pub get` fails.
- First Android build downloads Gradle and takes 5–15 minutes; that is normal. Run it in the background if your tool allows.
- Windows paths in Dart: use `package:path` (`p.join`), never string concatenation with `/` or `\`.
- If `flutter pub get` says "Please enable Developer Mode", stop and tell the human (it is supposed to be on).

## 7. Progress file

`PROGRESS.md` is the single source of truth for where the build is. Keep it accurate. Format is defined at the top of that file.
