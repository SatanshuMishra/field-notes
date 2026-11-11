# post-1-8-0-followups: Post-1.8.0 follow-ups: day modal polish, launch sync and update check, page transitions, sync feedback, hover padding, modal video controls, night-sky composer, reminder schedules and late-night streak
Status: active
Updated: 2026-11-11T01:57:20.819Z
Next ids: c4 D8 R2 S1

## Goal

Prototype the owner's eight 1.8.0 follow-ups (a to h) on the design canvas, get approval, then build them with fanout as pull requests, keeping the journal identity; fix the root causes of the broken top-corner outlines and the uneven hover padding so they cannot recur.

## Done when

- [x] c1 The owner approves prototypes for a to h on the canvas's 1.8 follow-ups page evidence: Owner, 2026-11-10: "Approved as recommended" with two tweaks (moon on the expanded late-night pill; equal collapsed rail boxes), both added to the canvas as Version 18
- [x] c2 The root causes of the broken top-corner outlines and the uneven hover padding are named with evidence and fixed in their shared primitives evidence: outlines broke where an opaque child was clipped only to the border's outer curve (day_detail_panel.dart:487-535 on f454ef02 and five other sites), fixed by OutlinedSurface in PR #370; hover fills hugged text because Pressable sizes its fill to its child while rows padded outside it (pressable.dart:116-129 on f454ef02), fixed by SettingsGutter and guarded by the settings gutter sweep test in PR #378
- [x] c3 Every approved change is open as a pull request with its tests passing evidence: PRs #370 to #379 open and assigned to the owner; each branch's touched test folders pass on the branch alone; all ten merged pass flutter analyze and 7648 tests, the only 5 failures being golden tests that fail on main with byte-identical images

## Where things stand

Ten PRs are open from origin/main f454ef02, assigned to the owner, with Auto-fix watching CI, conflicts and comments:

| PR | Branch | Base |
|---|---|---|
| #370 | fix/outlined-surface | main |
| #371 | feat/update-launch-check | main |
| #372 | feat/modal-video-transport | main |
| #373 | feat/page-transitions | main |
| #374 | feat/sync-status-box | main |
| #375 | feat/streak-late-night | main |
| #376 | feat/day-modal-tidy | fix/outlined-surface |
| #377 | feat/night-sky | fix/outlined-surface |
| #378 | fix/hover-padding | feat/day-modal-tidy |
| #379 | feat/reminder-schedules | feat/streak-late-night |

Each branch's builder worktree under .claude/worktrees still holds it, for fixes.

Device pass in progress, owner-approved: Android on the owner's test Note 10+ (serial RF8MA2NA3ZM, which the owner said can be used freely), macOS and Windows in the VM lab. It tests the ten-branch merge: local profile builds "Field Notes Lab" from ~/.mitosis/fireplace/devpass-180 (lab app ids, never pushed); the Windows installer comes from release.yml dispatched on the scratch branch lab/devpass-180 (signed merge 816d332a, same tree), because winpc is offline. Delete lab/devpass-180 from origin when the pass ends. The owner made onboarding's reminder choices a pre-merge check: the code and reminder_chapter_test already show Evenings, Midday and evening, Custom time and Not now, and the finish step saves the schedule; still to be seen on each device.

Follow-ups left for later, named in their PR bodies: the Microphone and Speaker rows (input_panel.dart _PanelRow) sit 6 px off their heading, fixable once #377 and #378 merge; the onboarding FakeJournalRepository in test/app/support/app_shell_harness.dart lacks setMoodForDate, as on main.

## Next step

Fix whatever Auto-fix reports on its PR's branch, checking the PR is still open before pushing; once the owner merges, stacked PRs merge in opened order with merge commits.

Needs: D1, D2, D3, D5, D6, D7, R1.

## Decisions in force

- D1 Owner on g: the capture rooms lose the central gradient; stars stay subtle and mostly still, comets are rare, the sky has some randomness per opening, and resource use must not spike on weak devices.
- D2 A streak day needs a bloom and at least one log: Owner approved as recommended on 2026-11-10: a day counts toward the streak only with a bloom and at least one log.
- D3 Late-night fill-ins count until 4 AM, grandfathering past days: Owner approved as recommended on 2026-11-10: strict 4 AM grace; each day stores when its bloom was first picked; days that already existed are grandfathered.
- D5 The voice room follows the app theme; the video recorder stays dark: Owner approved as recommended on 2026-11-10.
- D6 Rail boxes share 44 px width; late night is all sage: Owner, 2026-11-10: collapsed rail boxes all 44 wide; status, settings and sound 44 tall; streak 56 tall with the same inner padding; in late-night mode the border, flame, count, second line and moon are all sage #A9C2A9. Canvas Version 19.
- D7 Sidebar sync status is its own box that opens Sync and storage: Owner approved option A on 2026-11-10; the server address is removed. Rail sizes are in D6.

## Open risks

- R1 Windows reminders: every reschedule cancels and re-adds every toast over WinRT, the path that used to crash; #379 diffs bookings so only changed reminders are touched, but it was not tried on Windows (third_party/flutter_local_notifications_windows/LOCAL_MODIFICATIONS.md).

## Settled, do not reopen

## Where the details live

- Owner's request: 2026-11-10 message with ten screenshots, items a to h
- Prototype canvas: https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m, page "1.8 follow-ups" (boards DayModal18, HoverPadding, SyncStatus, Transitions, NightSky, Reminders); local copy in the session scratchpad artifact-files folder
- Fanout items and plan: session scratchpad fn/fanout18 (items.json each leaf's task, files and acceptance; review-bar.md the review criteria; rules.md the shared build rules; pr-notes.md each branch's assumptions, trade-offs and open problems; pr_fields.py and final/ the rendered PR bodies)
