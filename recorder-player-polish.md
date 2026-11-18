# recorder-player-polish: Settings width, recorder levels and clicks, player and video viewer polish, sound-effect investigation
Status: active
Updated: 2026-11-18T22:27:51.079Z
Next ids: c9 D4 R1 S1

## Goal

Fix eight owner-reported issues across the settings page, the voice and video recorders, the voice players and the video full view so the app stays consistent, accessible and calm, after the owner approves a visual prototype.

## Done when

- [ ] c1 Settings content keeps a readable width and sits balanced in a wide window without stretching its rows
- [ ] c2 The saved voice waveform on Today cards, the full view and the day window varies with how loudly the owner speaks instead of flipping between full and empty (reworded by D1: item b concerns the saved waveform)
- [ ] c3 Clicking empty space on the voice and video recorders plays no sound and does nothing, while video keeps its tap-to-focus
- [ ] c4 The recorder's microphone panel shows the input level as soon as it opens and carries no Voice settings entry
- [ ] c5 Full screen in the full view takes the app full screen and back to windowed, or the button is removed
- [ ] c6 The past-day voice preview follows light and dark mode and uses the same player as the Today cards and full view
- [ ] c7 The video viewing experience in the full view and the day-window preview (the space around the picture, the controls' look, their hover and idle animations, and play and pause feedback) feels calm and smooth with no visible line in light and dark, and the arrow buttons render crisp (reworded by D3)
- [ ] c8 A report explains why the sound effects never played, with no change made to them

## Where things stand

Intent and frontier round 1 are answered and recorded except the video controls, which the owner reopened. Two video boards (an interactive player and a fade explainer) are drafted but unpublished, waiting on a code inventory of today's player and an outside survey of other players.

## Next step

When the code inventory and the player survey report, align the Today side of the Watch19 and FadeLine19 boards with them, publish both, and report the problem and the proposed fix to the owner.

## Decisions in force

- D1 Item b concerns the saved waveform, drawn by loudness; the live meters keep their decibel scale.
- D2 Video controls carry no blur and no glass panel behind them, with YouTube as the reference; the exact treatment waits on the investigation.
- D3 Item g covers the whole video viewing experience: the space around a picture whose shape does not fit, the controls' look and feel, hover and idle animations, and how play and pause feel.

## Open risks

## Settled, do not reopen

## Where the details live

- https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m: cohesion canvas; its 1.9 follow-ups page holds the prototype boards
- docs/specs/recorder-player-polish.decisions.md and docs/specs/recorder-player-polish.record.json: the interview's answers and record
