---
thread: video-card-playback-controls
status: paused
updated: 2026-07-25
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
next_step: WAIT for the user's specific follow-up instruction on the video-card-preview. Do not begin it unprompted. The standing gate behind it is the HUMAN hardware run — `flutter run -d macos`, never the raw binary.
branch: fix/video-card-preview-and-controls
---

## Status
All eleven review fixes APPLIED and the hover-reveal overlay BUILT. 35 commits ahead of `origin/main`
(still `5cb5bad`), analyze clean, 856 tests green at `acf0976`, verified by the orchestrator independently
of every subagent claim. All nine completion criteria are met IN CODE; NOTHING is hardware-confirmed, which
is the single remaining gate. Branch has no upstream — never pushed. Three review rounds went
CRITICAL -> CRITICAL -> MEDIUM; all three CRITICALs and all eleven MEDIUM/LOW fixes are applied and
mutation-verified.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
WAIT for the user's specific follow-up instruction on the video-card-preview — it was announced at hand-off
and is not yet given. Do not begin it, and do not start the hardware run unprompted; it is the human's to
run. When it happens: `flutter run -d macos` (never the raw binary). Confirm: a real preview frame rather
than the red placeholder; hover reveals the controls and 3s idle hides them while playing; pausing and
resuming shows them again for the full delay; replay, scrub and mute all work; and a day with more videos
than the cap degrades to neutral with an announced refusal rather than red. Only after that is any of this
real. Do NOT open another review round on `video_body.dart` — severity went CRITICAL -> CRITICAL -> MEDIUM
and every specified item is applied.

## Open Risks
- The suite was green and structurally BLIND for a whole round: every receipt drove one card at `cap: 1` against a synthetic pinned occupant, so the production path (N unpinned holders, an N+1th mounting, eviction landing mid-load) had zero coverage and hid two CRITICALs. Multi-card receipts now exist — treat any new single-card-only receipt as suspect. Four vacuous or unpinned receipts have now been caught by mutation and NONE by reading, so mutation-check every load-bearing receipt; when a mutation reds nothing, ask whether the code is redundant or the coverage is missing, because both look identical from the green.
- First-frame-after-`initialize()` on macOS is UNVERIFIED. If blank, fill poster slot 2 via `CameraVideoRecorder._captureThumbnail` rather than redesigning — the macOS recorder writes no thumbnail (`camera_video_recorder.dart:345` vs `:77`), so slot 1 is dead there forever.
- Two test-infrastructure traps, both found only by running: `setUp`/`tearDown` CANNOT restore `debugDefaultTargetPlatformOverride` (invariants are checked at the end of the test body, before tearDown) — use `TargetPlatformVariant` via `variant:`; and `find.bySemanticsLabel` reads a STALE `debugSemantics` cache, returning a match at full hide — use `find.semantics.byLabel`.
- CI runs NO Dart tests. Local validation plus a human hardware run is the only real gate.
- `video_body.dart` is 672 lines (inside the 800 ceiling, over the 200-400 target). The controller-extraction seam is where both CRITICALs lived and would make that lifecycle unit-testable without a widget tree.
- Voice cards remain uncapped with an identical eager-init shape, no retry affordance, and a 40x40 tap target below the floor the video card meets — known unswept twins. A FOURTH twin was found and fixed this session (a changed `mediaId` under a stable resolver was ignored); assume more exist and sweep deliberately.
- Readout contrast ~2.9:1 (`Palette.muted` on `Palette.cardWarm`); the new Try again chip's contrast on `Palette.dangerSurface` is unmeasured. Both pre-existing token pairings.
- Full remaining-item list, including everything inherited from sessions 09 and 10, is in `sessions/2026-07-25-01`.

## Key Decisions
- decisions/2026-07-25-null-mutation-means-redundant-or-uncovered.md — decide which before acting
- decisions/2026-07-24-restart-retains-its-decoder-slot.md — `_restart` never releases its slot
- decisions/2026-07-24-denied-claim-uses-a-live-region.md — announced refusal, not a deprecated announce call
- decisions/2026-07-24-overlay-auto-hide-keeps-the-youtube-model.md — approved residual + 3 mitigations
- decisions/2026-07-24-playback-recovery-counts-as-interactive.md — recovery re-acquires WITH eviction rights
- decisions/2026-07-24-non-evicting-acquire-for-passive-mount.md — passive acquisition never evicts
- decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md — capped LRU, structural failure class
- decisions/2026-07-24-eager-init-decoder-ceiling.md — gating in scope, sequenced before the overlay
- decisions/2026-07-24-video-card-eager-player-and-controls.md — rebuild on the voice card's architecture
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls. Capture-time macOS thumbnail is a fallback only, if the eager first frame proves blank on hardware.
- Viewport/visibility detection (a clean later addition as a priority input to the registry); controller
  extraction from `video_body.dart`; touch double-tap seek; scrubber hover-thickening on desktop.

## Pointers
- .claude/ledger/plans/2026-07-24-video-controls-overlay-plan.md — the executable overlay plan; SUPERSEDES the spec below wherever they disagree and lists seven corrections found against the code
- .claude/ledger/plans/2026-07-24-video-card-controls-spec.md — original spec; its w3c/wcag#2007 citation is wrong (that issue is SC 2.4.7, not 1.4.13) and its "no hand-rolled seek-then-play for replay" line is stale
- lib/features/entry_cards/cards/video_controls_overlay.dart + test/.../cards/video_controls_overlay_test.dart — the overlay, its pure predicates, and 9 receipts
- lib/features/entry_cards/playback/ — video_slots.dart + video_slots_provider.dart (capped LRU registry), video_player_impl.dart (`videoStateFromValue`, load-bearing mapping)
- lib/features/entry_cards/cards/ — video_body.dart (phase machine), video_control_bar.dart, video_scrubber.dart, video_transport.dart, voice_body.dart (the architecture mirrored)
- test/features/entry_cards/ — cards/video_body_lifecycle_test.dart + support/video_card_harness.dart (slot accounting, stale-attempt receipts, the multi-card harness); cards/video_body_test.dart + media/media_image_test.dart (the original defect receipts — byte-identical audit trail, never weaken them)
- .claude/ledger/threads/post-ship-hardening.md — sibling thread, still paused

## Recent Sessions
- sessions/2026-07-25-01-video-card-playback-controls.md — all eleven fixes applied, a voice twin swept, the overlay built; 856 tests green
- sessions/2026-07-24-10-video-card-playback-controls.md — gating + retry built, reviewed, eleven fixes specified
