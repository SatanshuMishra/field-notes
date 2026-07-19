---
thread: journal-app-design
status: active
updated: 2026-07-19
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Execute plans/2026-07-19-next-round.md top-to-bottom. TAIL FIRST -> merge #18 streak-service (verify `gh pr checks 18` green), then delegate #17 data-management pubspec.yaml union-merge + merge -> 18/31. Reconcile local main onto origin/main. THEN present the batch-2 proposal (capture-core + entry-cards + reminders, with the entry-cards fix) for approval before staging/launching. Do NOT resume any prior run id.
branch: main
---

## Status
PAUSED at 16/31 merged (origin/main 6ce4189; local main 9b46d3c, now BEHIND origin by the 2 merges — reconcile before any relaunch). Batch 1 launched+completed with reuse FIRED for the first time (no window burn) via run wf_8a56361d-387: mood-picker (#15) + sound-effects (#16) merged; data-management (#17) open+DIRTY (pubspec.yaml union conflict only); streak-service (#18) open, CI running (opened from main thread after the classifier blocked the delegated ship agent's PR-create).

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main by building downstream dependents in session-sized batches via human-gated mitosis (agents publish green PRs; main thread merges under consent). Immediate: finish batch 1's tail (#17/#18 -> 18/31), then batch 2.

## Next Step
Open plans/2026-07-19-next-round.md and execute: merge #18 (CI-verify) -> union-merge + merge #17 -> reconcile local main -> present batch-2 proposal (capture-core + entry-cards + reminders) for approval -> stage (trim from pristine backup, fix verify_manifest.js hardcoded merged-count to 18, verify GO) -> clean leftover worktrees -> launch human-gated from a FRESH context.

## Open Risks
- pubspec.yaml conflicts are SYSTEMIC (decisions/2026-07-19-pubspec-parallel-conflict.md): merge batch PRs one-at-a-time, union-merge each dep-adding PR.
- `.mitosis/batch-tooling/verify_manifest.js` has a HARDCODED 14-id merged set — bump to 18 or its batch-2 preview lies. Its "line-split fallback" message is EXPECTED for batch 2 (base + park delta = 2 lines).
- entry-cards fix relies on the pristine backup's `execute` park delta being RETAINED on trim (resume re-runs Parallelize, mitosis.js:3446, regenerating the graph from the fixed plan; dropping the delta triggers a fresh Plan that overwrites the fix) — verify at execution.
- #18 receipts/D6 unverified until its PR CI completes (it parked before any CI ran). Verify green before merge.
- The engine REUSES existing worktrees/branches (mitosis.js:981) — clean the batch MSPs' leftovers before each relaunch (destructive; needs consent). New worktrees from wf_8a56361d-387 may remain.
- run.json fold is fragile: MUST stay one compact line (+ append-only JSONL deltas). Re-derive each batch FROM `.mitosis/run.json.pristine-backup`, never trim-on-trim. Launch from a FRESH (not near-full) context.
- Classifier blocks DELEGATED gh pr create/merge but ALLOWS the MAIN THREAD to with explicit per-batch consent (proven this session).

## Key Decisions
- decisions/2026-07-19-pubspec-parallel-conflict.md — systemic pubspec.yaml conflict; merge one-at-a-time + per-PR union merge
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact line (fold defect); scope batches by out-of-band trim from the pristine backup
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main onto origin/main before EVERY relaunch
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated + main-thread merge under consent
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell in v1).

## Pointers
- .claude/ledger/plans/2026-07-19-next-round.md — TURNKEY next-round plan (tail + batch 2), stages A-H
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 notes pre-vendored fonts + skeleton status)
- .mitosis/run.json.pristine-backup — durable untouched 31-MSP manifest (source of truth for deriving batches; gitignored, not committed)
- .mitosis/batch-tooling/ — trim_manifest.py (edit BATCH list) + verify_manifest.js (replays engine gate; fix hardcoded merged-count)
- .mitosis/entry-cards.plan.md — plan to edit so ONE task owns entry_cards_harness.dart
- sessions/2026-07-19-01-journal-app-design.md — latest (batch 1: reuse fired; #15/#16 merged; #17/#18 open; Fable plan)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-19-01-journal-app-design.md
- sessions/2026-07-16-02-journal-app-design.md
- sessions/2026-07-16-01-journal-app-design.md
- sessions/2026-07-14-02-journal-app-design.md
