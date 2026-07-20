# Reminders day-2+ coverage deferred to a batch-3 follow-up MSP

Status: accepted
Date: 2026-07-20

## Decision

reminders (PR #21) ships arming only the NEXT single occurrence. A user who ignores the
notification and never reopens the app receives no reminder on subsequent days. User accepted
this residual and directed that the fix be queued as a follow-up MSP alongside the batch-3
candidates, not as a blocker on #21.

## Why the obvious fix is not the fix

`zonedSchedule(..., matchDateTimeComponents: DateTimeComponents.time)` was evaluated and
rejected against verified plugin source:
- Android discards the scheduled DATE and rebuilds from today + time-of-day, so the
  suppression case (entry exists today -> schedule tomorrow) would fire TONIGHT, violating
  spec §6.4.
- macOS maps `DateTimeComponents.time` to a `.day`-inclusive `UNCalendarNotificationTrigger`,
  i.e. a MONTHLY repeat, not daily.

## The follow-up's actual shape

Plan review raised, as advisory, the middle option the plan never evaluated: pre-arm N one-shot
occurrences (ids 1001..1007) on each sync instead of exactly one. It preserves §6.4 suppression
because an entry can only be created by opening the app, which rebuilds `reminderSyncProvider`
and re-arms the whole window from scratch. It sits INSIDE the existing reminders fileScope.
Prefer it over a boot/periodic background worker, which needs out-of-scope platform files.
