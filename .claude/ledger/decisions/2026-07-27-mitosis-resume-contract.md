Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
Session 04 assumed a re-dispatch needed the harness `resumeFromRunId` cache, which is same-session-only, and expected a fresh session to re-run every MSP from scratch. That is wrong. The engine keeps its own resume state in `.mitosis/run.json`, a newline-delimited run journal folded by `node ~/.claude/lib/superpowers-parallel/fold-run-log.mjs <path>`. Run live before dispatch it reported a1-token-ladder parked at `plan-review`, a3-dialog-material-host parked at `ship`, and a2/a4/a5 parked with no stage. A separate fact cost a rejected dispatch: `worktreeRoot` is a REQUIRED input, and omitting it fails input validation in 24ms with `missing or empty required fields: worktreeRoot`.

## Decision
Re-dispatch a partially-completed mitosis run by calling the engine fresh with the SAME `spec`, `baseBranch`, `sourcePrefix` and `worktreeRoot`; the run journal resumes each MSP at its recorded stage. Fold the journal BEFORE dispatching and let the reconstructed stages, not the ledger's prose, decide whether a prefix or spec must change. Never rely on `resumeFromRunId` across sessions.

## Consequences
- Cost collapsed from 11.7h / 2.5M tokens to 81 min / 1.4M: A3 resumed at `ship`, hit the done-oracle (`gh pr view` reported PR #51 MERGED) and skipped without re-implementing; A1 resumed at `plan-review` instead of re-planning.
- An MSP resuming at `ship` never cuts a worktree, so pre-existing branches under a reused `sourcePrefix` are NOT a collision risk for it. This is the evidence that overrode the run-distinct-prefix worry for this run; `msp-cluster-a` was correctly reused. decisions/2026-07-27-source-prefix-is-run-distinct.md still governs a genuinely NEW run.
- `.mitosis/` is gitignored and local-only. The journal, and any plan fix living there, do not survive a fresh clone — the engine parks a resume whose plan artifact is missing rather than re-planning silently.
