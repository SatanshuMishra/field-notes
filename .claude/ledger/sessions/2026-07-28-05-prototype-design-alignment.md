# Session 2026-07-28-05 — prototype-design-alignment

## Where it started
Continuation of the same calendar day. Session 04 handed off with all four Wave 1 MSPs implemented and pushed but nothing merged. The user merged PRs as they were opened and directed "proceed" twice, then called the hand-off.

## What shipped

**Three Cluster C MSPs are MERGED. 12 of the parent spec's 39 MSPs are now shipped** (A1-A5, B1-B4, C1, C4, C2). `main` is `8f711e9`.

| PR | MSP | Merged as | Gate that let it in |
|---|---|---|---|
| #74 | C1 streak card | `553b9ae` | 903 passed, 0 failed, analyze clean |
| #75 | C4 eyebrow + card header | `b8375c1` | 903 passed, 0 failed, incl. the 106-case playback suite unmodified |
| #76 | ledger (session 04) | `ed7c522` | 4 markdown files, zero code |
| #77 | C2 header + mood banner | `8f711e9` | 904 passed, 0 failed, analyze clean |

**Each MSP was rebased `--onto main` and REVALIDATED on its new base before its PR opened.** No green was carried across a base. C4 rebased clean over C1; C2 rebased clean over C4.

**C5 was dispatched early and is IN FLIGHT.** It depends on C4, which merged, and the slice permits concurrent implementation while serializing only shipping. See Running state.

## Verification discipline that earned its keep

- **Squash-reproduction checks passed for both merged MSPs.** `git diff --stat main <validated-tip> -- lib test` is EMPTY for C4 (`a702143`) and for C2 (`209a2d9`), proving each squash captured exactly the tip that was validated. This is the check decisions/2026-07-25-verify-squash-against-remote-tip.md exists for, after a squash silently dropped two files from this repo once.
- **The C2 test count was PREDICTED before the run.** Counting its diff gave +2 test declarations and -1 removed, net +1 over main's 903, so 904 was the expected figure and 904 is what the run returned. Predicting the number is what converts a green into evidence; the unexplained 902 -> 903 surprise in session 04 is what taught this.
- **A clean rebase was NOT treated as proof.** C2 and C4 both rewrote the same region of `today_screen.dart` — the "two coherent-but-incompatible rewrites" case git merges textually without complaint. The merged composition was read by hand and confirmed: `headerDateLabel` wiring and the 16px gap intact above `TodayFeedEyebrow`, which carries its own 18/12 margins. No gap doubled, none lost, order correct.

## Tried and failed
- **I read the working tree believing it was `main`.** After rebasing I stayed on the ledger branch, then ran `ls` / `grep` / `wc` on `.claude/ledger/*` and reported "main is coherent". Those reads were my own branch. Caught and redone with `git show main:<path>` and `git cat-file -e main:<path>`; the conclusion happened to hold. Lesson: when the working tree is on a topic branch, interrogate another ref through `git show`, never through the filesystem.
- **`pr-create` rejects non-ASCII and the first C4 attempt died on it.** The feed eyebrow and capture stamp copy both contain U+00B7 (the middle dot). The tool's rejection message enumerates several causes at once and does not name which value or which character failed. Describe such copy in prose in PR fields rather than quoting it. **C5's photo caption and C3's subtitle are the next likely tripwires.**
- No revert, no dropped stash, no deleted branch.

## Decisions and authorizations
- **Standing authorization granted by the user: `--force-with-lease` on `msp-cluster-c/*` and the ledger branches for the rest of Cluster C.** This is structural, not incidental — decisions/2026-07-28-stacked-msps-ship-sequentially.md mandates `git rebase --onto main` between merges, which necessarily rewrites the branch. Scoped to this cluster.
- No new decision record this session. The test-retarget rule recorded in session 04 was applied to C2 (seven assertions across three files) without further adjudication.

## Findings
- **`#72` was a PR this session did not open.** It carried `db6b30e` (the session-03 handoff) while `#73` carried `5d35247` (the mark-active commit) — GitHub computed `#73`'s squash as the remainder against a `main` that already had `#72`. The two partitioned cleanly; `main`'s PROJECT.md has exactly one index line per decision and no duplication. Verified rather than assumed.
- The ledger hand-off branch was cut fresh (`chore/ledger-handoff-session-18`) rather than committing onto the branch with open PR #73, because a PR's body is fixed at creation by rule and folding more content in would have made that body describe less than it carried.

## C5 COMPLETED after this log was first written

C5 was in flight when the hand-off was drafted (see Running state below, left intact as the record of that moment). It finished before the session closed and **pushed `86ad8f4` to `msp-cluster-c/c5-card-surface-body-strip`**, based on `ed7c522` — one merge behind current `main`, so it rebases before shipping. It is implemented and green but NOT validated with `fullValidationCmd` and has no PR.

