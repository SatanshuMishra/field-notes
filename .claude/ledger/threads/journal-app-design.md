---
thread: journal-app-design
status: active
updated: 2026-07-20
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Plan batch 3 from the 10 remaining dependents (capture-photo/voice/video, today-screen, day-detail, garden-screen, settings-screen, +3) plus the reminders day-2 pre-arm follow-up. Bump .mitosis/batch-tooling MERGED set 18 -> 21 BEFORE trimming, or trim_manifest.py fires FATAL on dependsOn.
branch: main
---

## Status
21/31 merged, 0 open PRs. The staged relaunch was launched (wf_00757aaa-c12, human-gated, 34 agents, 0 errors,
9.1h): manifest reuse fired, 20 units skipped via the live merged-PR reconcile, reminders resumed at plan-review
off the rewritten plan and built all 7 tasks. PR #21 was verified locally (analyze clean, 405/405 suite, 23/23
reminders subset at HEAD 78bdb6b) and squash-merged under user consent.

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main by building downstream dependents in session-sized batches via
human-gated mitosis (agents publish green PRs; main thread merges under consent). Immediate: land reminders
to reach 21/31.

## Next Step
Plan batch 3. Bump the batch-tooling MERGED set 18 -> 21 first.

## Open Risks
- CI IS HOLLOW FOR DART (decisions/2026-07-20-ci-gates-are-hollow-for-dart.md). Neither check runs a Dart
  test; d6Pass is vacuous. Run fullValidationCmd locally against the PR head worktree before EVERY merge.
- THE GUARD FIX IS UNCOMMITTED in /Users/satanshumishra/Documents/DevLabs/.windful-ocean. If that tree is
  reverted, every mitosis launch silently full-re-decomposes with NO log line.
- Exit code 0 is NOT evidence a Node CLI ran. Pre-flight the fold CLI's stdout before every launch.
- Do NOT hand-edit run.json's base line before a launch. It must stay valid single-line JSON. Editing
  fileScope there is also INERT for a plan-review resume — the plan on disk is the only surface that reaches
  the reviewer. (Confirmed live: #21's scope grant reached the worker only via the plan document.)
- No Android SDK on this machine. The Task 2 desugaring config in #21 is verified by file content only and
  has NEVER been compiled. Do not add an Android build to receipts.config.json.
- TWO systemic conflict files now: pubspec.yaml AND macos/Flutter/GeneratedPluginRegistrant.swift. All three
  capture-* MSPs add plugins and regenerate both. Merge them one-at-a-time and regenerate, never hand-resolve.
- Classifier blocks DELEGATED `gh pr create`/`gh pr merge`; the main thread creates and merges them.
- `result.shipped` is MISLEADING; truth = `gh pr list` + `git ls-remote`.
- 16 stale worktrees remain on disk (left by user choice). Harmless for a reminders-only run; cleanup is
  destructive and must happen between runs, never mid-run.
- batch-tooling MERGED set is stale at 18 (must be 20 before batch 3); verify_manifest.js misreports
  capture-core/entry-cards as "will BUILD". Trust the live engine, not that preview.
- 3 files still carry the symlink guard defect (task chip task_ecab775c), incl. a hook that FAILS OPEN.

## Key Decisions
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — local validation before every merge; CI proves nothing
- decisions/2026-07-20-reminders-day2-prearm-followup.md — day-2+ reach deferred to a batch-3 follow-up MSP
- decisions/2026-07-20-reminders-android-desugaring-scope.md — reminders' fileScope expanded by one file
  (android/app/build.gradle.kts) so it ships the desugaring config in the same PR; CI cannot catch this
- decisions/2026-07-19-symlink-guard-defect.md — all 7 CLIs were silent no-ops; pre-flight the fold CLI
- decisions/2026-07-19-entry-cards-fix-and-batch-2.md — batch 2 scope; entry-cards fixed-and-included
- decisions/2026-07-19-pubspec-parallel-conflict.md — systemic pubspec conflict; serial union merges
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact line
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main before EVERY relaunch
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated + main-thread merge under consent
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories
  gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell).

## Pointers
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — VERBATIM launch block at lines 38-62
  (change mergePolicy to "human-gated")
- .claude/ledger/plans/2026-07-19-next-round.md — Stages A-G done for batch 2; G3/H still apply
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- .mitosis/run.json — batch-2 manifest (21 msps); reminders parked at plan-review; do NOT re-trim or hand-edit
- .mitosis/run.json.pristine-backup — durable untouched 31-MSP manifest (gitignored)
- .mitosis/reminders.plan.md — REWRITTEN this session (1372 lines, 7 tasks); ready for re-review
- .mitosis/batch-tooling/ — trim + verify scripts (MERGED set must be bumped 18 -> 20 next batch)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-20-01-journal-app-design.md
- sessions/2026-07-19-03-journal-app-design.md
- sessions/2026-07-19-02-journal-app-design.md
- sessions/2026-07-19-01-journal-app-design.md
