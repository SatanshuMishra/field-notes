---
thread: video-card-playback-controls
status: paused
updated: 2026-07-26
priority: high
completion_criteria:
  - A video card shows a real preview frame before playback, never the red corrupt placeholder, human-confirmed on macOS hardware
  - A played video can be replayed, paused, scrubbed and muted from the card, human-confirmed
  - Red placeholder appears only on genuine media failure, never for an absent poster
  - EntryVideoPlayer reaches parity with EntryAudioPlayer (seek, positionStream, duration, completed)
  - Video controller init is gated so a day of video entries cannot exhaust the device decoder ceiling
  - _markUnavailable distinguishes retryable decoder unavailability from genuine corruption, with a retry path
  - Hover-reveal overlay behaves per spec on macOS pointer AND Android touch, with the macOS path covered by a test that overrides defaultTargetPlatform
  - Every control meets the 48x48 logical-px tap-target floor and is keyboard reachable with a Semantics label
  - Red-before-green receipt exists for each of the two reported defects
next_step: Merge the session-07 handoff PR (it carries the spec amendment the workers must see), fast-forward local main, then dispatch mitosis for MSP 3 with sourcePrefix "msp" (bare token). Then the macOS hardware run, the only thing that can close this thread.
branch: main (ledger + spec amendment on chore/ledger-handoff-session-07)
---

## Status
All nine criteria met IN CODE. MSPs 1+2 SHIPPED (PRs #41, #44). MSP 3 is DISPATCH-READY: its plan's
round-3 adversarial findings are fixed (the anti-Option-B wobble claim verified false against the Flutter
source and retracted), the blocking Step 0 ruling was obtained pre-dispatch (Option B, shrink-to-fit),
and the spec's Phase 2 amendment ratifying bounded-position shrinkWrap is written — but uncommitted,
riding the session-07 handoff branch. The macOS hardware run has still never happened; DoD refuses done.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
ORDERING IS LOAD-BEARING: (1) merge the session-07 handoff PR — it carries the spec's Phase 2 amendment,
and the engine cuts worker worktrees from the bare LOCAL main ref, so an undispatched amendment means
plan-review re-rejects against the unamended spec :154; (2) fast-forward local main; (3) dispatch mitosis
for MSP 3 only, sourcePrefix "msp" (bare token, no slash). The plan's Step 0 is already RESOLVED (Option B
ruling recorded verbatim in the plan) — no mid-run human gate remains. After MSP 3: the macOS hardware run
closes the thread; MSP 4 stays unauthorized pending a post-Phase-1 profile.

## Open Risks
- Merged-but-unconfirmed remains the live hazard: poster-first is fully on main, yet no human has run the
  app on macOS hardware. CI runs NO Dart tests; only local fullValidationCmd at an echoed TREE:/HEAD: counts.
- Squash merges strand unpushed commits: hit again this session (PR #43 vs local a912055; recovered by
  cherry-pick). Push the ledger branch right after every ledger commit; scope strand-check diffs to the
  branch's own file class once multiple merges have landed.
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target); video_body.dart is
  ~700 lines, its controller-extraction seam where both CRITICALs lived.
- The missing EntriesDao pagination and the unreceipted responsive band are carried in the spec — read it.

## Key Decisions
- decisions/2026-07-26-day-detail-shrinkwrap-option-b.md — MSP 3 ships shrinkWrap shrink-to-fit; spec rejection scoped to unbounded positions
- decisions/2026-07-25-didupdatewidget-gate-ratified-as-amendment.md — gate covers BOTH passive entry points; Task 3 form supersedes staysGated
- decisions/2026-07-25-poster-first-supersedes-eager-decode.md — poster-first root fix; cap stays 6 global
- decisions/2026-07-25-source-prefix-is-a-bare-token.md — pass `msp`; the engine adds the slash
- decisions/2026-07-25-verify-squash-against-remote-tip.md — diff main vs tip before deleting a branch
- decisions/2026-07-25-video-preview-width-driven-and-cover-filled.md — 21:9 from width, floor, cover fill
- decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md — capped LRU + structural failure class
- The four 2026-07-24 slot-lifecycle records are indexed in PROJECT.md; load on demand.
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls.
  Controller extraction from `video_body.dart`; touch double-tap seek; scrubber hover-thickening.
- Any thumbnail backfill or file-based frame extractor: current data is temporary, purged before release.
  Editing the vendored `third_party/camera_macos` source.
- MSP 4 (Today virtualization) stays unauthorized, conditional on a post-Phase-1 profile.

## Pointers
- docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md — the 4-MSP spec (Phase 1b now carries the ratified amendment)
- .mitosis/day-detail-feed-virtualization.plan.md — MSP 3's plan, needs editing before relaunch
- lib/features/entry_cards/cards/video_body.dart — the gate + _deferDecodeUntilIntent live here
- Sibling thread: .claude/ledger/threads/post-ship-hardening.md, still paused

## Recent Sessions
- sessions/2026-07-26-01-video-card-playback-controls.md — MSP 3 plan fixed, Option B ruled pre-dispatch, spec amended
- sessions/2026-07-25-06-video-card-playback-controls.md — MSP 2 salvage: ratified, Task 3, PR #44 merged
