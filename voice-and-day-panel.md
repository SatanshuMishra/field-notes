# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: parked
Updated: 2026-10-18T00:46:14.887Z
Next ids: c1 D3 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

FEATURE branch feat/voice-and-day-panel (cut at cb2428e9) holds three committed MSPs in review round 1: audio on mitosis/audio at 907bdd51, settings on mitosis/settings at 3567ddb1 stacked on audio (it lacks audio's last commit and needs audio merged in before its fix pass), and day-panel on mitosis/day-panel at c1a05eab. Round 1 is validated and every MSP's verdict is diagnose (verdict.json per MSP in review/round-1). Audio's blockers are the take-loss class (C1, S1, S2: a sound-only failure at Keep deletes the video picture; one mic stream error or odd-length chunk discards the whole voice take) and thirteen stale tests (U1 to U13); its advisories are C4 (duplicated helpers) and C5 (unused voiceRecordingEncoder). Settings' blockers are C1 (the Bluetooth output id leaks into journal exports) and the failing-test class: U1 and U2 stale tests, U3 the vendored Windows player crashing after OpenURL fails in the lab guest, and U4 a touch-opened dropdown ignoring Escape on Android; its advisories are C3 (Input profile row announces no value) and C5 (output id decoded by an input-named function). Day-panel's blocker is U1, full screen from a playing video pane doubling the sound; its advisories are C1 (Full screen and card Play lack a screen-reader tap action), C2 (card Play restarts the selected log from 0:00) and C4 (duplicated back button). Settings' export-leak kind is diagnosed fixable and recorded: add SettingsKeys.deviceIdentifierKeys (audioInputId, audioOutputId) and SettingsKeys.isExportedKey, use it at journal_export_service.dart:52, with receipt test test/features/data/journal_export_device_ids_test.dart. Four diagnosis agents still run, one per remaining kind; the settings branch stays untouched until its failing-test diagnosis returns. Smoke left unproven: macOS A3 (no guest camera), Windows playback, video recording and D3x (no guest sound device or camera); Android has no Output row and its day sheet card play still plays in the card, as the spec decided. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's Mac input runs hot: their raw Studio take clips to +0.5 dBFS in four short places, upstream of the chain.

## Next step

Save each diagnosis agent's last JSON object as review/round-1/<msp>.<kind slug>.diagnosis.json, record it with pipeline diagnosis, rerun pipeline verdict per MSP, then run the fix pass on each branch: receipt test first, the class-wide fix, the advisories, and merge mitosis/audio into mitosis/settings.

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
