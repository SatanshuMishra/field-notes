# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: parked
Updated: 2026-10-18T02:05:49.828Z
Next ids: c1 D3 R2 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

FEATURE branch feat/voice-and-day-panel (cut at cb2428e9) holds three MSPs whose round-1 fix passes are committed, moving into review round 2 (round-2 diffs in review/round-2). Audio (mitosis/audio, a05546da): receipts 1998253c, take-loss fix 357b3157 (C1, S1, S2), 13 tests migrated to shared fakes in test/features/capture/audio/live_audio_test_support.dart at 37e84460 (U1 to U13), C4 and C5 at a05546da; suite 5310 pass in review/round-2/audio.suite.txt; both selecting checks empty; four new assumptions in review/audio.assumptions.txt. Settings (mitosis/settings, 94831a4a = audio a05546da merged over 7114254c): C1 at e868f4ef, U1 to U4 at f94e5b27, C3 and C5 at 7114254c; its Windows native change (video_player_win finishLoad and single reply) is not yet compiled; its round-2 suite passes 5339 in review/round-2/settings.suite.txt. Day-panel (mitosis/day-panel, 8f40db6a; round-2 reviewed head bf8ee49e): its round-2 suite passes 5313 in review/round-2/day-panel.suite.txt (earlier runs lost test files to an overloaded machine and killed testers; kept as day-panel.suite-run*.txt). Full suites run one at a time on this Mac. Smoke left unproven: macOS A3 (no guest camera), Windows playback, video recording and D3x (no guest sound device or camera); Android has no Output row and its day sheet card play still plays in the card, as the spec decided. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's Mac input runs hot: their raw Studio take clips to +0.5 dBFS in four short places, upstream of the chain.

## Next step

Audio round 2 looped on C1, sound shifted after a failed append (diagnosis fixable, review/round-2/audio.sound-shifted-after-failed-append.diagnosis.json); its fix is at bb275abd (receipts 4c1eb0f9; each native append reports frames taken, Dart holds the rest; Android debug build compiles) and its round-3 suite runs into review/round-3/audio.suite.txt; audio is merged into settings at 30428ffb; after the audio suite, run settings' suite and slow checks there, and review audio round 3. Day-panel is green at 8f40db6a, its advisory C1 fixed and its 13 slow checks passing alone (review/day-panel.proofs.jsonl); it waits only for the macOS D3x smoke. Settings is green at 94831a4a (P1 fixed; C1 and S1 rejected as not introduced by the fix commits); its slow checks run after audio's fix is merged into it. Then smoke the broken paths in the lab, Windows first (settings U3 build on winpc only), then macOS D3x, then Android S2.

Needs: D2.

## Decisions in force

- D2 Attenuation limit default stays 15 dB by the owner's ear pick: naturalVoiceAttenuationLimitDb stays 15; no code change. The three-MSP build of the approved spec continues as decided at hand-off.

## Open risks

- R1 Two real settings defects older than the round-2 fixes were rejected as not introduced and ship unfixed: a touch-opened dropdown that lost focus lets Escape close the recorder input panel too and arrows move the volume slider behind it (anchored_dropdown.dart, reproduced by probe), and the Windows player clears m_loadCallback and m_rerouteWhenLoaded without m_mutex (my_grabber_player.cpp, unconfirmed); raise them with the owner in the final report.

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
- Round-2 diffs, suites, briefs, reviewer arrays, findings and candidates per MSP: review/round-2/
