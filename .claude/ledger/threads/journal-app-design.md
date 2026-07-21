---
thread: journal-app-design
status: paused
updated: 2026-07-21
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: FRESH context. Confirm 30/31 merged + all 4 shell-nav parent checkpoint refs present on origin, run the 3 pre-flights, then LAUNCH the verbatim 2026-07-11-03 human-gated block (NOT resumeFromRunId). shell-nav composes (now unblocked) -> builds -> opens a PR; validate FOREGROUND, then the HUMAN merges it -> 31/31.
branch: main
---

## Status
30/31 merged (was 26/31), 0 open PRs, origin/main = bf527a4. Only shell-nav-integration remains,
UNBUILT — parked at branch-composition, now UNBLOCKED (2 missing parent checkpoint refs recreated).

## Active Goal
Build + ship the final Field Notes v1 MSP (shell-nav-integration) via one fresh-context relaunch,
for 31/31.

## Next Step
Fresh session: verify 30/31 + the 4 checkpoint refs, pre-flight, launch the verbatim 2026-07-11-03
human-gated block. The 30 merged fast-skip via the live merged-PR reconcile; shell-nav composes off
its 4 parent checkpoints (all now present), plans, executes, opens a PR. Then validate locally
(FOREGROUND) and the HUMAN merges (gh pr merge is hook-blocked for the agent).

## Open Risks
- LOCAL main is 4 BEHIND / 2 AHEAD of origin/main (it never pulled the #27-#30 squash-merges; the 2
  ahead are ledger commits). RECONCILE local main onto origin/main BEFORE the relaunch — the engine
  cuts worktrees from the local main ref. See decisions/2026-07-16-pre-relaunch-main-reconciliation.md.
- `gh pr merge` + REST merge are HOOK-BLOCKED for all callers incl. the agent — the HUMAN merges every
  PR after the agent validates. See decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md.
- MITOSIS RELAUNCH MUST BE FRESH-CONTEXT (runs die when launched near-full; proven).
- CI IS HOLLOW FOR DART — run fullValidationCmd locally (FOREGROUND) against the PR head before merge.
- If shell-nav re-parks on composition despite the refs, fallback = authorize the engine's
  `git branch -f msp/shell-nav-integration-integration origin/main` (all 4 parents ARE in main).
- Engine checkpoint force-pushes are classifier-blocked; shell-nav has no dependents so its own
  checkpoint not persisting is harmless.

## Key Decisions
- decisions/2026-07-21-shellnav-checkpoint-refs-unblock.md — shell-nav parked on missing checkpoint
  refs (classifier-blocked pushes); recreated them non-destructively; ready for a fresh relaunch
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — the HUMAN merges every PR
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — local validation before every merge
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact base line
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main before EVERY relaunch
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated mode (merge mechanism superseded above)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories
  gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell). The reminders
  day-2 pre-arm follow-up MSP is post-31 work (needs a NEW msp id; not in this run).

## Pointers
- .mitosis/run.json — STAGED 31-msp manifest (gitignored; base + park deltas + built checkpoints)
- .mitosis/run.json.pristine-backup — untouched 31-MSP source; gitignored
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — VERBATIM launch block (flip mergePolicy to human-gated)
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- GitHub: https://github.com/SatanshuMishra/field-notes (PRIVATE). Project name is field-notes.

## Recent Sessions
- sessions/2026-07-21-02-journal-app-design.md — 26→30/31; gh-merge hook-block found; shell-nav parked+unblocked
- sessions/2026-07-21-01-journal-app-design.md — final run: 26/31, usage-limit parked 5, repo pristine
- sessions/2026-07-20-03-journal-app-design.md — 23/31; engine verified; final run staged, not launched
