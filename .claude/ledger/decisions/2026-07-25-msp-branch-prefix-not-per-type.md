Status: accepted
Date: 2026-07-25
Thread: video-card-playback-controls

## Context
Dispatching mitosis needs one `sourcePrefix` for the MSP branches. The user proposed making it dynamic per
change type — `fix` for a bug fix, `msp` for an MSP, `feat` for a feature — and asked whether that was a
good approach.

## Decision
Use `msp/` as the single branch prefix for a mitosis run, and keep semantic types where they actually pay
off: the Conventional Commit type on every commit and on the squashed PR title.

## Consequences
A branch prefix marks which BATCH work belongs to while in flight; the commit type records what the change
IS. Splitting branches into feat/fix/perf scatters one coordinated batch across `git branch` and the GitHub
dropdown exactly when the "these ship together, each must leave main green" signal matters most. Mitosis
also takes `sourcePrefix` as a scalar, not a per-MSP function, so dynamic is not expressible without
overriding the skill contract. REJECTED: per-type branch prefixes (loses batch identity, unsupported by the
contract); a bare `feat/` (these three are a mix of gap-fill, defect and perf, so no one type is honest).
