# post-1-8-0-followups: Post-1.8.0 follow-ups: day modal polish, launch sync and update check, page transitions, sync feedback, hover padding, modal video controls, night-sky composer, reminder schedules and late-night streak
Status: active
Updated: 2026-11-11T00:35:56.982Z
Next ids: c4 D8 R2 S1

## Goal

Prototype the owner's eight 1.8.0 follow-ups (a to h) on the design canvas, get approval, then build them with fanout as pull requests, keeping the journal identity; fix the root causes of the broken top-corner outlines and the uneven hover padding so they cannot recur.

## Done when

- [x] c1 The owner approves prototypes for a to h on the canvas's 1.8 follow-ups page evidence: Owner, 2026-11-10: "Approved as recommended" with two tweaks (moon on the expanded late-night pill; equal collapsed rail boxes), both added to the canvas as Version 18
- [ ] c2 The root causes of the broken top-corner outlines and the uneven hover padding are named with evidence and fixed in their shared primitives
- [ ] c3 Every approved change is open as a pull request with its tests passing

## Where things stand

Fanout split a to h into ten MSPs (one PR each) from origin/main f454ef02. Reviewed, fixed and waiting for the integration check: update-launch-check (feat/update-launch-check at d9995ff4, worktree .claude/worktrees/agent-aa28e60456c8b13a7; Play builds keep the daily gate, an assumption for the PR because the store delivers Play updates) and outline-primitive (fix/outlined-surface at 80df9212, worktree .claude/worktrees/agent-a227d6afe19505c51; OutlinedSurface takes an optional padding because, unlike a bordered Container, it does not inset its child) and modal-video-transport (feat/modal-video-transport at bd9aba45, worktree .claude/worktrees/agent-a1abc2d27eedfac3c; the embedded transport steps down at narrow widths, Page keys step logs, cards keep their old layout tree) and page-transitions (feat/page-transitions at 5fc52c4d, worktree .claude/worktrees/agent-a28aae361b473ae8f; PageFadeThrough in lib/design/motion keeps one page alive; the Meadow's past-year reset runs when its page is disposed) and day-modal-tidy (feat/day-modal-tidy at 59756fe7 on 80df9212, worktree .claude/worktrees/agent-a388bf42e55a1271b; cards keep Today's cardWarm, an assumption for the PR; the step footer moved to the window and its band stays reserved whenever two or more logs are listed, so a chosen card is never hidden under it and the empty band shows its rule before a log is chosen; day_media_pane.dart loses three lines at 126-131). Second review green, with three follow-ups in its builder's hands (a sweep test over every Settings row so a wrapped row cannot put the gutter outside its fill again, a 360 dp phone check that log step captions stay on one line, and the join-scan Cancel caption's padding): hover-padding (fix/hover-padding from a03a0fc7, worktree .claude/worktrees/agent-a6532085534a30cd2; the phone list card grows 8 px and the input profile menu hangs from the full row, both for the PR; the Microphone and Speaker rows' text sits 6 px off the heading in input_panel.dart, which night-sky edits, an open problem for the PR; the bleed left Pressable, HoverFill and FocusRing; a new SettingsGutter in lib/design/settings_fields puts the 12 px gutter inside each settings row's fill, settings_screen.dart's padding shrinks by 12 and its content width grows from 680 to 704 so text stays put; it also edits about_section.dart, sync_storage_section.dart, voice_section.dart, settings_notice.dart and settings_phone_pages.dart; four golden tests fail as they already do on main). Also ready: streak-late-night (feat/streak-late-night at a5db8464, worktree .claude/worktrees/agent-a8e2daa0103a1e7ab; schema 4 adds synced bloomPickedAt, stamped only for a day that never had a bloom, so days from before it stay grandfathered; isDayComplete({hasBloom, logCount}); the over-scene pill keeps dark sage #A9C2A9 in both themes; light mode elsewhere uses a deeper sage #4F6A4F for contrast and the wide pill's second line sits under the flame-and-count row, both assumptions for the PR; the 4 AM cutoff uses the device's current time zone, a trade-off for the PR). The reminder-schedules builder is told to rebase onto a5db8464 before reporting. Also ready: the sync status box plus Sync now feedback (feat/sync-status-box at d49acdea, worktree .claude/worktrees/agent-aa8c967d5794cf1ff; syncNow returns Future<bool>; sidebar boxes sit 10 px apart; returning to the front while a cycle runs queues one more cycle so changes made elsewhere while away are fetched, kept on purpose; the failed Sync now wording shows only in the desktop status row, the phone pill is unchanged; SettingsActionButton gains a minWidth; after merging with fix/hover-padding, check SidebarSyncBox's hover fill and focus ring). Also ready: night-sky (feat/night-sky at 8979173b on 80df9212; the microphone input panel takes the voice room's inks; recorder, orb and comet colours are FieldNotesColors tokens; one accepted line in immersive/android-dark.txt where the open panel covers part of the title placeholder; worktree .claude/worktrees/agent-aea935a14e5e1a0bc; the sky lives in lib/features/capture/core/night_sky.dart on the existing viewerStage ground token; the reading room shares the note room's ground, so it shows the sky and repaints its twinkle while a note is read; tests freeze the twinkle through the debug-only debugNightSkyStill in test/flutter_test_config.dart; it also edits lib/design/glass/glass_button.dart and accessibility baselines; the light voice-room colours are the builder's picks and the light Keep pill is #4A3B2E with cream text because the board's pair falls under 4.5:1, both assumptions for the PR). Building in a worktree: reminder-schedules (feat/reminder-schedules on dd5da7a3). fix/outlined-surface and feat/update-launch-check both edit test/features/settings/sections/about_updates_test.dart.

