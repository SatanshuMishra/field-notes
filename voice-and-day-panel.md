# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: parked
Updated: 2026-10-18T00:59:20.269Z
Next ids: c1 D3 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

FEATURE branch feat/voice-and-day-panel (cut at cb2428e9) holds three MSPs in the round 1 fix pass, each with its round-1 verdict.json and diagnoses in review/round-1. Audio (mitosis/audio, 907bdd51) has verdict loop with both kinds diagnosed fixable: take lost on sound failure (C1, S1, S2) and thirteen stale tests (U1 to U13), plus advisories C4 and C5; an agent applies its fix pass from handoff/audio-fix-round-1.md and saves the round-2 suite. Settings (mitosis/settings, f5887c6d, audio 907bdd51 merged in; audio's fix commits merge in again after audio's pass) has verdict loop with both kinds fixable and its fix pass under way here: three receipt tests committed failing at f15b9511 (test/features/data/journal_export_device_ids_test.dart for C1; input_dropdown_test.dart "escape closes a menu that lost focus" for U4; test/native/video_player_win_load_failure_test.dart for U3); fixes planned: SettingsKeys.deviceIdentifierKeys and isExportedKey used by the export filter (C1), U1 and U2 tests rewritten to the Input profile dropdown, a HardwareKeyboard Escape handler in AnchoredDropdown while the menu lacks focus (U4), MyPlayer::finishLoad taking the load callback off the player before calling it at all three call sites plus a replied flag for the plugin's open reply (U3), and advisories C3 (Input profile row semantics) and C5 (rename _decodeAudioInputId). Day-panel (mitosis/day-panel, c1a05eab) waits on its failing-test diagnosis of U1 (full screen from a playing video pane doubles the sound); its advisories are C1, C2 and C4. Smoke left unproven: macOS A3 (no guest camera), Windows playback, video recording and D3x (no guest sound device or camera); Android has no Output row and its day sheet card play still plays in the card, as the spec decided. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's Mac input runs hot: their raw Studio take clips to +0.5 dBFS in four short places, upstream of the chain.

## Next step

Finish and commit the settings fix pass, record day-panel's diagnosis and fix it, take audio's fix report, merge audio into settings again, then run round 2 reviews with previous_head set and smoke only on broken paths, in the lab, Windows first.

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
- Smoke tree, a detached local merge of the three heads at 03ed3bb2, and the smoke path list: ~/.mitosis/field-notes/voice-and-day-panel/smoke-tree, review/round-1/smoke-paths.md
- Reviewer and suite finding arrays per MSP for round 1: ~/.mitosis/field-notes/voice-and-day-panel/review/round-1/arrays/
- Smoke reports per MSP and platform, and their screenshots: review/round-1/<msp>.smoke-<platform>.txt, review/round-1/smoke-shots/
- Round-1 findings, readable records, candidates and validator briefs per MSP: review/round-1/<msp>.findings.json, <msp>.md, <msp>.candidates.md, briefs/<msp>.validator.md
- Diagnosis briefs per MSP and kind: review/round-1/briefs/<msp>.<kind slug>.diagnosis.md; diagnoses: review/round-1/<msp>.<kind slug>.diagnosis.json
- Audio fix-pass brief: handoff/audio-fix-round-1.md
