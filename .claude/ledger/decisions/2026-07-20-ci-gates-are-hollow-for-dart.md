# Both CI gates are hollow for this Flutter repo — local validation is the only real gate

Status: accepted
Date: 2026-07-20

## Finding (verified on PR #21, CI run 29759729458)

Neither GitHub check executes a single Dart test. A green PR proves nothing about the code.

- `receipts` job: 15s on ubuntu-24.04 with `actions/setup-node` + `shaheershoaib/receipts`.
  No Flutter toolchain is installed. It enforces receipt declarations, not behavior.
- D6 cluster-boundary step: `node scripts/d6-check.cjs` logs
  `dependents not computed (no supported import grapher for this stack (detected: unknown))`.
  It has no Dart import grapher, so it passes trivially on ANY change to this repo.
  `d6Pass: true` is vacuous and has been for all 21 merged MSPs.

## Consequence (standing rule)

Before merging any MSP, run `fullValidationCmd` locally against the PR head worktree and read
the actual counts. Do NOT accept `receiptsPass` / `d6Pass` from the engine result as evidence.
This sits alongside the existing lesson that `result.shipped` is misleading.

For #21 this ran green at HEAD 78bdb6b: analyze `No issues found!`, full suite
`00:12 +405: All tests passed!`, reminders subset `00:00 +23` (matching the plan's 23).

## Not fixed here

Adding a Flutter toolchain to CI would close this properly but was not attempted; an Android
build in `receipts.config.json` remains forbidden (no SDK on this machine — it would break
every gate for every MSP).
