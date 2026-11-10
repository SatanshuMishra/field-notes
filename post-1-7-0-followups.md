# post-1-7-0-followups: Post-1.7.0 follow-ups: privacy line, note title focus, note viewer and editor parity, voice button, week garden, overnight Today, day modal
Status: active
Updated: 2026-11-10T20:06:13.489Z
Next ids: c4 D1 R2 S1

## Goal

Prototype the owner's seven 1.7.0 follow-ups (a to g) on the design canvas, get approval, then build them with fanout as pull requests, keeping the journal identity.

## Done when

- [x] c1 The owner approves prototypes for a, b, c, d, e and g evidence: Owner, 2026-11-10: "Approve as recommended" for the NoteRoom, VoiceButton and TodayDay boards, with a = the day line and d = flat coral in the cream ring
- [x] c2 The overnight Today bug (f) is reproduced by a test that fails before the fix and passes after evidence: today_day_change_test on branch fix/today-day-change (#365) fails with the fix taken out (the late note stays) and passes with it; the provider, resume and New log tests do the same
- [ ] c3 Every approved change is open as a pull request with its tests passing

## Where things stand

Open and assigned: week garden (e) #363; recorders (a for recordings, d) #364; overnight Today (f) #365; day modal (g) #366. The first merged run of all five found one stale test per branch on #363, #364 and the note room; each is fixed and pushed (the recorder date now wraps at 2x text rather than truncating). The note room (b, a for notes, c) is committed on feat/note-room, not pushed. The merged run is repeating on the latest branches.

## Next step

When the merged run is green, push feat/note-room and open its pull request from scratchpad fn/fanout/pr-noteroom.json (fill the merged-run result), then tick c3 and remove the scratch integration worktree. Plain gh pr create is refused in this session; open through the GitHub MCP create_pull_request with render's title and body, then assign.

## Decisions in force

## Open risks


## Settled, do not reopen

## Where the details live

- Owner's request: 2026-11-10 message with eight screenshots, items a to g
- Prototype canvas: https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m (boards NoteRoom, VoiceButton, TodayDay on page followups)
- Fanout plan and leaf briefs: scratchpad fn/fanout/items.json and plan.json; shared helper fn/fanout/capture_day_line.dart
- Integration check: scratchpad fn/integration, a detached worktree with all five branches merged; remove it after the check
