---
thread: journal-app-design
status: paused
updated: 2026-07-16
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Fresh session (CLEAN context) -> LAUNCH batch 1 mitosis human-gated. run.json is ALREADY fixed+trimmed to 18 MSPs (14 merged + mood-picker/streak-service/sound-effects/data-management), one compact line, reuse-gate VERIFIED. Use the sessions/2026-07-11-03 contract but with `mergePolicy:"human-gated"` (NOT its autonomous line). Expect 4 PRs; verify via `gh pr list --state open`; merge under per-batch consent. Do NOT resume any prior run id.
branch: main
---

## Status
PAUSED at 14/31 SHIPPED (origin/main 66a12a4; local main 3f40f8f, contains core-providers — reconciliation invariant holds). Session 2026-07-16-02 shipped no code: it FOUND the root cause of every failed relaunch (run.json was pretty-printed -> `foldRunManifest` returned null -> engine silently fresh-decomposed all 31 MSPs + overwrote the file every run, burning the window before any MSP work). Fixed run.json to one compact line AND trimmed it to batch 1 (18 MSPs), verified against the engine's real fold+reuse logic. Did NOT launch (context hit 72%; launching near-full is the proven kill condition).

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main by BUILDING the downstream dependents in session-sized batches via human-gated mitosis (agents publish green PRs; main thread merges under consent). Batch 1 staged: mood-picker, streak-service, sound-effects, data-management.

## Next Step
Fresh session, CLEAN context -> launch batch 1 (run.json already staged) -> confirm the engine log says it SKIPPED Decompose (reuse fired) -> verify `gh pr list --state open` -> merge 4 green PRs under per-batch consent. Then re-derive batch 2 from `.mitosis/run.json.pristine-backup` via `.mitosis/batch-tooling/`.

## Open Risks
- **The engine has NO MSP-filtering input** (audited): scoping is done ONLY by out-of-band editing of run.json's `msps[]`. A trimmed manifest that fails the reuse gate SILENTLY reverts to fresh-decompose-and-overwrite (no error). Always run `node .mitosis/batch-tooling/verify_manifest.js` before launch.
- **run.json fold is fragile:** it MUST stay one compact line (base object) + optional append-only JSONL deltas. Any pretty-print breaks fold -> silent full re-decompose. `.mitosis/` is gitignored, so backups live there but are NOT committed — `.mitosis/run.json.pristine-backup` is the durable 31-MSP source of truth for future batches.
- **entry-cards is STRUCTURALLY broken:** add/add conflict on `test/features/entry_cards/support/entry_cards_harness.dart`, created independently by BOTH `task-media-resolver-harness` (de79f13) and `task-note-body`. DETERMINISTIC; excluded from batches until the plan gives that file one owner. Blocks 5 screen MSPs.
- The mitosis `result.shipped` array is MISLEADING — only done-oracle fast-skips, NOT PRs just published. Always verify via `gh pr list --state open`.
- SESSION-LIMIT bound: a run exhausts a ~2h window. Batch-scoping (this session's fix) keeps a run inside one window. Park checkpoints may fail to persist at the limit (written=null) -> parked MSPs rebuild fresh (idempotent).
- Launch each relaunch from a FRESH (not near-full) context — runs die when launched near-full (proven twice).
- Human-gated agents publish-then-stop (PROVEN); main thread does every merge; the classifier requires EXPLICIT per-batch merge consent even for the main thread.
- The safety classifier (opus-4-8) was UNAVAILABLE when reviewing `parallelize:garden-screen` and `sec:streak-service` on wf_bfb12095-952 — unverified; re-review if reused. 6 leftover batch-MSP worktrees not cleaned (destructive; needs consent).
- Local launch blocked until Phase 8 (full Xcode+CocoaPods + Android SDK not installed). Binary assets human-provided + committed.

## Key Decisions
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json must be one compact line (fold defect = silent full re-decompose); scope batches by out-of-band trim from the pristine backup; batch 1 = 4 leaf MSPs
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main onto origin/main before EVERY relaunch (engine cuts worktrees from the bare LOCAL `main` ref)
- decisions/2026-07-12-direct-ship-built-msps.md — direct main-thread ship of already-built MSPs (Option A); engine builds unbuilt dependents (Option B)
- decisions/2026-07-12-human-gated-merge-policy.md — autonomous structurally blocked; human-gated + main-thread merge (governs Option B builds)
- decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md — receipts.yml npm-ci fix (ec7b959); relaunch/keep-run.json semantics
- decisions/2026-07-10-mitosis-run-contract.md — exact fresh-run inputs; sourcePrefix "msp"
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell in v1).

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 notes pre-vendored fonts + skeleton status)
- .mitosis/run.json — CURRENTLY trimmed to batch 1 (18 MSPs, one compact line). NOT the full manifest anymore.
- .mitosis/run.json.pristine-backup — durable untouched 31-MSP manifest (source of truth for deriving future batches; gitignored, not committed)
- .mitosis/batch-tooling/ — trim_manifest.py (edit BATCH list) + verify_manifest.js (replays engine fold+reuse); gitignored
- .mitosis/entry-cards.plan.md — the plan whose task graph carries the harness-ownership defect
- sessions/2026-07-16-02-journal-app-design.md — latest (fold-defect root cause; run.json fixed+trimmed; batch tooling)
- sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch contract block (use its args, set mergePolicy "human-gated")
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-16-02-journal-app-design.md
- sessions/2026-07-16-01-journal-app-design.md
- sessions/2026-07-14-02-journal-app-design.md
- sessions/2026-07-14-01-journal-app-design.md
