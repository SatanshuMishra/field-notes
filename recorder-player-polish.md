# recorder-player-polish: Settings width, recorder levels and clicks, player and video viewer polish, sound-effect investigation
Status: active
Updated: 2026-11-18T23:26:12.879Z
Next ids: c9 D5 R2 S1

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
- [x] c8 A report explains why the sound effects never played, with no change made to them evidence: evidence: the owner was told the three sound files in assets/sounds are 0.1 s of silence, only the mood pencil is triggered, and nothing was changed

## Where things stand

The interview is finished: the owner approved round 2, chose a video-coloured blurred surround instead of flat black, and told the run to proceed autonomously, so the run is unattended. The Watch19, FadeLine19 and VideoFit19 boards show the approved video experience, surround included. The spec's criteria and Steps are being written.

## Next step

Write the criteria, test rows and Steps for items a to g into docs/specs/recorder-player-polish.record.json, run the probes, feasibility and complete checks, then write and review the spec and hand off.

Needs: D2, D3, D4.

## Decisions in force

- D1 Item b concerns the saved waveform, drawn by loudness; the live meters keep their decibel scale.
- D2 Video controls carry no blur and no glass panel behind them, with YouTube as the reference; the exact treatment waits on the investigation.
- D3 Item g covers the whole video viewing experience: the space around a picture whose shape does not fit, the controls' look and feel, hover and idle animations, and how play and pause feel.
- D4 The spare space around a fitted video glows with a blurred colour sampled from the video file at the playing position, resampled as it plays and blended between samples, as YouTube's ambient mode does.

## Open risks

- R1 The Watch19, FadeLine19 and VideoFit19 boards have not been seen rendered, because the browser pane is not signed in to claude.ai; only their logic was run. Bears on c7.

## Settled, do not reopen

## Where the details live

- https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m: cohesion canvas; its 1.9 follow-ups page holds the prototype boards
- docs/specs/recorder-player-polish.decisions.md and docs/specs/recorder-player-polish.record.json: the interview's answers and record
