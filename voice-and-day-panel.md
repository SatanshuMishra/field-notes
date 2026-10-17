# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: active
Updated: 2026-10-17T17:17:22.473Z
Next ids: c1 D2 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

FEATURE branch feat/voice-and-day-panel (cut at cb2428e9) holds three MSPs. Audio is committed on mitosis/audio at 907bdd51 (34 gate passes) and settings on mitosis/settings at 3567ddb1, stacked on audio (22 pass, 1 inert); both are in review round 1 with diffs, obligations and 57 gate proofs written and the full suite running. Day-panel's Lane 21 test line was fixed in its worktree with the owner's approval (6 of 6 pass) and a second --resume is gating and committing it. Known out-of-set failures for the fix pass: the nine video tests in handoff/audio-lane-9.md, 7 voice tests (voice_level, voice_selected_input, voice_level_response), 1 drift_journal_repository test, voice_settings_page_test and settings_tabs_test. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's 45 s Studio take for the attenuation-limit ear pick has not arrived.

## Next step

Run stopped on a hard failure: day-panel is not committed after its one --resume (Lane 21's arrow-keys test row taps note text no finder reaches; the one-line fix in handoff/day-panel-lane-21.md passed 6 of 6 in a scratch copy, but the red-test hook blocks the Worker). Audio (34 gates pass) and settings (22 pass, 1 inert) are committed on mitosis/audio and mitosis/settings and wait for review round 1. The owner decides whether to apply the one-line fix and continue.

Needs: D1.

## Decisions in force

- D1 Interphase hand-off: build the approved spec in three MSPs: Build now: audio, settings (stacked on audio) and day-panel MSPs from the FEATURE branch; the owner's pick replaces naturalVoiceAttenuationLimitDb when the take arrives.

## Open risks

## Settled, do not reopen

## Where the details live

- Sample recording: /Users/satanshumishra/Downloads/Record (online-voice-recorder.com).mp3
- Listening renders, tune.sh (limit renders of a take), benchmark and probe tests: session scratchpad
- Spec, decisions, record and items: docs/specs/voice-and-day-panel.{md,decisions.md,record.json,items.json}
- Natural-voice research with sources and the measured RNNoise delay: docs/specs/voice-and-day-panel.research.md
- Player construction sites and output-routing APIs per platform: docs/specs/voice-and-day-panel.players.md
- Glossary and ADRs 0001 to 0003 written at hand-off (untracked, ship with the first PR): GLOSSARY.md, docs/adr/
- Run home (charter, worker rules, run.zsh, plan-only.out, build-1.out, rounds.md): ~/.mitosis/field-notes/voice-and-day-panel
- Mitosis run directory (plan, state, lanes, worktrees): ~/.mitosis/runs/field-notes/voice-and-day-panel
- Lane assumptions per MSP for the pull requests: ~/.mitosis/field-notes/voice-and-day-panel/review/<msp>.assumptions.txt
