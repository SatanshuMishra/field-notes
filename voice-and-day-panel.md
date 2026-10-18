# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: parked
Updated: 2026-10-18T04:41:06.121Z
Next ids: c1 D4 R3 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

All three MSPs on FEATURE branch feat/voice-and-day-panel (cut at cb2428e9) are review-green with every advisory fixed and every slow check passing: audio (mitosis/audio, 291a079c), settings stacked on audio (mitosis/settings, 14daa129) and day-panel (mitosis/day-panel, 8f40db6a). Lab smoke passes on Windows, macOS and Android at the local merge 66438b78. Ready pull requests are open, assigned to the owner and carry their assumptions comments: audio #320 on the FEATURE branch, settings #321 on mitosis/audio, day-panel #322 on the FEATURE branch. The ship gate left 12 slow checks inconclusive (4 audio video_live_audio, 8 settings dropdown and speaker tests); each passes run alone at code-identical heads. Unproven: device-level 40 ms sync, macOS A3 (no guest camera), Windows playback and video recording (no guest sound device, camera or video decode); Android has no Output row and its day sheet card play still plays in the card, as the spec decided. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's Mac input runs hot: their raw Studio take clips to +0.5 dBFS in four short places, upstream of the chain.

## Next step

The owner decides whether to fix the Windows output routing fallback (R2) on #321 before merging; otherwise the owner starts Integration by saying the MSP pull requests merged (#320, #321, #322).

Needs: R1, R2.

## Decisions in force

- D2 Attenuation limit default stays 15 dB by the owner's ear pick: naturalVoiceAttenuationLimitDb stays 15; no code change. The three-MSP build of the approved spec continues as decided at hand-off.
- D3 Ship boundary: ship all three MSPs green: Ship all three MSPs now: SHIP=1 run.zsh --resume with no --proven-head (no current head equals a reviewed green head, so mitosis gates all three), then ready pull requests in stack order audio, settings, day-panel.

## Open risks

- R1 Two real settings defects older than the round-2 fixes were rejected as not introduced and ship unfixed: a touch-opened dropdown that lost focus lets Escape close the recorder input panel too and arrows move the volume slider behind it (anchored_dropdown.dart, reproduced by probe), and the Windows player clears m_loadCallback and m_rerouteWhenLoaded without m_mutex (my_grabber_player.cpp, unconfirmed); raise them with the owner in the final report.
- R2 On the real Windows PC a chosen non-default output silently plays on the system default part of the time (DELL 5 of 17, Realtek 4 of 8), with just_audio_windows logging 'Output device error: The request is invalid in the current state'; unfixed in #321 (review/winpc/settings.smoke-winpc.txt).

## Settled, do not reopen

## Where the details live

- Sample recording: /Users/satanshumishra/Downloads/Record (online-voice-recorder.com).mp3
- Attenuation-limit ear-test renders of the owner's 33 s Studio take: ~/Desktop/Field Notes voice levels/
- Listening renders, tune.sh (limit renders of a take), benchmark and probe tests: session scratchpad
- Spec, decisions, record and items: docs/specs/voice-and-day-panel.{md,decisions.md,record.json,items.json}
- Natural-voice research with sources and the measured RNNoise delay: docs/specs/voice-and-day-panel.research.md
- Player construction sites and output-routing APIs per platform: docs/specs/voice-and-day-panel.players.md
- Glossary and ADRs 0001 to 0003 written at hand-off (untracked, ship with the first PR): GLOSSARY.md, docs/adr/
- Run home (charter, worker rules, run.zsh, plan-only.out, build-1.out, rounds.md): ~/.mitosis/field-notes/voice-and-day-panel
- Mitosis run directory (plan, state, lanes, worktrees): ~/.mitosis/runs/field-notes/voice-and-day-panel
- Lane assumptions, obligations, gate proofs and round records per MSP: ~/.mitosis/field-notes/voice-and-day-panel/review/
- Smoke tree, a detached local merge of the three heads at 03ed3bb2, and the smoke path list: ~/.mitosis/field-notes/voice-and-day-panel/smoke-tree, review/round-1/smoke-paths.md
- Reviewer and suite finding arrays per MSP for round 1: ~/.mitosis/field-notes/voice-and-day-panel/review/round-1/arrays/
- Smoke reports per MSP and platform, and their screenshots: review/round-1/<msp>.smoke-<platform>.txt, review/round-1/smoke-shots/
- Round-1 findings, readable records, candidates and validator briefs per MSP: review/round-1/<msp>.findings.json, <msp>.md, <msp>.candidates.md, briefs/<msp>.validator.md
- Diagnosis briefs per MSP and kind: review/round-1/briefs/<msp>.<kind slug>.diagnosis.md; diagnoses: review/round-1/<msp>.<kind slug>.diagnosis.json
- Audio fix-pass brief: handoff/audio-fix-round-1.md
- Round-2 and round-3 diffs, suites, briefs, reviewer arrays, findings, candidates, verdicts, smoke reports and shots per MSP: review/round-2/, review/round-3/
