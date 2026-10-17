# voice-and-day-panel: Voice meter, settings, day pop-up panel, voice clarity and faster denoise
Status: active
Updated: 2026-10-17T06:15:04.587Z
Next ids: c1 D1 R1 S1

## Goal

Fix the flat voice visualizer, add live input meters and a microphone dropdown plus speaker settings, make the past-day pop-up open voice and video in its right panel with day arrows, diagnose why processed voice lacks clarity, and make post-recording noise removal faster without reducing quality.

## Done when

## Where things stand

Interphase interview (feature pathway, slug voice-and-day-panel): intent I1 to I4 and round 1 and 2 answers recorded in the decisions file (live processing for voice and video, full speaker settings, seams written to the record). The clarity processing is open: the owner rejected variants A to E (voice sounds unnatural, high-pitched, uneasy). Research found the cause is RNNoise's unlimited attenuation (dry, gated, bright); practice is a reduction limit of about 12 to 18 dB via a delay-aligned dry/wet mix, plus de-essing and loudness levelling. Round 3 asks to adopt it and requests a raw Studio take for tuning. An Explore agent is locating where just_audio, video_player and audioplayers create their native players on each platform, for output routing. A 10-minute 608 MB pass-through video join took 0.32 s on the M4 Pro (ffmpeg). No literal pitch shift exists in the pipeline (a 180 s take stays 180.000 s through resampling).

Grounded causes: cleaned voice takes save peaks as an empty list that the backfill skips (voice_composer.dart:336, voice_peaks_backfill.dart:88); input meter segments lay out 0 px tall (probe: 14 x 0); the day pane placeholder's OverflowBox inherits the pane height as its minimum; Android always uses the one-column day sheet. Measured on M4 Pro for 180 s: RNNoise 0.9 s, 44.1 to 48 kHz resample 0.6 s, AAC encode 0.3 s.

## Next step

When the research and the player survey return, ask round 3 (the clarity processing from the research, and the video join on Keep versus writing cleaned sound into the camera's own file), then design the criteria and Steps in docs/specs/voice-and-day-panel.record.json.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Sample recording: /Users/satanshumishra/Downloads/Record (online-voice-recorder.com).mp3
- Listening variants A to E, benchmark and probe tests: session scratchpad (listen/, clean_bench_test.dart, meter_probe_test.dart)
- Interview decisions and intent: docs/specs/voice-and-day-panel.decisions.md
- Interview record: docs/specs/voice-and-day-panel.record.json
- Run home: ~/.mitosis/fireplace/voice-and-day-panel
