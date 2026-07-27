# Session 2026-07-27-02 — prototype-design-alignment

## Where it started
Resumed the thread via `/resume-project prototype-design-alignment` and the user directed "proceed". The thread's next step was to run mitosis against the approved alignment spec, Cluster A first. No application code had moved.

## What shipped
- PR #48 MERGED as `9fb3e7f` on main — the alignment spec, the `docs/prototype/` design bundle, the session-07 ledger handoff, and four ledger files stranded by the PR #46 squash. Branch `docs/prototype-design-alignment-spec` (deleted on merge).
- `.claude/ledger/decisions/2026-07-27-prototype-alignment-run-contract.md` — the run contract: land the spec on base first, then Cluster A only.
- The spec and `docs/prototype/project/Field Notes.dc.html` are now on main, which is the precondition for dispatch: mitosis worktrees are cut from `origin/main`, and spec §7 requires every implementer to re-open each cited line against that bundle.

Mitosis was NOT dispatched. All inputs are resolved and the blocker is cleared; the run is the next action.

## Tried and failed
- **Misread `git rev-list --left-right --count`.** Reported the branch as 2 ahead / 6 behind main; it was 6 ahead / 2 behind. The columns are left=main, right=HEAD. This made rebase look correct when it was not, and the error reached the user before being caught.
- **Assumed all four pre-spec commits were absorbed by PR #46's squash. FALSE.** `c70ce82` (17:20) and `8ceeb04` (21:36) both postdate the #46 merge (00:50 local), so the msp4-not-authorized decision, sessions `2026-07-26-02` and `-03`, and the closed state of the video-card thread had never reached main — while PROJECT.md already indexed the decision. Main had been carrying a dangling pointer and a thread file reading `paused` against an index reading `done`. Caught only by diffing the new branch against the old branch tip. Rebase was abandoned for a cherry-pick of the two new commits plus a surgical restore of the four files.
- **The first PROJECT.md conflict resolution silently lost two load-bearing State-snapshot entries** — the `pr-title-lint` note and the v1-MARKDOWN-ONLY ledger note — and reinstated three lines that had been deliberately demoted for the 80-line cap. Both came from the un-cherry-picked commits. Fixed by taking the old branch tip's PROJECT.md wholesale, which is a strict descendant of main's. Lesson: when resolving a ledger conflict, diff the result against the newest branch tip, never just check that markers are gone.
- **`gh pr merge` is blocked by a hook** (mitosis never merges; a human merges after review). Expected — already recorded in `decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md` and `decisions/2026-07-12-human-gated-merge-policy.md`. The user merged #48 manually.
- **The `sourcePrefix` option offered to the user was labelled `msp/`, with a trailing slash. That form is a known failure.** `decisions/2026-07-10-mitosis-run-contract.md` records that the engine appends `/` itself (`mitosis.js:1293`) and that `"msp/"` produced the invalid ref `msp//...`, failing run 1. The user's intent was the `msp` convention; the value to pass is `"msp"`. Corrected in the run-contract record before it could reach a dispatch.

## Verification
- `gh pr view 48` — expected MERGED; observed `state: MERGED`, `mergedAt: 2026-07-27T06:46:13Z`, `mergeCommit 9fb3e7f`.
- `gh pr view 48 --json statusCheckRollup` before merge — expected green; observed `receipts` SUCCESS and `pr-title-lint` SUCCESS. The Conventional Commits title cleared the lint that every mitosis-titled PR fails.
- `git cat-file -e origin/main:<path>` for the spec, `Field Notes.dc.html`, the msp4 decision and the prototype-design-alignment thread — expected all present after merge; observed all four ON MAIN.
- `git diff chore/ledger-handoff-session-07 --stat` after the restore — expected the only residual delta to be main's own PR #47 work; observed exactly `day_detail_panel.dart` and `day_detail_panel_test.dart`, confirming ledger content parity.
- Every `decisions/*.md` path indexed by PROJECT.md checked against disk — expected all resolve; observed no misses.
- `wc -l .claude/ledger/PROJECT.md` — expected 80 (at cap); observed 80.
- No application code changed this session, so no test suite was run and none was warranted.

## Running state
none

## Deferred + open
- **The mitosis run itself.** Not dispatched. Resolved inputs, ready to pass verbatim: `spec` = `docs/specs/2026-07-26-prototype-design-alignment.md`; `repoRoot` = `/Users/satanshumishra/Documents/DevLabs/fireplace`; `baseBranch` = `main`; `sourcePrefix` = `msp` (NO trailing slash); `verify`/`build` from `receipts.config.json`; `fixLoopMax` 2. Scope is Cluster A (A1-A5) only.
- **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model) remain open and touch no MSP in Cluster A, so neither blocks this run.
- **WIP:** two unrelated non-terminal threads now exist — `post-ship-hardening` (paused) and `prototype-design-alignment` (paused). Surfaced for disposition, not auto-closed.
- Demoted from PROJECT.md for cap enforcement (file remains on disk, content unchanged): the `docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md` pointer — 3 of its 4 MSPs shipped (#41, #44, #47) and MSP 4 / Phase 3 is CONDITIONAL and NOT authorized, requiring a post-Phase-1 hardware profile AND spec-owner review, never execution on prediction; full rationale at that spec's `:112`, `:128-131`, `:133`, `:135`, `:152`, `:159`. Now fully carried by `decisions/2026-07-26-msp4-today-virtualization-not-authorized.md`, which is in the Active Decisions index.

## Pick up here
Dispatch mitosis against `docs/specs/2026-07-26-prototype-design-alignment.md` scoped to Cluster A (A1-A5), using the inputs listed above — note `sourcePrefix` is `msp` with no trailing slash. A3 is dependency-free and fixes a shipping defect (five dialogs render Flutter's yellow debug underline because `lib/app/app.dart:20` builds `MaterialApp` with no `builder`), so it can land in parallel with A1/A2. Expect to retitle every PR the engine opens: it hardcodes `mitosis: <msp-id>`, which this repo's `pr-title-lint` rejects. Before dispatching, re-read spec §7 — line citations are pointers to verify, not authority.
