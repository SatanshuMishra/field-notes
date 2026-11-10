# post-1-7-0-followups: Post-1.7.0 follow-ups: privacy line, note title focus, note viewer and editor parity, voice button, week garden, overnight Today, day modal
Status: active
Updated: 2026-11-10T18:31:20.746Z
Next ids: c4 D1 R2 S1

## Goal

Prototype the owner's seven 1.7.0 follow-ups (a to g) on the design canvas, get approval, then build them with fanout as pull requests, keeping the journal identity.

## Done when

- [ ] c1 The owner approves prototypes for a, b, c, d, e and g
- [ ] c2 The overnight Today bug (f) is reproduced by a test that fails before the fix and passes after
- [ ] c3 Every approved change is open as a pull request with its tests passing

## Where things stand

Prototypes for a, b, c, d, e and g are published on the canvas's 1.7 follow-ups page and wait for the owner's approval; recommended picks are a = the day line (replaces the privacy line) and d = flat coral in the cream ring. The overnight bug is reproduced: today_day_change_test fails on main with the header on the new day while yesterday's note stays in the feed. Nothing is built.

## Next step

Wait for the owner's approval of the three boards on the canvas's 1.7 follow-ups page (NoteRoom for a, b, c; VoiceButton for d; TodayDay for e, g) and their picks for a and d, then plan the leaves with fanout from worktree .claude/worktrees/post-1-7-0 (branch research/post-1-7-0), which holds the red overnight test test/features/today/today_day_change_test.dart.

## Decisions in force

## Open risks

- R1 Overnight cause: todayDateProvider, thisWeekCellsProvider and onThisDayMemoryProvider compute once and nothing refreshes them at midnight, while the Today header calls the clock on every rebuild; the shell's New log and the mood dock read the same stale key, so a log or mood made after midnight may be filed under yesterday (inferred from code, not yet tested). A Dart timer can fire late after the Mac sleeps, so the fix also needs a check when the app resumes. Bears on c2.

## Settled, do not reopen

## Where the details live

- Owner's request: 2026-11-10 message with eight screenshots, items a to g
- Prototype canvas: https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m
