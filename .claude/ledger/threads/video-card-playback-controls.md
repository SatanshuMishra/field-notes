---
thread: video-card-playback-controls
status: active
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
next_step: HUMAN hardware run — `flutter run -d macos`, never the raw binary. Confirm the preview frame, hover reveal, 3s auto-hide, pause/resume, and that a day with more videos than the cap degrades to neutral rather than red.
branch: fix/video-card-preview-and-controls
---

## Status
All eleven review fixes APPLIED and the hover-reveal overlay BUILT. 28 commits ahead of `origin/main`
(still `5cb5bad`), analyze clean, 856 tests green at `acf0976`, verified by the orchestrator independently
of every subagent claim. All nine completion criteria are met IN CODE; NOTHING is hardware-confirmed, which
is the single remaining gate. Branch has no upstream — never pushed. Six of nine
criteria met in code; NOTHING is hardware-confirmed. Two rounds found three CRITICALs, all fixed and
mutation-verified; a third returned APPROVE-WITH-FIXES and those eleven fixes are specified but NOT applied.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
Hand to the HUMAN for `flutter run -d macos` (never the raw binary). Confirm: a real preview frame rather
than the red placeholder; hover reveals the controls and 3s idle hides them while playing; pausing and
resuming shows them again for the full delay; replay, scrub and mute all work; and a day with more videos
than the cap degrades to neutral with an announced refusal rather than red. Only after that is any of this
real. Do NOT open another review round on `video_body.dart` — severity went CRITICAL -> CRITICAL -> MEDIUM
and every specified item is applied.

## Open Risks
- The suite was green and structurally BLIND for a whole round: every receipt drove one card at `cap: 1` against a synthetic pinned occupant, so the production path (N unpinned holders, an N+1th mounting, eviction landing mid-load) had zero coverage and hid two CRITICALs. Multi-card receipts now exist — treat any new single-card-only receipt as suspect.
- Three vacuous tests were caught by mutation, none by reading. Mutation-check every load-bearing receipt.
- First-frame-after-`initialize()` on macOS is UNVERIFIED. If blank, fill poster slot 2 via `CameraVideoRecorder._captureThumbnail` rather than redesigning — the macOS recorder writes no thumbnail (`camera_video_recorder.dart:345` vs `:77`), so slot 1 is dead there forever.
- For the overlay: `defaultTargetPlatform` reports `android` in ALL widget tests, so without `debugDefaultTargetPlatformOverride` the macOS pointer path is silently untested; controls-enabled can now go true -> false and the overlay must then force always-visible and cancel the hide timer; auto-hide conflicts with WCAG SC 1.4.13's Persistent clause (w3c/wcag#2007 open); desktop and mobile disagree on first-tap semantics, so one unconditional tap handler is wrong.
- CI runs NO Dart tests. Local validation plus a human hardware run is the only real gate.
- `video_body.dart` is 615 lines (inside the 800 ceiling, over the 200-400 target). The controller-extraction seam is where both CRITICALs lived and would make that lifecycle unit-testable without a widget tree.
- Voice cards remain uncapped with an identical eager-init shape, no retry affordance, and a 40x40 tap target below the floor the video card meets — known unswept twin.
- Readout contrast ~2.9:1 (`Palette.muted` on `Palette.cardWarm`); the new Try again chip's contrast on `Palette.dangerSurface` is unmeasured. Both pre-existing token pairings.
- Full remaining-item list, including everything inherited from session 09, is in `sessions/2026-07-24-10`.

## Key Decisions
- decisions/2026-07-24-playback-recovery-counts-as-interactive.md — recovery re-acquires WITH eviction rights
- decisions/2026-07-24-non-evicting-acquire-for-passive-mount.md — passive acquisition never evicts; kills a
  wake/evict stampede and the first-paint inversion in one change
- decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md — capped LRU registry, `initState`
  trigger unchanged, failures classified STRUCTURALLY because retryability is unreadable from the error
- decisions/2026-07-24-eager-init-decoder-ceiling.md — gating in scope, sequenced before the overlay
- decisions/2026-07-24-video-card-eager-player-and-controls.md — rebuild on the voice card's architecture
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — GitHub checks run no Dart test

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls.
- Capture-time macOS thumbnail: fallback only, if the eager first frame proves blank on hardware.
- Viewport/visibility detection (a clean later addition as a priority input to the registry). Controller
  extraction from `video_body.dart`.

## Pointers
- .claude/ledger/plans/2026-07-24-video-controls-overlay-plan.md — the executable overlay plan; SUPERSEDES the spec below wherever they disagree and lists seven corrections found against the code
- .claude/ledger/plans/2026-07-24-video-card-controls-spec.md — original spec; its w3c/wcag#2007 citation is wrong (that issue is SC 2.4.7, not 1.4.13) and its "no hand-rolled seek-then-play for replay" line is stale
- lib/features/entry_cards/cards/video_controls_overlay.dart + test/.../cards/video_controls_overlay_test.dart — the overlay, its pure predicates, and 9 receipts
- lib/features/entry_cards/playback/video_slots.dart + video_slots_provider.dart — the capped LRU registry
- lib/features/entry_cards/cards/ — video_body.dart (phase machine), video_control_bar.dart, video_scrubber.dart, video_transport.dart, voice_body.dart (the architecture mirrored)
- lib/features/entry_cards/playback/video_player_impl.dart — `videoStateFromValue`, load-bearing mapping
- test/features/entry_cards/cards/video_body_lifecycle_test.dart + support/video_card_harness.dart — slot accounting and stale-attempt receipts, and the multi-card harness
- test/features/entry_cards/cards/video_body_test.dart + media/media_image_test.dart — the three original defect receipts; byte-identical audit trail, never weaken them
- .claude/ledger/threads/post-ship-hardening.md — sibling thread, still paused

## Recent Sessions
- sessions/2026-07-24-10-video-card-playback-controls.md — gating + retry built, reviewed, eleven fixes specified
- sessions/2026-07-24-09-video-card-playback-controls.md — both original defects fixed in code and receipted
