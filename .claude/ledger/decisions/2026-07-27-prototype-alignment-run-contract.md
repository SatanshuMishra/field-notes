Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
The 39-MSP alignment spec was approved and unstarted. Mitosis cuts worktrees from `origin/main`, but neither the spec nor `docs/prototype/project/Field Notes.dc.html` existed on main — and spec §7 requires every implementer to re-open each cited line against that bundle rather than trust the document.

## Decision
Land the spec and prototype bundle on main BEFORE dispatch (done: PR #48, `9fb3e7f`), then run mitosis over **Cluster A (A1-A5) only**, review the output, and re-dispatch B-H as separate runs. Inputs: `baseBranch` = `main`; `sourcePrefix` = `msp` with **no trailing slash**; `verify`/`build` from `receipts.config.json`.

## Consequences
- A single 39-MSP run was rejected: no inspection point before 39 PRs, ~15x chat tokens, and every PR needing a retitle past `pr-title-lint`. Every cluster depends on A, so A-first costs nothing in ordering.
- The trailing-slash form `msp/` is a known run-1 failure — the engine appends `/` itself (`mitosis.js:1293`), producing the invalid ref `msp//...`. Recorded in `decisions/2026-07-10-mitosis-run-contract.md`; the option label offered at ruling time wrongly carried the slash and is corrected here.
- Rebasing the spec branch onto main was rejected once `c70ce82` and `8ceeb04` proved to postdate the PR #46 squash; cherry-pick onto current main plus a surgical restore of four stranded ledger files was used instead.
- Generalises: any spec whose implementers must verify against an in-repo source must have BOTH on the base branch before dispatch, because worktrees see only base.
