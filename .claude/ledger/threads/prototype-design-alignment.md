---
thread: prototype-design-alignment
status: paused
updated: 2026-07-29
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Merge PR #84 (C7, 1 of 4 rows). Cluster C's execution then closes and the next move is a DECISION, not an implementation: re-scope C7's three blocked rows per decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md, or accept them deferred and cut the Cluster D slice. The section 5.4 macOS visual pass is due either way.
branch: main `3aa956f`; C7 open as PR #84 from `msp-cluster-c/c7-video-poster-chrome` `2500926`
---

## Status
**15 of the parent spec's 39 MSPs are merged** (A1-A5, B1-B4, C1 #74, C4 #75, C2 #77, C6 #80, C5 #82, C3 #83). `main` is `3aa956f`. **C7 is open as PR #84 and ships only 1 of its 4 target rows** — the container radius. Its hatch, play badge and duration chip are structurally blocked and re-scoped out. Cluster C is one merge from closed execution, with two MSPs (C5, C7) knowingly incomplete against their own tables. Mitosis is excluded for the WHOLE remaining spec.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Merge PR #84. Then decide C7's three blocked rows (re-scope vs defer) before cutting the Cluster D slice; the macOS visual pass is due and carries three rulings.

## Open Risks
- **C7's three blocked rows are a SPEC defect, not an implementation gap.** decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md carries the evidence and the recommended re-scoping. The slice's §0 resolution 6 is wrong and will mislead anyone who re-reads it: it mandates dropping `NeutralMediaPlaceholder`, which reds `video_body_test.dart:400`.
- **`CrossHatchPlaceholder`'s `hatchColor` alpha-blends at 0.5 over the ground** (`cross_hatch_placeholder.dart:73-75`). `CrossHatchVariant.video` is ALREADY byte-exact for the prototype (`hatchDark` `#D9C9AE` / `hatchMid` `#E2D3BA`, 6px/12px, 45deg). Pass no colour overrides; passing `hatchMid` yields `#EEE6D7`.
- **`git push --force-with-lease` is classifier-blocked for the MAIN THREAD.** The granted `Bash(git push --force-with-lease:*)` rule is still NOT in settings.json and still UNPROVEN — it did not bite this session only because C3 and C7 both branched off the current tip. Workaround remains a new `-rebased` ref.
- **The ledger's own branch/merge state has now been wrong FOUR times**, most recently in the opposite direction (PR #82 recorded as awaiting merge when it had already landed). The ledger is written before merges land and nothing reconciles it. **On resume, always re-check `gh pr view` and `git log origin/main` against the recorded state before acting.**
- **Predict the expected test count from the diff BEFORE running `fullValidationCmd`.** An unexplained number is not a green. Baseline on `main` is **904**.
- **N24's eight untouchable files include five under `cards/`, not just `playback/`**: `playback/video_slots_test.dart` (29), `cards/video_body_lifecycle_test.dart` (20), `cards/video_controls_overlay_test.dart` (18), `cards/video_body_test.dart` (16), `cards/video_body_slots_test.dart` (11), `cards/video_body_poster_gate_test.dart` (7), `cards/video_body_attempt_identity_test.dart` (4), `cards/video_scrubber_test.dart` (1). The fence names the list only by reference to the parent spec's N24 row; without it a `cards/` test reads as ordinary and retargetable. It is not.
- **`pr-create` rejects non-ASCII and names neither the field nor the character.** Describe copy in prose in PR fields, never quote it.
- **The slice's §3 "Current app" column is unreliable — verify base state at the call site.** Wrong at slice lines `:272`, `:273`, `:276`, `:281`. Prototype citations, by contrast, have verified accurate everywhere checked, including `:101-103` and `:128-130` this session.
- **C1's flame glyph is unverifiable by any automated check.** Residual risk is the cusp at (9,8); §5.4 must check the inner curl reads as a NOTCH, not a blob. **§5.4 also owes a ruling on C5's tilt** (`Entry.id` is a ULID, so id-parity tilt scatters rather than alternating) and now on whether C7's missing badge and chip are acceptable at rest.
- **The four `integration_test/` flows (§5.3 gate 3) have never been run** — `fullValidationCmd` excludes them. Expect pre-existing failures; triage before blaming an MSP.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **C4's restyled Edit/Delete are only observable in Day Detail** (`day_detail_entry_tile.dart:36-37`). Do not wire them into Today — that pre-empts OQ-3.
- **The `pr-create` tool is NOT at the repo-relative path the global rule states.** Use `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`.
- **Serena has no Dart backend on this repo.** Use native grep/Read; do not require Serena semantic discovery here.
- **Orphan branches now number nine**, plus three stale stashes: `msp-cluster-c/c5-card-surface-body-strip`, `msp-cluster-c/c6-feed-empty-state`, `feat/cluster-c-today-centre`, and `chore/ledger-handoff-session-16` through `-21`. All need one explicitly confirmed batch removal.
- **`receipts.yml` has UNPINNED actions** including third-party `shaheershoaib/receipts/enforcer@main` running with the workflow token. Chip `task_e10f4f7e`.
- The `.fireplace-worktrees-cluster-a/b/c` checkouts and their `msp-cluster-*` branches are KEPT by standing directive (decisions/2026-07-20-keep-stale-worktrees.md). Do not propose removing them.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. §7 says re-open rather than trust inherited citations.
- OQ-3 and OQ-6 unanswered. **OQ-6 blocks a C5 target value** (the 6px monospace thumbnail caption is deliberately unshipped because the domain has no photo label, so `Type.monoThumbSans` is unconsumed).

