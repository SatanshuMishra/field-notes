# Session 2026-07-24-09 — video-card-playback-controls

## Where it started
Resumed on the explicit slug `video-card-playback-controls`. Design was complete from session 08;
zero implementation existed. Verified first: branch `fix/video-card-preview-and-controls` clean at
2208285, origin/main still 5cb5bad (fresh base, no divergence), all eight thread pointers present on
disk. Ledger and repo agreed. The user directed "Go", i.e. build it.

## What shipped
Seven commits on `fix/video-card-preview-and-controls`, 19 files, +1894/-183.

- `952017e` — RED receipts, committed BEFORE any fix so the red-before/green-after trail is auditable.
  Three tests, each failing on HEAD for the right reason: a null `thumbnailMediaId` rendering the red
  placeholder; `MediaImage` with a literal null id doing the same; the play/pause control unreachable
  once playing.
- `f26b97d` — `EntryVideoPlayer` parity with `EntryAudioPlayer`: `seek`, `duration`, `positionStream`,
  plus `completed` on `VideoPlaybackState`. The value-to-state mapping was extracted into the pure
  `videoStateFromValue` (`lib/features/entry_cards/playback/video_player_impl.dart`) so it is testable
  without a platform channel. State and position emissions are deduped.
- `c5cf7de` — pure rename `LoadingMediaPlaceholder` -> `NeutralMediaPlaceholder`; the neutral crosshatch
  now serves both "not yet loaded" and "never had a poster". Kept separate from the behavior commit.
- `d433230` — the card rebuild. `VideoBody` now mirrors `VoiceBody`: eager `_prepare()` from
  `initState`, both streams subscribed, and **the widget tree is never swapped** — readiness only
  toggles whether the control's `onTap` is null. Both one-way latches (`_started`, `_surfaceReady`)
  are gone. Autoplay-on-load removed: a journal feed must not blast audio on scroll. Poster resolves
  as a Stack — neutral base, player surface above it, captured thumbnail above that until first play.
  `MediaImage` now renders neutral for an absent id; red is reserved for genuine failure.
- `a2cfa5b` + `df80d25` — `setVolume` on the interface, then the control bar: scrub bar with seek,
  `elapsed / total` readout, mute. Always visible (the hover-reveal auto-hide is deliberately a later
  step; always-visible is the correct shippable intermediate). The total-only duration chip was
  deleted — its one fact is a subset of the readout. New files `cards/video_control_bar.dart`,
  `cards/video_scrubber.dart`.
- `b6ac029` — four code-review fixes, each red-first. See below.

## Tried and failed
- **The first implementation of the completion mapping was wrong and would have shipped a regression
  of the exact defect this branch exists to close.** `videoStateFromValue` checked `isCompleted`
  before `isPlaying`. In video_player 2.13.0 `isCompleted` is derived as `position == value.duration`
  inside `_updatePosition`, which `seekTo` also calls — so `isPlaying && isCompleted` is a legal live
  state, not a stale flag. Dragging the scrubber fully right or pressing End while playing latched
  the card to `completed`, the Pause affordance vanished mid-playback, and `_hasPlayed` stopped
  latching so the poster could re-cover a playing video. The unit test written alongside it had
  ENSHRINED the wrong behavior. Both were corrected; completion now requires `isCompleted && !isPlaying`.
  This was caught by code review, not by the tests, and is the single most valuable finding of the session.
- The eager-init architecture was implemented as decided, then found to have a ceiling the decision
  record did not anticipate. See the new decision record.
- No hardware verification was attempted. Nothing in this session is confirmed on real macOS.

## Verification
- `flutter analyze` — expected clean; observed `No issues found!` at every phase boundary.
- `flutter test` — expected all green after the fixes; observed `+764: All tests passed!` on b6ac029.
  Baselines along the way: 29 tests -3 red at the receipt commit, 40 -3 after parity (proving parity
  alone could not fix the card), 45 +0 after the rebuild, 760 then 764 after the control bar and fixes.
- Each of the three defect receipts was re-run in isolation after every subsequent commit and confirmed
  green; none of the three test bodies was ever weakened or edited.
- `git fetch` + `git rev-parse origin/main` — expected 5cb5bad; observed 5cb5bad. Fresh base held for
  the whole session; no rebase needed.
- Red-first was observed and reported for every fix, including all four review findings.

## Running state
- none.

## Deferred + open
- **Hover-reveal auto-hide overlay is NOT built** — spec receipts 3, 4 and 5 (pointer reveal + 3s
  idle hide; paused and ended never auto-hide; touch tap-when-hidden reveals without toggling) are
  unwritten. Controls are unconditionally visible. The platform split and the
  `debugDefaultTargetPlatformOverride` footgun are both still ahead.
- **Decoder ceiling** — folded INTO this thread's scope by the user; see the new decision record.
- Non-null-but-unresolvable `thumbnailMediaId` still renders red over an otherwise playable video
  (`media_image.dart` treats a present-but-broken id as genuine failure, which is defensible). Nothing
  writes `thumbnailMediaId` today, so it is currently unreachable.
- `_markUnavailable()` is terminal — no retry path from any transient error.
- `VoiceBody._PlayToggle` is 40x40, below the 48px floor the video card now meets. Twin, unswept.
- Readout contrast is ~2.9:1 (`Palette.muted` on `Palette.cardWarm`), under WCAG 1.4.3's 4.5:1. This is
  a pre-existing token pairing shared with the voice card, not introduced here, but this diff makes it
  the only textual position indicator.
- Everything still open from session 08: blob backfill has not run against the live container
  (restore point `/Users/satanshumishra/field-notes-container-backup-2026-07-24`); export-ZIP
  extensions unconfirmed; integration tests still write into the real journal container; two junk
  voice entries pending human in-app deletion; merged branch `fix/media-blob-extension-playback` not pruned.

## Demoted from PROJECT.md (cap enforcement, content preserved verbatim)
State snapshot (2026-07-21):
- CAPTURE FLOWS COMPLETE (session 07): note/voice save-hang + video deadlock FIXED; 4 code-review
  touch-ups applied (finally-flash removed, single-flight timeout-dedupe, error logging, one root
  ProviderScope); the COMPLETE real-UI app test PASSES 3/3 on -d macos
  (integration_test/capture_ui_flow_test.dart drives real widgets Save->dismiss->card). analyze clean;
  full host suite 671 green. Shipped in PR #32, human-merged (origin/main c2fbefd). Live VM screenshots
  deferred; real camera/mic+TCC human-gated. See sessions/2026-07-21-07.
- LOCAL RUN ACHIEVED (macOS): Xcode 26.6 + CocoaPods 1.17.0 installed (gate cleared);
  `flutter build macos --debug` -> field_notes.app; app launches + renders the designed home screen
  against live DB data; analyze clean + 660/660 tests on integrated main. Screenshot the running app
  via the `_flutter.screenshot` VM RPC (scratchpad/vm_screenshot.dart) — `screencapture` is TCC-blocked;
  click-driving needs a Claude Desktop quit+reopen for Accessibility. Set LANG=en_US.UTF-8 for
  CocoaPods. Next phase: debug/troubleshoot.

## Pick up here
Two code tasks remain before any human hardware test is worth running, and the user folded the second
into this thread deliberately. Do the decoder gating FIRST — it is a correctness ceiling that
reintroduces the red placeholder this branch exists to remove, and it changes when `_prepare()` runs,
which the overlay work would otherwise have to be rewritten around. Then build the hover-reveal
overlay against the spec's receipts 3-5. Only then hand the branch to the human for
`flutter run -d macos` (never the raw binary) to confirm the preview frame and the controls.
