---
thread: journal-app-design
status: paused
updated: 2026-07-19
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: LAUNCH batch 2 as the FIRST major action of a fresh session, using the verbatim Workflow contract in plans/2026-07-19-next-round.md Stage F3 (mergePolicy human-gated). Staging is DONE and verified GO — do not re-stage, do not re-trim, do not resume any prior run id. Then follow Stages G-H to reach 21/31.
branch: main
---

## Status
PAUSED at 18/31 merged (origin/main 326686a; local main RECONCILED, 11 ahead / 0 behind). Batch 1
is fully closed: #18 streak-service and #17 data-management both squash-merged this session and no
PRs are open. Batch 2 (capture-core + entry-cards + reminders) is user-approved, fully staged, and
verified GO — only the launch remains, deliberately deferred to a fresh context.

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main by building downstream dependents in session-sized
batches via human-gated mitosis (agents publish green PRs; main thread merges under consent).
Immediate: launch batch 2 and merge it to reach 21/31.

## Next Step
Launch batch 2 verbatim from plans/2026-07-19-next-round.md Stage F3, as the first major action of
a fresh session. Everything upstream (tail merge, reconcile, entry-cards plan fix, tooling fix,
run.json re-derivation, destructive cleanup, assertion block) is complete and verified.

## Open Risks
- Launch MUST be from a fresh context; near-full-context launches have died repeatedly.
- If entry-cards enters a fresh Plan stage instead of resuming at `execute`, KILL the run — a fresh
  Plan overwrites the harness-ownership fix applied 2026-07-19.
- pubspec.yaml conflicts are SYSTEMIC. Batch-2 merge order: capture-core (no deps) -> entry-cards
  -> reminders LAST; reminders will go dirty after entry-cards lands. Union procedure per PR.
- Classifier blocks DELEGATED `gh pr create`/`gh pr merge`; expect pushed branches without PRs and
  create them from the MAIN THREAD (ready-made commands in Stage G2).
- `result.shipped` is MISLEADING (it lists fast-skips); truth = `gh pr list` + `git ls-remote`.
- The engine reuses leftover worktrees and cuts them from LOCAL main — cleanup + reconcile are
  mandatory before EVERY future relaunch (both already done for batch 2).
- run.json base must stay ONE compact line; re-derive each batch FROM the pristine backup.

## Key Decisions
- decisions/2026-07-19-entry-cards-fix-and-batch-2.md — batch 2 = capture-core + entry-cards +
  reminders; entry-cards fixed-and-included; garden-screen deferred to batch 3
- decisions/2026-07-19-pubspec-parallel-conflict.md — systemic pubspec.yaml conflict; merge
  one-at-a-time + per-PR union merge
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact line; scope
  batches by out-of-band trim from the pristine backup
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main before EVERY
  relaunch
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated + main-thread merge under consent
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled
  Memories gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell).

## Pointers
- .claude/ledger/plans/2026-07-19-next-round.md — TURNKEY plan; Stages A-F are DONE, resume at F3
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- .mitosis/run.json — STAGED for batch 2 (21 msps, base line + entry-cards park delta, 2 lines)
- .mitosis/run.json.pristine-backup — durable untouched 31-MSP manifest (gitignored)
- .mitosis/batch-tooling/ — trim + verify scripts (merged set now correct at 18)
- .mitosis/entry-cards.plan.md — FIXED plan; never delete (resume probes it)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-19-02-journal-app-design.md
- sessions/2026-07-19-01-journal-app-design.md
- sessions/2026-07-16-02-journal-app-design.md
- sessions/2026-07-16-01-journal-app-design.md
