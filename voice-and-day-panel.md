# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: active
Updated: 2026-10-17T06:28:11.130Z
Next ids: c1 D1 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

Interphase interview (feature pathway, slug voice-and-day-panel): intent I1 to I4 and round 1 and 2 answers recorded in the decisions file (live processing for voice and video, full speaker settings, seams written to the record). The clarity processing is open: the owner rejected variants A to E (voice sounds unnatural, high-pitched, uneasy). Research found the cause is RNNoise's unlimited attenuation (dry, gated, bright); practice is a reduction limit of about 12 to 18 dB via a delay-aligned dry/wet mix, plus de-essing and loudness levelling. Round 3 asks to adopt it and requests a raw Studio take for tuning. No playback package (just_audio, video_player, audioplayers) can choose an output device on any platform, so output routing means vendoring nine native player sites; the scout found AVPlayer audioOutputDeviceUniqueID (macOS), ExoPlayer setPreferredAudioDevice and MediaPlayer setPreferredDevice (API 28), and WinRT MediaPlayer.AudioDevice documented; the Media Engine's only per-endpoint call, IMFMediaEngineAudioEndpointId::SetAudioEndpointId, has no Learn page (unverified), recorded in docs/specs/voice-and-day-panel.players.md. A 10-minute 608 MB pass-through video join took 0.32 s on the M4 Pro (ffmpeg). No literal pitch shift exists in the pipeline (a 180 s take stays 180.000 s through resampling).

Grounded causes: cleaned voice takes save peaks as an empty list that the backfill skips (voice_composer.dart:336, voice_peaks_backfill.dart:88); input meter segments lay out 0 px tall (probe: 14 x 0); the day pane placeholder's OverflowBox inherits the pane height as its minimum; Android always uses the one-column day sheet. Measured on M4 Pro for 180 s: RNNoise 0.9 s, 44.1 to 48 kHz resample 0.6 s, AAC encode 0.3 s.

## Next step

Phase 7 read-back is out for approval (20 criteria, 23 Steps in three MSPs: audio, settings, day-panel; record passes check_record --complete). On approval, write the spec (phase 8). When the owner's 45 s Studio take arrives, run scratchpad tune.sh on it and send the 9, 12, 15, 18 and 24 dB renders; the pick replaces naturalVoiceAttenuationLimitDb = 15 in criterion 5.1.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Sample recording: /Users/satanshumishra/Downloads/Record (online-voice-recorder.com).mp3
- Listening variants A to E, benchmark and probe tests: session scratchpad (listen/, clean_bench_test.dart, meter_probe_test.dart)
- Interview decisions and intent: docs/specs/voice-and-day-panel.decisions.md
- Interview record: docs/specs/voice-and-day-panel.record.json
- Natural-voice research with sources and the measured RNNoise delay: docs/specs/voice-and-day-panel.research.md
- Player construction sites for output routing: docs/specs/voice-and-day-panel.players.md
- Run home: ~/.mitosis/fireplace/voice-and-day-panel