Root causes found: rounded outlines break where an opaque child is clipped only to the border's outer curve (day modal right pane, day_detail_panel.dart:487-535; five other sites); hover fills hug text because Pressable sizes its fill to its child and rows pad outside it (pressable.dart:116-129).

## Next step

Review each finished branch against fn/fanout18/review-bar.md and send confirmed findings back to its builder; if review changes feat/streak-late-night, have the reminder-schedules builder rebase onto its new head; once every branch is green, merge all ten in one scratch worktree and run the suites they touch before opening any PR.

Needs: D1, D2, D3, D5, D6, D7, R1.

## Decisions in force

- D1 Owner on g: the capture rooms lose the central gradient; stars stay subtle and mostly still, comets are rare, the sky has some randomness per opening, and resource use must not spike on weak devices.
- D2 A streak day needs a bloom and at least one log: Owner approved as recommended on 2026-11-10: a day counts toward the streak only with a bloom and at least one log.
- D3 Late-night fill-ins count until 4 AM, grandfathering past days: Owner approved as recommended on 2026-11-10: strict 4 AM grace; each day stores when its bloom was first picked; days that already existed are grandfathered.
- D5 The voice room follows the app theme; the video recorder stays dark: Owner approved as recommended on 2026-11-10.
- D6 Rail boxes share 44 px width; late night is all sage: Owner, 2026-11-10: collapsed rail boxes all 44 wide; status, settings and sound 44 tall; streak 56 tall with the same inner padding; in late-night mode the border, flame, count, second line and moon are all sage #A9C2A9. Canvas Version 19.
- D7 Sidebar sync status is its own box that opens Sync and storage: Owner approved option A on 2026-11-10; the server address is removed. Rail sizes are in D6.

## Open risks

- R1 Windows reminders: every reschedule cancels and re-adds every toast over WinRT, the path that used to crash; a second daily slot and the last call double those calls (third_party/flutter_local_notifications_windows/LOCAL_MODIFICATIONS.md).

## Settled, do not reopen

## Where the details live

- Owner's request: 2026-11-10 message with ten screenshots, items a to h
- Prototype canvas: https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m, page "1.8 follow-ups" (boards DayModal18, HoverPadding, SyncStatus, Transitions, NightSky, Reminders); local copy in the session scratchpad artifact-files folder
- Read-only worktree at origin/main for tracing: ~/.mitosis/fireplace/explore-180
- Fanout items and plan: session scratchpad fn/fanout18 (items.json holds each leaf's task, files and acceptance; brief-day-modal-tidy.md, brief-night-sky.md and brief-reminder-schedules.md are the ready briefs for the stacked builds; rules.md holds the shared build rules and report format)
