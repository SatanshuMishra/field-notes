# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: parked
Updated: 2026-10-18T05:42:09.017Z
Next ids: c1 D4 R3 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

The owner merged MSP pull requests #320, #321 and #322 into FEATURE branch feat/voice-and-day-panel (d120d9cd). The Windows routing fallback (R2) is fixed as Integration round 1-2 on branch fix/windows-output-routing (worktree trees/output-routing, head 06c32a71), to ship as its own pull request into the FEATURE branch at the owner's request: round 2 verdict green with advisories C1-C3 fixed, suite 5368 pass at 2537e758, native tests pass at 06c32a71. It is pushed and open as ready pull request #323 into the FEATURE branch, assigned to the owner. Both fix commits compile on the real PC; the routing trials there were not run because Discord held the headset microphone throughout (review/round-2/integration.smoke-winpc.txt). The real Windows PC smoke at 66438b78 passed every path but routing, with Escape keys unproven there. Unproven: device-level 40 ms sync, video recording on macOS and Windows (no camera); Android has no Output row and its day sheet card play still plays in the card, as the spec decided. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's Mac input runs hot: their raw Studio take clips to +0.5 dBFS in four short places, upstream of the chain.

## Next step

When the owner is off calls, rerun the PC routing trials R1-R6 at 06c32a71; the owner merges #323; Integration (lighthouse on feat/voice-and-day-panel) starts when the owner says it merged.

## Decisions in force

- D2 Attenuation limit default stays 15 dB by the owner's ear pick: naturalVoiceAttenuationLimitDb stays 15; no code change. The three-MSP build of the approved spec continues as decided at hand-off.
- D3 Ship boundary: ship all three MSPs green: Ship all three MSPs now: SHIP=1 run.zsh --resume with no --proven-head (no current head equals a reviewed green head, so mitosis gates all three), then ready pull requests in stack order audio, settings, day-panel.

## Open risks

- R1 Two real settings defects older than the round-2 fixes were rejected as not introduced and ship unfixed: a touch-opened dropdown that lost focus lets Escape close the recorder input panel too and arrows move the volume slider behind it (anchored_dropdown.dart, reproduced by probe), and the Windows player clears m_loadCallback and m_rerouteWhenLoaded without m_mutex (my_grabber_player.cpp, unconfirmed); raise them with the owner in the final report.
- R2 On the real Windows PC a chosen non-default output silently plays on the system default part of the time (DELL 5 of 17, Realtek 4 of 8), with just_audio_windows logging 'Output device error: The request is invalid in the current state'; fixed in #323 but not yet proven on the PC (review/winpc/settings.smoke-winpc.txt).

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