## Key Decisions
- decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md — C7 ships 1 of 4 rows; the badge belongs to N3, the hatch to a `media_placeholders.dart` MSP, the chip needs a product ruling
- decisions/2026-07-28-c5-ships-as-is.md — C5 ships knowingly incomplete on its 6px caption (OQ-6) and with tilt scatter deferred to §5.4
- decisions/2026-07-28-force-push-permission-granted.md — the rule is granted but unwritten and unproven against the classifier
- decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md — every remaining cluster has an in-cluster chain, so mitosis is excluded for the whole spec
- decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md — an MSP may retarget existing assertions pinning a rendering it is mandated to change; N24's playback files stay carved out
- decisions/2026-07-28-stacked-msps-ship-sequentially.md — rebase `--onto main` after each merge, revalidate on the new base, never open parallel stacked PRs
- decisions/2026-07-28-recover-stranded-checkpoints-over-redispatch.md — recover finished work from `refs/mitosis/*` and hand-ship it
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice
- decisions/2026-07-27-primitives-cluster-confirms-by-regression.md — a primitives-only cluster is confirmed by REGRESSION, never by prototype match
- decisions/2026-07-27-prototype-alignment-open-questions.md — adopt the prototype's form, never its promises
- decisions/2026-07-22-black-window-standalone-binary.md — always run via `flutter run -d macos`, never the raw binary

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the token layer — which CLOSED with Cluster A.
- Within Cluster C specifically: no edit to `sticker_card.dart`, `media_placeholders.dart` or `lib/app/shell/**` beyond C1's one-line margin carve-out; no second hatch painter; no unifying the two dashed-border painters.

## Pointers
- docs/specs/2026-07-28-prototype-alignment-cluster-c.md — **the live slice.** §0 carries the token table, the 16-file fence, seven binding primitive resolutions and the wave graph; §5.3 the regression gate; §7 the citation-trust note. **§0 resolution 6 is now known defective — see Open Risks**
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. MSP map: C1-C7 Today centre, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens. Its N24 row is the only place the eight untouchable test files are enumerated. Clusters D-H still need slices cut
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is 904 passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-07-29-01-prototype-design-alignment.md — **C3 shipped and merged; C7 partial as PR #84 with its three blocked rows evidenced; three PROJECT.md decision lines demoted here verbatim**
- sessions/2026-07-28-07-prototype-design-alignment.md — C5 validated and opened; the three rulings and the demoted terminal threads
- sessions/2026-07-28-06- / -05- / -04- / -03- / -02- / -01-prototype-design-alignment.md
