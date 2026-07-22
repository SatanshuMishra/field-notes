---
thread: journal-app-design
status: active
updated: 2026-07-22
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Implement the VIDEO fix (vendor camera_macos into the repo as a pinned path dependency and route recording through Apple's self-finalizing AVCaptureMovieFileOutput, reusing the working preview) and the cross-cutting verify-on-disk GUARDRAIL (after stop(), poll file exists+non-empty; surface native errors distinctly; keep the bounded-timeout fail-safe). Verify compile + analyze + Dart tests (camera is HUMAN-validated). Then push fix/macos-capture-finalize and open a PR from the MAIN THREAD, left open for human review + real-camera validation. Always run via `flutter run -d macos`, never the standalone binary.
branch: fix/macos-capture-finalize
---

## Status
Two distinct macOS capture bugs root-caused. VOICE fixed + hardware-verified (record 6.2.1->7.1.1 +
a missing-parent-dir fix; stop() 26ms, 82KB m4a persists), 2 commits on fix/macos-capture-finalize.
VIDEO fix DECIDED (vendor camera_macos -> AVCaptureMovieFileOutput) but NOT yet built.

## Active Goal
Make real voice + video captures actually save on the running macOS app; land the fixes (push + PR
left open for review).

## Next Step
Build the video fix (vendor camera_macos -> AVCaptureMovieFileOutput, reuse preview) and the
verify-on-disk guardrail across voice/video/shared service; verify compile+analyze+Dart tests; then
push + open the PR from the main thread.

## Open Risks
- Video cannot be camera-tested autonomously (test binary denied camera TCC); the human must
  validate one real Save. Exact native branch unconfirmed (optional 1-line diagnostic in session log).
- record_macos 2.1.1 returns the path BEFORE the async file flush and writes to purgeable Caches —
  the guardrail must poll for a non-empty file; the pipeline must copy to the DB blob promptly.
- Branch fix/macos-capture-finalize is unpushed; no PR yet. Its base (fix/capture-save-hang) carries
  the bounded-timeout fail-safe (0a9902c) and a stale ledger — ledger stays canonical on main.

## Key Decisions
- decisions/2026-07-22-capture-finalize-fix-strategy.md — voice=record upgrade; video=vendor+AVCaptureMovieFileOutput; +disk-verify guardrail
- decisions/2026-07-22-save-hang-timeout-noop-root-cause.md — bounded timeout fails gracefully but does not persist
- decisions/2026-07-21-capture-flow-root-cause-and-fix.md — PR #32 capture fixes (timeout claim corrected)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user;
  pooled Memories gallery. All sync/server work is v2. Reminders day-2 pre-arm is post-31.

## Pointers
- lib/features/capture/voice/record_voice_recorder.dart — voice fix (record 7.x + dir-create); DONE
- lib/features/capture/platform/camera_video_recorder.dart — video recorder to rewrite (stop() at :197/:212)
- lib/features/capture/video/video_recorder.dart — videoStopMessage (the string the human sees)
- lib/features/capture/{voice,video,text}/*_composer.dart — bounded-timeout fail-safe (keep) + guardrail hook
- lib/features/capture/core/journal_capture_service.dart — shared persist; disk-verify guardrail target
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-22-02-journal-app-design.md — 2 root causes; voice fixed+verified; video approach decided (unbuilt)
- sessions/2026-07-22-01-journal-app-design.md — DB round-trip proven; black-window + voice save-hang root-caused & fixed
- sessions/2026-07-21-07-journal-app-design.md — 4 touch-ups + real-UI app test (3/3 macOS); PR #32 merged
- sessions/2026-07-21-06-journal-app-design.md — capture flows debugged + fixed; complete app test owed
