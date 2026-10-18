# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: parked
Updated: 2026-10-18T00:01:16.885Z
Next ids: c1 D3 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

FEATURE branch feat/voice-and-day-panel (cut at cb2428e9) holds three committed MSPs in review round 1, each with its diff, obligations and gate proofs written: audio on mitosis/audio at 907bdd51 (34 gate passes), settings on mitosis/settings at 3567ddb1 stacked on audio (22 pass, 1 inert), and day-panel on mitosis/day-panel at c1a05eab (15 pass; its Lane 21 test line was fixed with the owner's approval). The day-panel suite passes in full; the audio and settings suites fail only in the out-of-set tests below. Conformance is MET on every criterion of all three MSPs (5.9 not applicable: live-device seam). Security review is in (arrays and threats saved): audio has two CRITICAL take-loss candidates (a sound-only failure at Keep deletes the video picture; one mic stream error or odd-length chunk discards the whole voice take) plus a LOW native path-confinement gap; settings has the Bluetooth output id leaking into journal exports (MEDIUM), the stale voice_settings_page compile break, and a LOW Windows re-route thread use-after-free. The audio code review confirms the take-loss path independently (HIGH) and adds three LOW advisories: an empty-peaks entry is re-decoded on every launch, duplicated settings and processing helpers, and an unused voiceRecordingEncoder. The day-panel code review finds the new Full screen and card Play buttons have no screen-reader tap action (MEDIUM), plus four LOW advisories: card Play restarts the selected log from 0:00, two duplicated widgets, and a dead onReadNote parameter. The settings code review agrees on the export leak (HIGH) and the stale tests, and adds the Input profile row announcing no value or expanded state to screen readers (MEDIUM) plus LOW naming and dead-field advisories. Every reviewer is in. The macOS smoke is done (reports in review/round-1/*.smoke-macos.txt): every path passes or is unproven for lack of a guest camera (A3), except D3x, a day-panel defect: full screen on a video playing in the right column leaves the pane playing under the viewer, doubling the sound. Windows smoke ran in the VM lab instance on the owner's instruction (the PC only built the profile app): no BROKEN path, with playback, video recording and D3x unproven (no sound device or camera) and X1, video_player_win crashing on a null pointer after OpenURL fails (hr 0x887A0004) under the Basic Display Adapter, likely guest-specific. Android smoke is running in the lab, alone. Draft round-1 findings files are assembled from the arrays (audio 21, settings 11, day-panel 5); smoke findings join them as further U ids before Validate. Settings' reconcile lists 229 undeclared files, all inside its declared third_party package folders, so they are not findings. The stale out-of-set tests are written up as suite findings (audio U1 to U13, settings U1 and U2, each with its fix) in review/round-1/arrays; each still expects behaviour the spec replaced. The owner's checkout keeps uncommitted docs/prototype and tool/probe/macos/drive.sh changes that no Step touches. The owner's Mac input runs hot: their raw Studio take clips to +0.5 dBFS in four short places, upstream of the chain.

## Next step

When the Android lab smoke reports, file each broken path (macOS D3x included) against its MSP as further U findings, then build each MSP's round-1 findings.json from review/round-1/arrays and run pipeline candidates and the validator.

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
