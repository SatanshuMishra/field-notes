# recorder-player-polish: Settings width, recorder levels and clicks, player and video viewer polish, sound-effect investigation
Status: parked
Updated: 2026-11-19T07:23:14.937Z
Next ids: c9 D8 R2 S1

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

The run is unattended. The interphase package is handed off: 12 criteria, two of them unproven and left to lab checks, 41 acceptance lines and 10 builder Steps in five pull requests. The spec reviewer's 13 issues were each fixed once and the spec now uses the glossary's words, and every check passes. The glossary terms and ADRs 0010 and 0011 are written, and the run's facts file is in the run home.

## Next step

The drive entered clean-up and runs it next.

## Decisions in force

- D1 Item b concerns the saved waveform, drawn by loudness; the live meters keep their decibel scale.
- D2 Video controls carry no blur and no glass panel behind them, with YouTube as the reference; the exact treatment waits on the investigation.
- D3 Item g covers the whole video viewing experience: the space around a picture whose shape does not fit, the controls' look and feel, hover and idle animations, and how play and pause feel.
- D4 The spare space around a fitted video glows with a dim, heavily blurred live copy of the video, through the recorder's existing CameraPictureStage, as YouTube's ambient mode fills it.
- D5 One-time test for this run only: once the MSP pull requests are merged into the FEATURE branch and before the drive's product test runs, drive the FEATURE build in Flutter's headless mode (no VM) for every changed surface, send only what headless cannot reach to the VM lab, and report what headless covered; the lighthouse profile and every rule stay unchanged.
- D6 Items a to e each ship as their own pull request; f ships with g in one, because their existing tests share the day window's test files, as the owner allowed.
- D7 hand-off: build recorder-player-polish unattended through the pipeline drive: Hand the package to the pipeline drive in the full lane, unattended. Each later gap becomes an assumption citing an intent line, and the D5 headless pass runs once the MSP pull requests are merged into the FEATURE branch.

## Open risks

- R1 The Watch19, FadeLine19 and VideoFit19 boards have not been seen rendered, because the browser pane is not signed in to claude.ai; only their logic was run. Bears on c7.

## Settled, do not reopen

## Where the details live

- https://claude.ai/artifact/6Jhnx5E1BxCPH9DgNu9R1m: cohesion canvas; its 1.9 follow-ups page holds the prototype boards
- docs/specs/recorder-player-polish.decisions.md and docs/specs/recorder-player-polish.record.json: the interview's answers and record
- docs/specs/recorder-player-polish.md and docs/specs/recorder-player-polish.items.json: the spec and the Steps builders receive
- ~/.mitosis/fireplace/recorder-player-polish/: the pipeline run home, holding facts.json
