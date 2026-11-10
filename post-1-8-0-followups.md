# post-1-8-0-followups: Post-1.8.0 follow-ups: day modal polish, launch sync and update check, page transitions, sync feedback, hover padding, modal video controls, night-sky composer, reminder schedules and late-night streak
Status: active
Updated: 2026-11-10T23:13:10.163Z
Next ids: c4 D8 R2 S1

## Goal

Prototype the owner's eight 1.8.0 follow-ups (a to h) on the design canvas, get approval, then build them with fanout as pull requests, keeping the journal identity; fix the root causes of the broken top-corner outlines and the uneven hover padding so they cannot recur.

## Done when

- [x] c1 The owner approves prototypes for a to h on the canvas's 1.8 follow-ups page evidence: Owner, 2026-11-10: "Approved as recommended" with two tweaks (moon on the expanded late-night pill; equal collapsed rail boxes), both added to the canvas as Version 18
- [ ] c2 The root causes of the broken top-corner outlines and the uneven hover padding are named with evidence and fixed in their shared primitives
- [ ] c3 Every approved change is open as a pull request with its tests passing

## Where things stand

Fanout split a to h into ten MSPs (one PR each) from origin/main f454ef02. In their fix passes, each builder confirming a finding with a red test before fixing it: modal-video-transport (feat/modal-video-transport, worktree .claude/worktrees/agent-a1abc2d27eedfac3c): overflow of the full transport at the 720 px minimum window, PageUp/PageDown log stepping inside the embedded player. update-launch-check (feat/update-launch-check, worktree .claude/worktrees/agent-aa28e60456c8b13a7): rate-limited launch check never retried, 23 h drift, weakened quiet-overrides test, double request after Check now, Play builds keep the daily gate (an assumption for the PR: the store delivers Play updates). outline-primitive (fix/outlined-surface, worktree .claude/worktrees/agent-a227d6afe19505c51): stale StickerCard finder in on_this_day_open_test.dart, an optional padding parameter on OutlinedSurface (it does not inset its child the way a bordered Container does), the viewfinder's duplicate width constant, a semi-transparent-border clip test; the day-modal and night-sky builders are told to keep the inset and to rebase once the new head is ready. Building in worktrees: hover-padding (fix/hover-padding), sync status box plus Sync now feedback (feat/sync-status-box), page-transitions, streak-late-night, and, stacked on c19fe624, day-modal-tidy (feat/day-modal-tidy) and night-sky (feat/night-sky). Waiting to start: reminder-schedules stacks on feat/streak-late-night. fix/outlined-surface and feat/update-launch-check both edit test/features/settings/sections/about_updates_test.dart.

Root causes found: rounded outlines break where an opaque child is clipped only to the border's outer curve (day modal right pane, day_detail_panel.dart:487-535; five other sites); hover fills hug text because Pressable sizes its fill to its child and rows pad outside it (pressable.dart:116-129).

## Next step

When feat/streak-late-night lands, dispatch reminder-schedules on it from fn/fanout18/brief-reminder-schedules.md; when the outline fix pass commits, tell the day-modal-tidy and night-sky builders to rebase onto the new fix/outlined-surface head and use its padding parameter; review each finished branch.

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
