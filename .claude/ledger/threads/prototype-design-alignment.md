---
thread: prototype-design-alignment
status: paused
updated: 2026-07-28
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: C5 is validated and OPEN as PR #82 (head `183b6b5`, 904 passed / 0 failed, analyze clean) awaiting HUMAN merge — never a second MSP PR until it lands. Put C5's two rulings to the user now: the unshipped 6px caption behind OQ-6, and tilt scatter vs strict alternation. After the merge: C3 off the post-C2 main (C3's only edge is C2, not C5), then C7 last, after C5.
branch: main `c88bd3f`; C5 open as PR #82 from `msp-cluster-c/c5-card-surface-body-strip-rebased` `183b6b5`
---

## Status
**13 of the parent spec's 39 MSPs are merged** (A1-A5, B1-B4, C1 #74, C4 #75, C2 #77, C6 #80). `main` is `c88bd3f`. **C5 is the 14th: validated and open as PR #82, NOT merged** — head `183b6b5`, 904 passed / 0 failed, analyze clean, the count predicted before the run and the rebase proven patch-identical across five intervening merges. It ships knowingly incomplete on its 6px caption. Cluster C Wave 1 is CLOSED. Mitosis is excluded for the WHOLE remaining spec, not just Cluster C.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Get PR #82 merged by the user, then C3 off the post-C2 main; C7 last, after C5. The slice's §0 SERIALIZATION declares the lib-file edges but does NOT cover test files — compute test overlap yourself before any parallel dispatch.

## Open Risks
- **`git push --force-with-lease` is classifier-blocked for the MAIN THREAD, not only mitosis agents.** Proven this session. The mandated rebase-between-merges makes every remaining MSP need it. Workaround is a `-rebased` ref (decisions/2026-07-28-agent-force-push-blocked-ship-via-new-ref.md); it leaves an orphan branch per MSP. **Ask the user early for a `Bash(git push --force-with-lease:*)` permission rule.**
- **RESOLVED — both C5 hazards cleared by direct read.** The deleted `SizedBox(height: 12)` moved into `photo_strip.dart` as 10px + dashed `ink25` rule + 10px. And `Shadows.cardDefault` does NOT match the inherited default — that IS the change: slice `:40` and `:456` mandate `cardDefault` (ink16, offset 2,2) FROM `Shadows.card = hero` (ink20, offset 3,3). Every C5 value matches the slice's target table except the caption.
- **C5's `MediaImage` contract is VERIFIED clean by direct read**, not merely reported: `_framed` returns `content` unchanged when `border` is null, so `video_body.dart` and `media_image_test.dart` render byte-identical trees. C5 touches zero test files and zero playback files. C7's edge is safe.
- **A clean rebase is NOT proof of a coherent widget.** Git merges two rewrites of one region textually without complaint. Prove it instead with the patch-identity check that cleared C6: diff the pre- and post-rebase patches over `lib`/`test`; empty means zero adaptation. Above all for C5 -> C7 on `video_body.dart`.
- **Predict the expected test count from the diff BEFORE running `fullValidationCmd`.** An unexplained number is not a green. Baseline on `main` is 904 after C2 and C6.
- **`pr-create` rejects non-ASCII and names neither the field nor the character.** Copy in this cluster uses U+00B7 and U+2014 — describe it in prose in PR fields, never quote it. C6's new message copy carries an em dash; C5's photo caption and C3's subtitle are the next tripwires.
- **The ledger's own branch-staleness figures have been wrong twice.** C6 was recorded as two merges behind and was six; C5 was recorded as two and was five. Recompute with `git log --oneline <tip>..origin/main` rather than trusting the spine — and note LOCAL `main` lags `origin/main`, so rebase onto `origin/main`.
- **C1's flame glyph is unverifiable by any automated check.** `flame_icon.dart` hand-transcribes a 24-viewBox SVG path; the test asserts only `find.byType(FlameIcon)`. Re-derivation confirmed the arc and nonZero fill. **Residual risk is the cusp at (9,8)** — a one-digit error renders as a lumpy flame, not a broken one. §5.4 must check the inner curl reads as a NOTCH, not a blob. **§5.4 must also rule on C5's tilt** — `Entry.id` is a ULID, so id-parity tilt reads as pseudo-random scatter, not the strict L-R-L-R the spec describes; strict alternation needs a feed index outside C5's fence.
- **The four `integration_test/` flows (§5.3 gate 3) have never been run** — `fullValidationCmd` excludes them. Expect pre-existing failures; triage before blaming an MSP.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **C7 lands on the most test-covered file in the repo.** The 106-case playback suite must run unmodified and green before AND after; a diff in it is a blocker, never a test to update.
- **The slice's §3 "Current app" column is unreliable — verify base state at the call site.** Wrong at slice lines `:272`, `:273`, `:276`, and `:281` (claims `bodySerif` is 16; it is 13.5, and the slice's own §0 table says 13.5). Four consecutive MSPs found it wrong. **C3 and C7 will read it.** Prototype citations, by contrast, have verified accurate everywhere checked.
- **`Shadows.card = hero` and `Shadows.button = control`** (`shadows.dart:132`, `:134`) are direct aliases — why `StickerCard`'s DEFAULT shadow already matches the prototype for C1/C2/C5.
- **C6's blast radius was closed by actual test run**, not reasoning: all eight other `EmptyStatePlaceholder` call sites green, and its new `borderRadius` default equals `DashedBorderPainter`'s own default so those sites render unchanged.
- **C4's restyled Edit/Delete are only observable in Day Detail** (`day_detail_entry_tile.dart:36-37`). Do not wire them into Today — that pre-empts OQ-3.
- **The `pr-create` tool is NOT at the repo-relative path the global rule states.** Use `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`.
- **Mitosis engine citations are STALE.** `mitosis.js` no longer exists; the engine is `.mjs` modules and `requireSha` has zero hits. The mechanism survives at `saga.mjs:63` and `run-engine.mjs:100`. Also parked: `.mitosis/run.json` is JSONL (never pretty-print it) and a spec must not be edited mid-run (`specContentHash` binds resume).
- **Serena has no Dart backend on this repo.** Use native grep/Read; do not require Serena semantic discovery here.
- **`msp-cluster-c/c6-feed-empty-state` is now stale** at the pre-rebase `179e4b8`; C6 merged from the `-rebased` ref. Expect one such pair per remaining MSP. `feat/cluster-c-today-centre` and `chore/ledger-handoff-session-16` through `-19` are superseded; three stale stashes remain. All need explicit confirmation to remove.
- **`receipts.yml` has UNPINNED actions** including third-party `shaheershoaib/receipts/enforcer@main` running with the workflow token. Chip `task_e10f4f7e`.
- The `.fireplace-worktrees-cluster-a/b/c` checkouts and their `msp-cluster-*` branches are KEPT by standing directive (decisions/2026-07-20-keep-stale-worktrees.md). Do not propose removing them.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. §7 says re-open rather than trust inherited citations.
- OQ-3 and OQ-6 unanswered. OQ-3 shipped its interim placement in C4. **OQ-6 BLOCKS a C5 target value**: the 6px monospace thumbnail caption is deliberately unshipped because the domain has no photo label (`entry_photo.dart:12-18`) and inventing one would resolve OQ-6 unilaterally — so C5 is knowingly incomplete against its own table, and `Type.monoThumbSans` is unconsumed. Put this to the user before Wave 3.

