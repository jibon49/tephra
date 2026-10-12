# How to start the Gemini build

This folder is a clean, separate workspace for building Tephra with Gemini. It contains only instructions;
Gemini creates all code here, phase by phase. Nothing here touches `D:\script\note taking app` (the Claude build).

## What is in this folder

| File | For whom | What |
|---|---|---|
| `GEMINI.md` | Gemini (read automatically by Gemini CLI; tell Antigravity to read it) | How Gemini must work: phase loop, rules, when to stop and ask you |
| `AGENTS.md` | Agents that look for this name | Points to `GEMINI.md` |
| `instructions/00-conventions.md` | Gemini | The technical contract every phase follows |
| `instructions/phase-00-…md` … `phase-11-…md` | Gemini | Step-by-step instructions per phase |
| `PROGRESS.md` | You and Gemini | Checklist Gemini ticks after every step — check it to see where the build is |
| `docs/plan/` | Background | The overall plan (same as in the Claude build) |

## Start (Antigravity)

1. Open the folder `D:\script\tephra-gemini` in Antigravity (File → Open Folder).
2. Start a new agent conversation and paste this message:

   > Read `GEMINI.md` completely and follow it as your standing rules. Then read `instructions/00-conventions.md`,
   > `PROGRESS.md` and `instructions/phase-00-foundation.md`. Start Phase 0 from the first unchecked step.
   > Work step by step, run every Verify block, tick `PROGRESS.md` and commit after each step.
   > Stop at the end of the phase and report the exit-gate results to me.

3. When Gemini finishes a phase it stops and reports. Check the report and `PROGRESS.md`, try the app, then reply
   **"continue with the next phase"**.

## Start (Gemini CLI)

```
cd "D:\script\tephra-gemini"
gemini
```
Gemini CLI loads `GEMINI.md` automatically. Then paste the same message as above.

## Tips

- Use one conversation per phase (long conversations lose detail). Every new conversation: repeat the start message —
  `PROGRESS.md` tells Gemini where to continue.
- Gemini will stop and ask you for things only you can do: connecting an Android phone, Google OAuth client IDs (Phase 3),
  a signing key (Phase 9), hosting choices (Phase 10).
- If Gemini drifts (changes the plan, skips tests, edits the other folder), point it back to `GEMINI.md` section 4.
- To compare with the Claude build later, compare `PROGRESS.md` gate results and run both apps side by side.
