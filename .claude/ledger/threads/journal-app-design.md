---
thread: journal-app-design
status: paused
updated: 2026-07-20
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Verify the two plan-fix agents' edits landed in .mitosis/{today-screen,settings-screen}.plan.md, run the 3 pre-flights, then LAUNCH the one final all-remaining-units run (2026-07-11-03 block, mergePolicy "human-gated") and merge each green PR PROMPTLY.
branch: main
---

## Status
23/31 merged, 0 open PRs (garden-screen #22, day-detail #23 merged by user this session). The FINAL run is
STAGED but NOT launched: .mitosis/run.json holds all 31 msps with today-screen/settings-screen parked at
plan-review; their plans are being fixed by two background agents. One run should reach 31/31.

## Active Goal
Complete all 31 Field Notes v1 MSPs in AS FEW mitosis flows as possible — one final human-gated run carrying
all 8 remaining units, human merging green PRs promptly so the frontier-train build-ahead lands
shell-nav-integration in the same run.

## Next Step
Verify plan fixes landed -> 3 pre-flights -> launch the final run -> merge PRs promptly.

## Open Risks
- CI IS HOLLOW FOR DART (decisions/2026-07-20-ci-gates-are-hollow-for-dart.md). Run fullValidationCmd locally
  against each PR head worktree before EVERY merge.
- Adversarial plan-review may re-park today-screen/settings-screen with NEW findings after the fixes. Blocking
  findings are addressed (today §4 DAG; settings Override import) but convergence is not guaranteed.
- MERGE PROMPTLY to stay at one flow: frontier-train poll budget is 6 cycles x <=300s (resets per merge). Slow
  merges -> shell-nav-integration parks -> one cheap relaunch resume (not a rebuild).
- capture-photo/voice/video each add pub deps AND regenerate macos/Flutter/GeneratedPluginRegistrant.swift:
  merge one-at-a-time with `flutter pub get` regeneration, never hand-resolve. pubspec.yaml also systemic.
- The fold PROPAGATES parked status through dependsOn; keep only today/settings park deltas in run.json (the
  stale entry-cards park was removed this session). shell-nav@null propagation is benign (runs fresh pipeline).
- Do NOT hand-edit run.json's base line or re-trim unless rebuilding the manifest; it is staged + fold-verified.
- `.mitosis/` is gitignored — staged run.json + batch-tooling live only on this machine.
- No Android SDK: capture-* Android bits never compile here; file-content receipts only.
- 3 files still carry the symlink guard defect (task chip task_ecab775c); 7-CLI fix committed, run-engine.mjs
  dirty in .windful-ocean.

## Key Decisions
- decisions/2026-07-20-one-run-completion-frontier-train.md — one run completes the app (frontier-train,
  code-verified); fix parked plans first; include all 8; merge promptly
- decisions/2026-07-20-batch-3-scoping.md — batch-3 four-screen scope (the reasoning the user corrected)
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — local validation before every merge
- decisions/2026-07-20-reminders-day2-prearm-followup.md — day-2 reach deferred (needs a NEW msp id; NOT in
  this run — the merged `reminders` unit is skipped by the reconcile; author it after 31/31)
- decisions/2026-07-19-pubspec-parallel-conflict.md — systemic pubspec conflict; serial union merges
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact line
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated + main-thread/user merge under consent
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories
  gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell). The reminders
  day-2 pre-arm follow-up MSP is post-31 work, not this run.

## Pointers
- .mitosis/run.json — STAGED final 31-msp manifest (fold-verified; today/settings parked@plan-review)
- .mitosis/run.json.pristine-backup — untouched 31-MSP source (md5 a7ca0a4f...); gitignored
- .mitosis/batch-tooling/ — MERGED=23, BATCH=8; parks/today-settings-parks.jsonl = preserved park deltas
- .mitosis/{today-screen,settings-screen}.plan.md — parked plans being fixed (verify before launch)
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — VERBATIM launch block (set "human-gated")
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- GitHub: https://github.com/SatanshuMishra/field-notes (PRIVATE). Project name is field-notes.

## Recent Sessions
- sessions/2026-07-20-03-journal-app-design.md — 23/31; engine verified; final run staged, not launched
- sessions/2026-07-20-02-journal-app-design.md — reminders shipped, 21/31; CI found hollow
- sessions/2026-07-20-01-journal-app-design.md
