# recorder-android-followups: Fix the three Android live-pass findings in the immersive recorders
Status: active
Updated: 2026-10-17T05:49:35.162Z
Next ids: c5 D3 R5 S6

## Goal

Fix the three defects the 2026-09-28 Android live pass found in the full-window video recorder (shipped in #229 and #231): the self-view-off notice claims the camera is recording while paused, the Leave control merges into a full-screen TalkBack node while the let-go panel is open, and the camera chip truncates the camera name on phones. Each fix ships with a test that fails without it, then gets a live check on the phone.

## Done when

- [ ] c1 With self-view off, the video recorder's notice never says the camera is recording while the recorder is paused, and it keeps the spec 16.18 wording while recording.
- [ ] c2 With the video let-go panel open, no full-window node is exposed to accessibility as a button labelled Leave; Leave is its own node (or disabled, matching voice).
- [ ] c3 On a 411 dp wide phone in the bottom-bar layout, the idle video recorder's camera chip shows a readable camera name instead of 'Back cam…'.
- [ ] c4 Nothing else breaks.

## Where things stand

Converted from the old ledger.

## Next step

Ask the owner what the self-view-off notice should say while paused (spec 16.18 only defines the recording wording), then start with the TalkBack defect in lib/features/capture/immersive/recorder_surface.dart at `_leave()` (the `Semantics(button: true, label: recorderLeaveLabel)` around line 264): write the failing semantics test for the video asking state first, and decide with it whether video Leave should be disabled while the let-go panel is open, as voice already does (video_recorder_sheet.dart line 288 versus voice_recorder_sheet.dart line 202).

## Decisions in force

- D1 Defer the three Android live-pass findings to a parked thread: Deferred. The owner said: "Open a new logbook thread. Defer the above issues for later implementation. Do not pick-up the new Logbook thread. Leave it parked." The thread is recorder-android-followups and stays parked until the owner resumes it.
- D2 Defer the three Android live-pass findings to a parked thread: Deferred. The owner said: "Open a new logbook thread. Defer the above issues for later implementation. Do not pick-up the new Logbook thread. Leave it parked." The thread is recorder-android-followups and stays parked until the owner resumes it.

## Open risks

- R1 Issue 1 detail: the notice text is the constants videoSelfViewOffTitle ('The camera is still recording.') and videoSelfViewOffMessage ('You just won’t see yourself.') at video_recorder_sheet.dart lines 36-37, drawn by _selfViewOffCopy (around line 356) whenever self-view is off (line 350, `if (hidden)`), regardless of phase. Seen live: self-view off, status 'Paused. Nothing’s lost.', notice still 'The camera is still recording.' Spec 16.18 defines only the recording wording, so the paused wording is an owner decision (for example 'Recording is paused. You just won’t see yourself.', or hiding the title while paused). Bears on c1.
- R2 Issue 2 detail and unverified hypothesis: uiautomator in the video recorder's asking state (paused, let-go panel open, bottom bar) showed one clickable 1080x2195 node labelled 'Leave / What do you want to remember about today?' and no separate Leave node; in idle and recording, Leave was its own 126x126 node, and voice's asking state keeps a separate disabled Leave. The Leave control's Semantics in recorder_surface.dart `_leave()` (around line 264) has button, enabled and label but no container: true, so when its sibling nodes change in the asking state its configuration likely merges up into the full-window node. Video also keeps Leave enabled while asking (video_recorder_sheet.dart line 288, `onLeave: _isSaving ? null : widget.onLeave`), while voice disables it (voice_recorder_sheet.dart line 202, `_saving || asking ? null : onCancel`). Confirm with a semantics test before fixing. Bears on c2.
- R3 Issue 2 overlaps a separately queued screen-reader task from session a22e2001 (task_4dc1b80e): the recorders' static text merges into the full-window node's accessible name (the question and privacy text read as the area's label) and the no-camera message is not its own node. Both touch semantics in recorder_surface.dart; do them together or sequence them so two branches do not rewrite the same Semantics wrappers. Bears on c2.
- R4 Issue 3 detail: the chip is CameraPicker (camera_picker.dart `_face`, a Flexible Text with maxLines 1 and TextOverflow.ellipsis), placed Flexible in video_recorder_sheet.dart `_trailing` (around line 384) beside SelfViewChip, and shown only while idle with more than one camera. In the bottom-bar top band it got 240x126 px (about 91 dp) next to 'Only you' and 'Mirror on', so 'Back camera 1' rendered as 'Back cam…'. The chip was restyled in the immersive-video Lane (commit 4678b3d). Check the prototype's phone video recorder in docs/prototype/project/Field Notes.dc.html before choosing between short names (Back, Front), an icon-only chip, or more width. Bears on c3.

## Settled, do not reopen

- S1 Out of scope: Owner design call, pending: keep the reflection kicker at the default macOS window (question 23.4 px on one line, as shipped in #231) or hide the kicker first so the question grows to 31-38 px.
- S2 Out of scope: Owner design call, pending: in the video recorder, Command-Return still keeps the take while the 'Let this one go?' panel is open, while voice turns it off there; the key hint describes it truthfully since #231.
- S3 Out of scope: Live checks not yet done for the onboarding, recorders and settings spec: the Android 13+ notification prompt on skip (the test phone is Android 12), a hardware keyboard on Android (16.17, via the uhid method in the testing memory), an actual TalkBack run (the pass read the uiautomator tree only), side-by-side comparison with the prototype screenshots (16.9, 16.23, 16.40), the Data-tab notice persisting across tabs (16.6, needs Delete all on test data), macOS live video with a real camera (the Parallels guest has none), and the device integration tests integration_test/capture_ui_flow_test.dart and the composer probe.
- S4 Out of scope: Pre-existing observation, not from this work: under gesture navigation on the test phone, uiautomator clips every node at y=2195 px, so bottom-edge controls (the shell bottom bar at 26.7 dp, the onboarding footer buttons at 37.7 dp) read below 48 dp; judge on a 3-button-navigation device or from code before treating it as a defect.
- S5 Out of scope: Housekeeping outside this thread: run `receipts doctor` for the stale receipts.config.json; the owner's uncommitted prototype files under docs/prototype/project and tool/probe/macos/drive.sh on the main checkout; three unrelated worktrees under .claude/worktrees (admiring-lamport-a13fd7, serene-sutherland-8825a1, upbeat-bhabha-6b686f); eight old local fix/* branches; the testkit's android-probe-build.patch no longer applies (android-plain-build.patch replaces it for plain builds).

## Where the details live

- Approved spec for onboarding, recorders and settings (local, git-ignored): docs/specs/onboarding-recorders-settings.md
- Binding decisions for that spec (local, git-ignored): docs/specs/onboarding-recorders-settings.decisions.md
- Android live-pass evidence screenshots, 2026-09-28: U+007E/.mitosis/field-notes/testkit/results/android/2026-09-28-ors-live/
- Android plain test-build patch (package dev.satanshumishra.field_notes.plain, keep-screen-on): U+007E/.mitosis/field-notes/testkit/patches/android-plain-build.patch
- Recorder fixes PR merged before this pass (question sizing, toast timing, key hints): https://github.com/SatanshuMishra/field-notes/pull/231
- Live testing method and Android pass lessons (auto-memory): U+007E/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/memory/live-macos-testing-method.md
- Video recorder sheet (self-view notice, trailing chips, leave wiring): lib/features/capture/video/video_recorder_sheet.dart
- Recorder surface (leave control semantics, top band): lib/features/capture/immersive/recorder_surface.dart
- Camera picker chip (ellipsis label): lib/features/capture/video/camera_picker.dart
- Old ledger record: thread 01M3NSE82GRQ35X2BA7PK8CYGS in refs/logbook/archive/ledger
