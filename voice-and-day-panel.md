# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: active
Updated: 2026-10-17T17:42:32.181Z
Next ids: c1 D3 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

FEATURE branch feat/voice-and-day-panel (cut at cb2428e9) holds three committed MSPs in review round 1, each with its diff, obligations and gate proofs written: audio on mitosis/audio at 907bdd51 (34 gate passes), settings on mitosis/settings at 3567ddb1 stacked on audio (22 pass, 1 inert), and day-panel on mitosis/day-panel at c1a05eab (15 pass; its Lane 21 test line was fixed with the owner's approval). The day-panel suite passes in full; the audio and settings suites fail only in the out-of-set tests below. Round 1 reviewers are running: code, conformance and security on audio and settings, code and conformance on day-panel (UI only, no security surface). Settings' reconcile lists 229 undeclared files, all inside its declared third_party package folders, so they are not findings. Known out-of-set failures for the fix pass: the nine video tests in handoff/audio-lane-9.md, 7 voice tests (voice_level, voice_selected_input, voice_level_response), 1 drift_journal_repository test, voice_settings_page_test and settings_tabs_test. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's Mac input runs hot: their raw Studio take clips to +0.5 dBFS in four short places, upstream of the chain.

## Next step

As each MSP's suite finishes, write its round-1 suite.txt (failures compared with its base) and dispatch its round 1 reviewers (code-reviewer, conformance-auditor, security-reviewer for audio and settings); then run one smoke agent per platform (macOS and Android in the VM lab, Windows on winpc) at the settings and day-panel heads.

Needs: D2.

## Decisions in force

- D2 Attenuation limit default stays 15 dB by the owner's ear pick: naturalVoiceAttenuationLimitDb stays 15; no code change. The three-MSP build of the approved spec continues as decided at hand-off.

## Open risks

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
