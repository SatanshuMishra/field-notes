# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: active
Updated: 2026-10-17T06:49:10.740Z
Next ids: c1 D2 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

Interphase is handed off: the spec holds 20 criteria and 23 Steps in three MSPs (audio; settings, stacked on audio through output-list-channel; day-panel), and the record, spec and items pass every interphase check. Pipeline stage 2 is starting: the checkout's main is at origin/main cb2428e9 with the owner's uncommitted docs/prototype and tool/probe/macos/drive.sh changes, which no Step touches. The owner's 45 s Studio take for the attenuation-limit ear pick has not arrived.

## Next step

Cut the FEATURE branch with pipeline feature-branch, write the run home (~/.mitosis/field-notes/voice-and-day-panel: CHARTER.md, worker-rules.txt, dispatch.zsh, run.zsh, items.json, graph.json) and run run.zsh --plan-only. When the Studio take arrives, run scratchpad tune.sh on it and send the 9, 12, 15, 18 and 24 dB renders; the pick replaces naturalVoiceAttenuationLimitDb = 15.

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
- Run home: ~/.mitosis/field-notes/voice-and-day-panel
