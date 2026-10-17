# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: active
Updated: 2026-10-17T06:51:36.249Z
Next ids: c1 D2 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

The first mitosis build is running from FEATURE branch feat/voice-and-day-panel (cut at cb2428e9): 23 Steps, 20 criteria, three MSPs (audio, which owns output-list-channel; settings, stacked on audio; day-panel), plan-only clean with no fatal findings. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's 45 s Studio take for the attenuation-limit ear pick has not arrived.

## Next step

Run ~/.mitosis/field-notes/voice-and-day-panel/run.zsh (first build, output to build-1.out), then read its last-line JSON result and start stage 3 review per MSP (audio, settings, day-panel).

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
