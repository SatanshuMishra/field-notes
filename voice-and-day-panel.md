# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: active
Updated: 2026-10-17T09:39:28.043Z
Next ids: c1 D2 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

The first build of FEATURE branch feat/voice-and-day-panel (cut at cb2428e9; 23 Steps, three MSPs: audio, which owns output-list-channel; settings, stacked on audio; day-panel) finished 19 of 22 Lanes; the one allowed --resume is running for the failed Lanes 9 (audio: nine out-of-set video tests still expect camera sound), 15 and 21 (a self-written test line the red-test hook blocked). The charter now tells Workers to name out-of-set tests their intended change breaks and leave them to the review's fix pass. Known out-of-set failures for the fix pass: the nine video tests in handoff/audio-lane-9.md, 7 voice tests (voice_level, voice_selected_input, voice_level_response), 1 drift_journal_repository test, voice_settings_page_test and settings_tabs_test. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's 45 s Studio take for the attenuation-limit ear pick has not arrived.

## Next step

When the --resume (output build-1-resume.out) returns, read its last-line JSON: an MSP still not committed is a hard failure to report; committed MSPs go to stage 3 review round 1, whose fix pass also updates the known out-of-set failing tests.

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