- **Zero test retargets were needed** — every existing assertion passed unmodified, and `git diff --name-only <SHA> -- test/ lib/features/entry_cards/playback/` returns zero files. The 106-case playback suite ran green inside a 152-test run and is provably untouched.
- **The `MediaImage` contract for C7 is clean:** exactly one new optional parameter, `BoxBorder? border`, defaulting to null, with the framing helper an identity function when null — so `video_body.dart:673` and `media_image_test.dart:30` return byte-identical trees and need no edit. Proven by construction AND by running both video suites plus the media-image cases. N7's `CorruptMediaPlaceholder` stays reachable because the frame wraps the whole `FutureBuilder`.
- **Reused the existing `DashedDivider` primitive** rather than writing a third dashed painter, honouring §0 resolution 7 without being asked.
- **A FOURTH "Current app" defect, and this one is self-contradictory.** Slice line 281 claims `bodySerif` is currently "Newsreader **16**"; it is **13.5** (`typography.dart:63-69`) — and the slice's own §0 token table at line 52 says 13.5. The document contradicts itself, and the claimed 16 -> 13.5 delta never existed. Three consecutive MSPs have now found this column wrong.

**Two things C5 deliberately did NOT do, both needing a ruling:**

1. **The 6px monospace thumbnail caption is NOT shipped.** The prototype's caption is fed by sample data with a `label` field; the domain has no counterpart — `entry_photo.dart:12-18` has no label, and `media_blob.relPath` is a content-addressed 64-char hex shard path, not a filename. Adding one is a change to the photo attachment model, which **is OQ-6 and is still open**, and `lib/domain/**` is outside the fence. C5 refused both bad options — a dead `caption` parameter nothing populates, or an invented caption — because inventing one resolves OQ-6 unilaterally, the exact failure §6.3 warns about for OQ-3. **C5 is therefore incomplete against its own target table.** Neither its acceptance criteria nor the §5.4 visual-pass line mentions the caption, and `Type.monoThumbSans` stays unconsumed. Once OQ-6 resolves this is a few lines: one optional `caption` param beside `border`, plus a bottom-centred `Text` at padding-bottom 3.
2. **The tilt will read as scatter, not alternation.** The spec mandates "alternating by entry id parity", but `Entry.id` is a ULID string (`ids.dart:3`), not the prototype's integer. C5 folds the id's code units and branches on the sum's parity, which reproduces the prototype exactly for its own sequential sample ids — but with production ULIDs the parity is pseudo-random per card, so the feed reads as a random left/right scatter rather than strict L-R-L-R. Strict alternation needs a feed index, which lives in `today_entry_feed.dart` (C6's file) and `day_detail_entry_tile.dart` (verify-only) — both outside C5's fence. **Decide at the §5.4 pass whether scatter is acceptable;** the scrapbook effect still lands, but it is not what the spec literally describes.

## Running state
**One subagent in flight: the C5 implementer.** (Superseded — it completed, see above. Left as written for the record.)
- Worktree `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-c/c5-card-surface-body-strip`, branch `msp-cluster-c/c5-card-surface-body-strip`, cut from `main` at `ed7c522` (one merge behind current `main`).
- **At hand-off it had pushed nothing and made no edit** — `git ls-remote` found no such branch on origin and the worktree's `git status --short` was clean. It was in its read/verify phase.
- It was left running deliberately, not killed: it works in an isolated worktree, cannot merge anything, and a completed push is worth more than the tokens already spent. **A fresh session will NOT receive its completion notification.**
- **How to determine its state:** `git ls-remote --heads origin 'refs/heads/msp-cluster-c/c5-*'`. If the branch exists, treat it as a completed MSP and enter the ship loop (rebase, revalidate, PR) after reading its diff critically — no agent report will be available, so verify the fence and the `MediaImage` opt-in claim from the diff itself. If it does not exist, check the worktree for uncommitted edits, then **re-dispatch C5 from scratch** using the brief shape in this ledger.
No background shells. No `flutter run` instance.

## Deferred + open
- **C6 (`179e4b8`) is the last unmerged Wave 1 MSP and the next action.** Implemented and green on the OLD base; it must rebase `--onto main` (now two merges ahead of it) and revalidate before its PR opens.
- **C3 is now unblocked** — it depends on C2, which merged. It shares `mood_banner.dart` with C2, so it cuts from the post-C2 `main`.
- Wave 3 (C7) still waits on C5.
- The six slice defects recorded in session 04 remain unfixed in the slice document. **C3 and C7 will read the same unreliable §3 "Current app" column.** Decide deliberately whether to correct the slice before dispatching them.
- Standing and unchanged: the four `integration_test/` flows never run; the §5.4 macOS visual pass outstanding for the whole cluster, including C1's hand-transcribed flame cusp; `receipts.yml` runs unpinned third-party `shaheershoaib/receipts/enforcer@main` (chip `task_e10f4f7e`); A2/A4 blast radius never walked; the five A3 dialogs never separately opened; OQ-3 and OQ-6 open; three stale stashes; `feat/cluster-c-today-centre`, `chore/ledger-handoff-session-16` and `-17` superseded but not deleted.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.

## Pick up here
Ship C6: `git -C .fireplace-worktrees-cluster-c/c6-feed-empty-state rebase main`, run `fullValidationCmd` verbatim against the new head, open one PR via `~/.claude/lib/superpowers-parallel/mitosis-git.mjs pr-create`, wait for the human merge. Predict the expected test count from the diff BEFORE the run and check it against the result. Then ship C5 the same way (`86ad8f4`, rebase first), reading its diff critically — it is the C7 contract edge and it is knowingly incomplete on the caption. Then dispatch C3 off the post-C2 `main`; C7 last.

**Put the two C5 rulings to the user before Wave 3**: whether the unshipped 6px caption is accepted as deferred behind OQ-6, and whether pseudo-random tilt scatter is acceptable in place of strict alternation.
