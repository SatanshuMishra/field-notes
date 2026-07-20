Status: accepted
Date: 2026-07-20
Thread: journal-app-design

## Context
reminders (PR #21) arms only the NEXT single occurrence; nothing re-arms day N+1 until a provider rebuild, i.e. until the app is launched. A user who ignores the reminder and never reopens the app gets no reminder on subsequent days — which is precisely the target user of a journaling reminder. The obvious fix, `zonedSchedule(..., matchDateTimeComponents: DateTimeComponents.time)`, was correctly rejected against verified plugin source: on Android `getNextFireDateMatchingDateTimeComponents` discards the scheduled DATE and rebuilds from today + time-of-day, so a suppression schedule for tomorrow would fire TONIGHT, violating spec §6.4; on macOS `DateTimeComponents.time` maps to a `.day`-inclusive `UNCalendarNotificationTrigger`, i.e. a MONTHLY repeat, not daily.

## Decision
Ship #21 with the one-shot form and defer day-2+ reach to a follow-up MSP queued with batch 3. User chose this over blocking the merge or accepting the residual permanently.

## Consequences
The plan's alternatives analysis was incomplete, and the follow-up should close that gap rather than repeat it: plan review raised, as advisory non-blocking, a middle option neither the plan nor the review's own recommendation considered — pre-arm N one-shot occurrences (ids 1001..1007) on each sync instead of exactly one. It preserves §6.4 suppression exactly, because an entry can only be created by opening the app, which rebuilds `reminderSyncProvider` and re-arms the whole window from scratch, so no stale day can fire against a day that has gained an entry. It sits INSIDE the existing reminders fileScope. Prefer it over a boot/periodic background worker, which needs out-of-scope platform files. Until it ships, v1 reminders are honestly "reminders for users who open the app".
