# post-1-8-0-followups: Post-1.8.0 follow-ups: day modal polish, launch sync and update check, page transitions, sync feedback, hover padding, modal video controls, night-sky composer, reminder schedules and late-night streak
Status: active
Updated: 2026-11-11T01:02:30.036Z
Next ids: c4 D8 R2 S1

## Goal

Prototype the owner's eight 1.8.0 follow-ups (a to h) on the design canvas, get approval, then build them with fanout as pull requests, keeping the journal identity; fix the root causes of the broken top-corner outlines and the uneven hover padding so they cannot recur.

## Done when

- [x] c1 The owner approves prototypes for a to h on the canvas's 1.8 follow-ups page evidence: Owner, 2026-11-10: "Approved as recommended" with two tweaks (moon on the expanded late-night pill; equal collapsed rail boxes), both added to the canvas as Version 18
- [ ] c2 The root causes of the broken top-corner outlines and the uneven hover padding are named with evidence and fixed in their shared primitives
- [ ] c3 Every approved change is open as a pull request with its tests passing

## Where things stand

Fanout split a to h into ten branches (one PR each) from origin/main f454ef02, each built in its own worktree under .claude/worktrees.

- Reviewed, fixed and ready: fix/outlined-surface 80df9212 (agent-a227d6afe19505c51); feat/update-launch-check 7aeff6dc (agent-aa28e60456c8b13a7; its new About wording retired one android-dark 2x contrast line); feat/day-modal-tidy 59756fe7 on 80df9212 (agent-a388bf42e55a1271b); feat/modal-video-transport bd9aba45 (agent-a1abc2d27eedfac3c); feat/night-sky 8979173b on 80df9212 (agent-aea935a14e5e1a0bc); feat/page-transitions 5fc52c4d (agent-a28aae361b473ae8f); feat/sync-status-box d49acdea (agent-aa8c967d5794cf1ff); feat/streak-late-night d5891f05 (agent-a8e2daa0103a1e7ab; the late-night tooltip link is a Pressable in a WidgetSpan, coral as before).
- fix/hover-padding 226ec6f8 (agent-a6532085534a30cd2): second review green; its follow-ups (a sweep over every Settings row, one-line phone step captions, the join-scan Cancel fill) are under a focused review, chiefly the custom render-object gutter claim in settings_gutter.dart against a simpler design. LogStepFooter is shared with feat/day-modal-tidy, so the day modal's footer tests belong in the integration run.
- feat/reminder-schedules 30933a9b on a5db8464 (agent-a00deb7378308fb28): built and under code review, including whether its new settings cards pass hover-padding's gutter rule once merged; it rebases onto d5891f05 in its fix pass.
- The eight ready branches merge cleanly in integ-180, and the other two merge cleanly on top. Every failure the full suite showed on the eight-branch merge is now fixed on its branch or already fails on main: natural_voice_chain_test and push_limits_test failed only under load and pass when rerun alone on the merge (7,579 passed, 9 failed in the full run). Five golden tests already fail on main with byte-identical images: note_float, three sticker_button and meadow_page (the last confirmed by running it on f454ef02's lib).

Root causes found: rounded outlines break where an opaque child is clipped only to the border's outer curve (day_detail_panel.dart:487-535 on f454ef02, and five other sites), fixed by OutlinedSurface; hover fills hug text because Pressable sizes its fill to its child and rows pad outside it (pressable.dart:116-129 on f454ef02), fixed by SettingsGutter.

## Next step

Review feat/reminder-schedules; trace each integration failure to its branch and send fixes to that branch's builder; once hover-padding's follow-ups land, merge all ten in integ-180, run the full suite, then push and open the ten PRs (day-modal-tidy and night-sky based on fix/outlined-surface, reminder-schedules on feat/streak-late-night) assigned to the owner.

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
- Fanout items and plan: session scratchpad fn/fanout18 (items.json holds each leaf's task, files and acceptance; review-bar.md the review criteria; rules.md the shared build rules and report format; pr-notes.md each branch's assumptions, trade-offs and open problems for its PR body)
- Integration worktree: ~/.mitosis/fireplace/integ-180 (detached, never pushed; session scratchpad integ_merge.sh merges named branches in order and stops on a conflict)
- Integration test log: session scratchpad integ8-test.log (failures-only output of the full suite on the eight-branch merge)
