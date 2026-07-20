---
thread: journal-app-design
status: paused
updated: 2026-07-19
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Before any relaunch, run the three pre-flight checks (guard fix present in .windful-ocean working tree; fold CLI returns non-empty output with the expected msp count; local main reconciled onto origin/main). Then edit .mitosis/reminders.plan.md against its adversarial-review findings and relaunch on the SAME run.json to land 21/31.
branch: main
---

## Status
PAUSED at 20/31 merged (origin/main 146751e), no open PRs. Batch 2 delivered capture-core (#19) and
entry-cards (#20); reminders parked at plan-review after its adversarial review failed to converge
in 3 iterations. The session's main work was root-causing and fixing a symlink defect that made all
7 mitosis CLIs silent no-ops.

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main by building downstream dependents in session-sized
batches via human-gated mitosis (agents publish green PRs; main thread merges under consent).
Immediate: unpark reminders to reach 21/31.

## Next Step
Run the three pre-flight checks, then fix .mitosis/reminders.plan.md against its review findings and
relaunch on the same run.json (reminders resumes at plan-review, before Parallelize).

## Open Risks
- THE GUARD FIX IS UNCOMMITTED in /Users/satanshumishra/Documents/DevLabs/.windful-ocean. If that
  tree is reverted, every mitosis launch silently full-re-decomposes with NO log line.
- Exit code 0 is NOT evidence a Node CLI ran. Pre-flight the fold CLI's stdout before every launch;
  the engine's own logs cannot catch this failure.
- 3 files still carry the same defect (task chip task_ecab775c), incl. hooks/block-inline-engine.mjs
  which is a blocking hook and therefore FAILS OPEN.
- pubspec.yaml conflicts are SYSTEMIC. reminders adds flutter_local_notifications + timezone and will
  go dirty against a main that now carries just_audio + video_player; apply the union procedure.
- Classifier blocks DELEGATED `gh pr create`/`gh pr merge`; the main thread creates and merges them.
- `result.shipped` is MISLEADING (it lists fast-skips); truth = `gh pr list` + `git ls-remote`.
- Engine reuses leftover worktrees and cuts them from LOCAL main — cleanup + reconcile before EVERY
  relaunch. Local main is now behind origin/main by 2 squashes.
- run.json base must stay ONE compact line; re-derive each batch FROM the pristine backup. Do NOT
  re-trim mid-batch while reminders is parked.

## Key Decisions
- decisions/2026-07-19-symlink-guard-defect.md — all 7 CLIs were silent no-ops under the lib
  symlink; fixed with the realpath idiom; pre-flight the fold CLI before every launch
- decisions/2026-07-19-entry-cards-fix-and-batch-2.md — batch 2 scope; entry-cards fixed-and-included
- decisions/2026-07-19-pubspec-parallel-conflict.md — systemic pubspec conflict; serial union merges
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact line
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main before EVERY relaunch
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated + main-thread merge under consent
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled
  Memories gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell).

## Pointers
- .claude/ledger/plans/2026-07-19-next-round.md — Stages A-G done for batch 2; G3/H still apply
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- .mitosis/run.json — batch-2 manifest (21 msps); reminders park delta appended, do NOT re-trim
- .mitosis/run.json.pristine-backup — durable untouched 31-MSP manifest (gitignored)
- .mitosis/reminders.plan.md — the plan to fix; parked at plan-review
- .mitosis/entry-cards.plan.md — FIXED plan, now shipped; never delete (resume probes it)
- .mitosis/batch-tooling/ — trim + verify scripts (merged set must be bumped 18 -> 20 next batch)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-19-03-journal-app-design.md
- sessions/2026-07-19-02-journal-app-design.md
- sessions/2026-07-19-01-journal-app-design.md
- sessions/2026-07-16-02-journal-app-design.md
