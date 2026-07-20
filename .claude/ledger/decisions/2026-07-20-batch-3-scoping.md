Status: accepted
Date: 2026-07-20
Thread: journal-app-design

## Context
10 MSPs remain. Seven are ready (all deps merged): capture-photo, capture-voice, capture-video,
today-screen, day-detail, garden-screen, settings-screen. Three are blocked: calendar-screen and
search-screen both wait on day-detail; shell-nav-integration waits on nine. The known systemic hazard is
file contention: pubspec.yaml, and now macos/Flutter/GeneratedPluginRegistrant.swift, which #21 shipped
outside any declared fileScope. All three capture-* MSPs carry pubspec.yaml in fileScope and all three add
plugins, so all three regenerate the registrant.

## Decision
Batch 3 = today-screen, day-detail, garden-screen, settings-screen. The three capture-* MSPs are deferred
to batch 4, where they get serial one-at-a-time merges with regeneration of both conflict files.

The four screens have pairwise-disjoint fileScopes (lib/features/{today,day_detail,garden,settings}/** plus
their test mirrors) and touch neither systemic conflict file, so the run has zero cross-MSP file contention
and needs no union-merge procedure. Quality over speed: mixing the three-way pubspec/registrant contention
into the same run buys nothing and makes every merge a hand-resolution. Shipping day-detail also unblocks
calendar-screen and search-screen for batch 4.

## Consequences
Remaining shape after batch 3: batch 4 = capture-photo/voice/video (serial merges) + the reminders day-2
pre-arm follow-up; batch 5 = calendar-screen, search-screen, shell-nav-integration.

The reminders day-2 follow-up (decisions/2026-07-20-reminders-day2-prearm-followup.md) is NOT in batch 3.
It cannot ride the `reminders` unit id — that unit has a merged PR and the live merged-PR reconcile skips it
at the top of runUnit(), so added tasks would never build. It needs a NEW msp id, which means hand-authoring
a 32nd entry into run.json.pristine-backup; trim_manifest.py FATALs on any KEEP id absent from the base.
That mutates the manifest whose reuse path is the most fragile part of this pipeline (the fold defect cost
two sessions). Batch 3 is kept a pure trim-only operation — the exact shape proven end-to-end on 2026-07-20
— so that a novel manifest mutation is never confounded with a 4-MSP parallel build. The follow-up MSP is
authored in batch 4, against a snapshot-preserved copy of the 31-MSP backup.

Note: no screen MSP has pubspec.yaml in fileScope. If a plan proposes a new pub dependency, that is a scope
violation and must be surfaced at plan review, not granted silently in run.json — #21 proved a run.json
fileScope edit is INERT for a plan-review resume; only the plan document reaches the worker.
