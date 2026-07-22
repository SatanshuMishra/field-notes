---
thread: journal-app-design
status: paused
updated: 2026-07-22
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Human runs the PR #33 camera-validation checklist (preview renders, start no-hang, non-empty playable mp4 + audio, two sequential recordings, mid-record interruption) on the signed app via `flutter run -d macos`; on approval the HUMAN merges PR #33 (gh pr merge is agent-blocked). If a defect surfaces, iterate on fix/macos-capture-finalize (git push works). Two follow-ups are post-merge.
branch: fix/macos-capture-finalize
---

## Status
Both macOS capture bugs fixed. VOICE fixed + hardware-verified (record 7.x + dir-create). VIDEO
BUILT: vendored camera_macos as a path dep + self-finalizing AVCaptureMovieFileOutput; disk-verify
guardrail added; hardened across 2 code-review passes. PR #33 OPEN, awaiting human camera validation.

## Active Goal
Land real voice + video capture saves on macOS via PR #33 (open for review + real-camera validation).

## Next Step
Human validates the PR #33 camera checklist and merges it (agent cannot merge). Iterate on the branch
if validation fails.

## Open Risks
- Video not autonomously camera-testable (test binary denied camera TCC); human validates one real Save.
- main LACKS the bounded-timeout fail-safe (0a9902c never merged; PR #32 shipped the no-op re-await).
  PR #33 carries 0a9902c and RESTORES it on merge.
- Follow-up 1 (post-merge): latestBuffer preview-frame lockless race — PRE-EXISTING upstream, not
  introduced here; fix needs real-camera testing.
- Follow-up 2 (post-merge): 30-min max-duration auto-stop is recoverable on next stop but the UI
  won't reflect it; wire an onVideoRecordingFinished push callback into the app.

## Key Decisions
- decisions/2026-07-22-capture-finalize-fix-strategy.md — voice=record upgrade; video=vendor+AVCaptureMovieFileOutput; +disk-verify guardrail
- decisions/2026-07-22-save-hang-timeout-noop-root-cause.md — bounded timeout fails gracefully but does not persist
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — human merges each PR; gh pr merge agent-blocked
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user;
  pooled Memories gallery. All sync/server work is v2. Reminders day-2 pre-arm is post-31.

## Pointers
- PR: https://github.com/SatanshuMishra/field-notes/pull/33 (base main, head fix/macos-capture-finalize)
- third_party/camera_macos/ — vendored plugin (path dep); movie-output enablement in macos/Classes/CameraMacosPlugin.swift
- lib/features/capture/platform/camera_video_recorder.dart — sets useMovieFileOutput: true
- lib/features/capture/core/journal_capture_service.dart — disk-verify guardrail (_finalize + _awaitFileReady)
- lib/features/capture/voice/record_voice_recorder.dart — voice fix (record 7.x + dir-create); DONE
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-22-03-journal-app-design.md — video BUILT + guardrail + 2 review passes; PR #33 opened
- sessions/2026-07-22-02-journal-app-design.md — 2 root causes; voice fixed+verified; video approach decided (unbuilt)
- sessions/2026-07-22-01-journal-app-design.md — DB round-trip proven; black-window + voice save-hang root-caused & fixed
- sessions/2026-07-21-07-journal-app-design.md — 4 touch-ups + real-UI app test (3/3 macOS); PR #32 merged
