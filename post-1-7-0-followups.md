# post-1-7-0-followups: Post-1.7.0 follow-ups: privacy line, note title focus, note viewer and editor parity, voice button, week garden, overnight Today, day modal
Status: active
Updated: 2026-11-10T18:42:17.099Z
Next ids: c4 D1 R2 S1

## Goal

Prototype the owner's seven 1.7.0 follow-ups (a to g) on the design canvas, get approval, then build them with fanout as pull requests, keeping the journal identity.

## Done when

- [x] c1 The owner approves prototypes for a, b, c, d, e and g evidence: Owner, 2026-11-10: "Approve as recommended" for the NoteRoom, VoiceButton and TodayDay boards, with a = the day line and d = flat coral in the cream ring
- [ ] c2 The overnight Today bug (f) is reproduced by a test that fails before the fix and passes after
- [ ] c3 Every approved change is open as a pull request with its tests passing

## Where things stand

Week garden (e) is open as SatanshuMishra/field-notes#363, assigned, 15 tests passing. Four agents are still building in their own worktrees cut from 6af4e271: note room (b, a for notes, c), recorders (a for recordings, d), overnight Today (f), day modal (g). The overnight bug is reproduced: today_day_change_test fails on main with the header on the new day while yesterday's note stays in the feed.

## Next step

As each agent returns, review its branch diff, run its tests, confirm both capture branches carry the byte-identical capture_day_line.dart (sha256 1eb5f153...), then push and open one pull request per branch assigned to the owner.

## Decisions in force

## Open risks

- R1 Overnight cause: todayDateProvider, thisWeekCellsProvider and onThisDayMemoryProvider compute once and nothing refreshes them at midnight, while the Today header calls the clock on every rebuild; the shell's New log and the mood dock read the same stale key, so a log or mood made after midnight may be filed under yesterday (inferred from code, not yet tested). A Dart timer can fire late after the Mac sleeps, so the fix also needs a check when the app resumes. Bears on c2.

## Settled, do not reopen

## Where the details live

- Owner's request: 2026-11-10 message with eight screenshots, items a to g
- Prototype canvas: https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m (boards NoteRoom, VoiceButton, TodayDay on page followups)
- Overnight reproduction: test/features/today/today_day_change_test.dart in worktree .claude/worktrees/post-1-7-0, uncommitted
- Fanout plan and leaf briefs: scratchpad fn/fanout/items.json and plan.json; shared helper fn/fanout/capture_day_line.dart
