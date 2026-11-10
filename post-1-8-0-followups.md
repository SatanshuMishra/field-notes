# post-1-8-0-followups: Post-1.8.0 follow-ups: day modal polish, launch sync and update check, page transitions, sync feedback, hover padding, modal video controls, night-sky composer, reminder schedules and late-night streak
Status: active
Updated: 2026-11-10T22:52:57.687Z
Next ids: c4 D4 R2 S1

## Goal

Prototype the owner's eight 1.8.0 follow-ups (a to h) on the design canvas, get approval, then build them with fanout as pull requests, keeping the journal identity; fix the root causes of the broken top-corner outlines and the uneven hover padding so they cannot recur.

## Done when

- [ ] c1 The owner approves prototypes for a to h on the canvas's 1.8 follow-ups page
- [ ] c2 The root causes of the broken top-corner outlines and the uneven hover padding are named with evidence and fixed in their shared primitives
- [ ] c3 Every approved change is open as a pull request with its tests passing

## Where things stand

Six boards are on the canvas page "1.8 follow-ups" and wait for the owner's approval, with four open questions: what completes a day for the streak (code counts one log, the owner described bloom plus log), whether fill-ins count only until 4 AM the next morning, the sidebar sync status form (own box or in the button row), and whether the voice room follows the light theme.

Root causes found: rounded outlines break where an opaque child is clipped only to the border's outer curve (day modal right pane, day_detail_panel.dart:487-535; five other sites); hover fills hug text because Pressable sizes its fill to its child and rows pad outside it (pressable.dart:116-129).

## Next step

Wait for the owner's answer on the 1.8 follow-ups boards and the four questions, then write fanout items from the approved boards and run fanout from origin/main.

## Decisions in force

- D1 Owner on g: the capture rooms lose the central gradient; stars stay subtle and mostly still, comets are rare, the sky has some randomness per opening, and resource use must not spike on weak devices.
- D2 A streak day needs a bloom and at least one log: Owner approved as recommended on 2026-11-10: a day counts toward the streak only with a bloom and at least one log.
- D3 Late-night fill-ins count until 4 AM, grandfathering past days: Owner approved as recommended on 2026-11-10: strict 4 AM grace; each day stores when its bloom was first picked; days that already existed are grandfathered.

## Open risks

- R1 Windows reminders: every reschedule cancels and re-adds every toast over WinRT, the path that used to crash; a second daily slot and the last call double those calls (third_party/flutter_local_notifications_windows/LOCAL_MODIFICATIONS.md).

## Settled, do not reopen

## Where the details live

- Owner's request: 2026-11-10 message with ten screenshots, items a to h
- Prototype canvas: https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m, page "1.8 follow-ups" (boards DayModal18, HoverPadding, SyncStatus, Transitions, NightSky, Reminders); local copy in the session scratchpad artifact-files folder
- Read-only worktree at origin/main for tracing: ~/.mitosis/fireplace/explore-180