## Key Decisions
- decisions/2026-07-28-agent-force-push-blocked-ship-via-new-ref.md — force-push is classifier-blocked for the main thread; ship a rebased MSP from a new `-rebased` ref, leaving the original untouched
- decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md — every remaining cluster has an in-cluster chain, so mitosis is excluded for the whole spec, not just Cluster C
- decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md — an MSP may retarget existing assertions pinning a rendering it is mandated to change; N24's playback files stay carved out
- decisions/2026-07-28-cluster-c-skips-mitosis.md — Cluster C runs as direct `implementer` waves; the engine's ship stage parks any unit with an unmerged parent
- decisions/2026-07-28-stacked-msps-ship-sequentially.md — MSPs stacked on a shared file ship one at a time: rebase `--onto main` after each merge, revalidate on the new base, never open parallel stacked PRs
- decisions/2026-07-28-recover-stranded-checkpoints-over-redispatch.md — recover finished work from `refs/mitosis/*` and hand-ship it; never re-dispatch mitosis to re-implement what already exists
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice, not inferred by the engine
- decisions/2026-07-27-primitives-cluster-confirms-by-regression.md — a primitives-only cluster is confirmed by REGRESSION, never by prototype match
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; one cluster at a time
- decisions/2026-07-27-prototype-alignment-open-questions.md — adopt the prototype's form, never its promises; OQ-2 and OQ-7 bind Cluster C
- decisions/2026-07-22-black-window-standalone-binary.md — always run via `flutter run -d macos`, never the raw binary

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the token layer — which CLOSED with Cluster A.
- Within Cluster C specifically: no edit to `sticker_card.dart`, `media_placeholders.dart` or `lib/app/shell/**` beyond C1's one-line margin carve-out; no second hatch painter; no unifying the two dashed-border painters.

## Pointers
- docs/specs/2026-07-28-prototype-alignment-cluster-c.md — **the live slice.** §0 carries the verified token table, the hard scope fence over 16 files, seven binding primitive resolutions and the wave graph; §5.3 the regression gate; §7 the citation-trust note
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. MSP map: C1-C7 Today centre, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens. **Its §3.3 video-tile citation `:127-129` is WRONG**; the slice corrects it to `:128-130`. Clusters D-H still need slices cut
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is 904 passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-07-28-06-prototype-design-alignment.md — **C6 shipped; the force-push block and the stale engine citations are here**
- sessions/2026-07-28-05-prototype-design-alignment.md — read its C5 section before touching C5
- sessions/2026-07-28-04- / -03- / -02- / -01-prototype-design-alignment.md
