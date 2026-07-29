# Session 2026-07-28-07 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The Resumption Brief flagged three drifts against the ledger; the user answered "Go" and the session shipped C5 end to end, then answered the three rulings the thread had been holding, then called the hand-off.

## What shipped

**C5 is validated and OPEN as PR #82 — NOT merged.** 13 MSPs remain merged (A1-A5, B1-B4, C1, C4, C2, C6); C5 is the 14th awaiting a human merge.

| Artifact | Where |
|---|---|
| C5 PR #82, head `183b6b5`, base `main` | `msp-cluster-c/c5-card-surface-body-strip-rebased` |
| Ruling: C5 ships as-is (caption + tilt) | decisions/2026-07-28-c5-ships-as-is.md |
| Ruling: force-push permission granted | decisions/2026-07-28-force-push-permission-granted.md |
| Supersession (Status line only) | decisions/2026-07-28-agent-force-push-blocked-ship-via-new-ref.md |
| Ledger commit `8b7099a` | branch `chore/ledger-handoff-session-21` (pushed, no PR) |

The rebase went to a NEW ref per the standing workaround, so `msp-cluster-c/c5-card-surface-body-strip` is untouched at `86ad8f4`. No force-push was attempted this session, so the classifier was never re-tested.

## Tried and failed

- **The ledger's staleness figure was wrong for the THIRD time.** C5 was recorded as "one, now two" merges behind; it was FIVE. Root cause found this session: LOCAL `main` was stale at `8098e5c` while `origin/main` was `d6d2d2d`, and `origin/main` advanced again to `c88bd3f` (#81, the session-20 ledger PR) during the session's own `git fetch`. Rebase onto `origin/main`, never local `main`.
- **The planned cap fix was not available.** PROJECT.md went to 81/80 lines because fixing a genuine defect (see below) cost a line. The principled fix — dropping a superseded record from the Active Decisions index — turned out not to apply: `2026-07-25-source-prefix-is-a-bare-token.md` is superseded on disk but is only REFERENCED inside its successor's index line, never independently indexed. The index was already compliant. Fell back to demoting the two terminal threads (below).
- **PROJECT.md had a structural defect:** the `video-card-playback-controls` index entry was concatenated onto the end of the `prototype-design-alignment` entry with no newline, so that thread was invisible in the Threads index. Split into two proper lines; that split is what pushed the file to 81.
- No revert, no dropped stash, no deleted branch, no force-push.

## Verification

- **`fullValidationCmd` verbatim against the rebased head `183b6b5` — 904 passed, 0 failed, `flutter analyze` "No issues found!"** (background shell `bys2l5vnd`, exit 0).
- **904 was PREDICTED before the run.** C5's diff touches zero test files and adds zero `test(`/`testWidgets(` declarations, so the count had to equal main's 904 baseline. It did.
- **Rebase patch-identity is EMPTY:** `diff <(git diff ed7c522..86ad8f4 -- lib test) <(git diff c88bd3f..183b6b5 -- lib test)` produced nothing, proving five merges of replay needed zero adaptation. Separately, no commit on main since merge base `ed7c522` touches any of C5's four files, so the two-incompatible-rewrites hazard did not arise.
- **PR #82's head SHA equals the locally validated tip** byte-for-byte, and it is the only open PR.
- **The deleted 12px gap is CONFIRMED moved, not lost.** `entry_card.dart` drops `SizedBox(height: 12)`; `photo_strip.dart` opens with 10px + `DashedDivider(1px, ink25)` + 10px.
- **`Shadows.cardDefault` resolves OPPOSITE to the ledger's hypothesis.** It does NOT match the inherited default: `StickerCard`'s default is `Shadows.card = hero` (ink20, offset 3,3) and C5 passes `cardDefault` (ink16, offset 2,2). Slice `:40` and `:456` mandate exactly that change ("from 3px at .2"). Same for radius (14 from 16) and padding (13/15 from `all(16)`) — all three explicit params are mandated changes, not restatements of a default.
- **`MediaImage`'s border is genuinely opt-in, verified by direct read at all three call sites.** `video_body.dart:673` and `media_image_test.dart:30` pass no `border`, so `_framed` returns `content` unchanged. C7's contract edge is clear.
- Every other C5 value matches the slice's C5 target table: thumb 56 (from 72), `radiusThumb` 9 (from 11), 1.5px ink border, gap 8, tilt -0.5/+0.4, `softWrap` with clip.

## Running state
None. Background shell `bys2l5vnd` (validation) completed, exit 0. No `flutter run`. No subagents dispatched this session.

## Deferred + open

- **PR #82 needs a HUMAN merge.** No second MSP PR until it lands. After the merge: C3 (its only edge is C2, already in — NOT C5), then C7 last.
- **The `Bash(git push --force-with-lease:*)` rule was granted by the user but NOT yet added to settings.json, and NOT proven.** The block is a classifier, not a permission, so the rule is expected but unverified to clear it. The agent deliberately did not self-edit its own permission boundary. Verify on C3's rebase; fall back to a `-rebased` ref if it still fires.
- **Demoted from PROJECT.md for cap (files and threads unchanged on disk):** the two terminal threads' closure summaries, preserved verbatim here —
  - `journal-app-design — done — closed 2026-07-24: design, planning and the 31/31 v1 build are complete; all completion_criteria met. Post-ship bug work moved to post-ship-hardening.`
  - `video-card-playback-controls — done — closed 2026-07-26: 3 MSPs shipped (#41, #44, #47; main 096b3c3), hardware-confirmed, and all 9 criteria verified against main by a per-criterion path:line audit (zero blockers). The MSP 4 explainer was delivered and MSP 4 formally recorded as not authorized. Accepted into closure: MSP 3 was never locally validated (fullValidationCmd not run against the PR head), and play/pause + mute keyboard reachability rests on code inspection rather than a sendKeyEvent test.`
- **New orphan branch by construction:** `msp-cluster-c/c5-card-surface-body-strip` stays at pre-rebase `86ad8f4`. Joins `msp-cluster-c/c6-feed-empty-state`, the superseded `feat/cluster-c-today-centre`, `chore/ledger-handoff-session-16` through `-20`, and three stale stashes. All need explicit confirmation to remove; the user chose to clear them in one confirmed batch alongside the permission grant.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.
- Standing and unchanged: §5.4's macOS visual pass now carries TWO rulings (C1's flame cusp at (9,8) and C5's tilt scatter); the four `integration_test/` flows never run; the slice's §3 "Current app" column wrong at `:272`, `:273`, `:276`, `:281` and C3/C7 will read it; `receipts.yml` runs unpinned third-party `shaheershoaib/receipts/enforcer@main` (chip `task_e10f4f7e`); A2/A4 blast radius never walked; the five A3 dialogs never opened; OQ-3 and OQ-6 open; CI runs no Dart test so the local gate is the only evidence.

## Pick up here
Get PR #82 merged, then start C3 off the post-merge `origin/main` — C3 depends only on C2, so it does not wait on C5's content, only on the one-PR-at-a-time rule. Before the first push, add the granted `Bash(git push --force-with-lease:*)` rule and verify on C3's rebase whether the classifier still fires. C7 is last, after C5.
