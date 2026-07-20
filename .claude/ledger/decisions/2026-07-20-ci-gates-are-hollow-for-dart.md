Status: accepted
Date: 2026-07-20
Thread: journal-app-design

## Context
PR #21 (reminders) reported `receiptsPass: true` and `d6Pass: true`, and both GitHub checks were green. Neither executes a single Dart test. The `receipts` job ran 15s on ubuntu-24.04 with `actions/setup-node` + `shaheershoaib/receipts` and installs no Flutter toolchain — it enforces receipt declarations, not behavior. The D6 cluster-boundary step ran `node scripts/d6-check.cjs --base 7e7cfaa --head 78bdb6b` and logged `dependents not computed (no supported import grapher for this stack (detected: unknown))`, so it has no Dart import grapher and passes trivially on ANY change to this repo. `d6Pass: true` has therefore been vacuous for all 21 merged MSPs, not just this one.

## Decision
Before merging any MSP, run `fullValidationCmd` locally against the PR head worktree and read the actual counts. Never accept `receiptsPass` / `d6Pass` from the engine result, or a green GitHub check, as evidence that the code works. This sits alongside the existing lesson that `result.shipped` is misleading and that exit code 0 is not evidence a Node CLI ran.

## Consequences
Adds one local validation run (~1 min) per merge; it is the only gate with real signal, so the cost is not optional. For #21 it ran green at HEAD 78bdb6b: `flutter analyze` "No issues found!", full suite `00:12 +405: All tests passed!`, reminders subset `00:00 +23`, matching the plan's expected 23. Rejected alternative: adding a Flutter toolchain to CI — correct in principle, not attempted here, and it would still not cover Android (no SDK on this machine; an Android build in `receipts.config.json` remains forbidden because it would break every gate for every MSP). Until CI gains Flutter, "green PR" means only "the branch is well-formed".
