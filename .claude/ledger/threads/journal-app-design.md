---
thread: journal-app-design
status: paused
updated: 2026-07-24
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: HUMAN merges PR #33 on GitHub (gh pr merge agent-blocked). PR #33 carries both the videoRotationAngle crash fix (a714961) and the H2 main-thread reply fix (301232b), and RESTORES the bounded-timeout fail-safe (0a9902c) to main. After merge, reconcile local main onto origin/main; the two post-merge follow-ups are optional.
branch: fix/macos-capture-finalize
---

## Status
Real macOS video capture FIXED and VERIFIED on the actual camera (human run 2026-07-24). Root cause was
AVCaptureConnection.videoRotationAngle throwing on macOS 26 _Tundra the instant camera TCC was granted
(the isVideoRotationAngleSupported guard returns true, then the setter throws the legacy setVideoOrientation
error Swift cannot catch) — never a save-path bug. Fix = delete the three rotation-angle sets. Verified
run records+saves a 669KB/7.3s clip; entry appears and plays. Both the crash fix and 301232b validated.
VIDCAP instrumentation stripped; crash fix committed (a714961) + pushed. Voice already hardware-verified.

## Active Goal
Land real voice + video capture saves on macOS via PR #33 (OPEN / MERGEABLE, awaiting human merge).

## Next Step
Human merges PR #33 on GitHub (agent cannot merge). If any defect surfaces, iterate on
fix/macos-capture-finalize (git push works).

## Open Risks
- main LACKS the bounded-timeout fail-safe (0a9902c) until PR #33 merges; PR #33 restores it on merge.
- gh pr merge (and the REST merge endpoint) are hook-blocked for all callers — the HUMAN must merge.
- Follow-up 1 (post-merge): latestBuffer preview-frame lockless race — PRE-EXISTING upstream, not
  introduced here; a fix needs real-camera testing.
- Follow-up 2 (post-merge): 30-min max-duration auto-stop is recoverable on next stop but the UI won't
  reflect it; wire an onVideoRecordingFinished push callback into the app.

## Key Decisions
- decisions/2026-07-24-macos-videorotationangle-crash.md — REAL crash = videoRotationAngle setter, not save-path
- decisions/2026-07-22-capture-finalize-fix-strategy.md — voice=record upgrade; video=vendor+movie-output; +disk-verify
- decisions/2026-07-22-save-hang-timeout-noop-root-cause.md — bounded timeout fails gracefully but does not persist
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — human merges each PR; gh pr merge agent-blocked
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user;
  pooled Memories gallery. All sync/server work is v2. Reminders day-2 pre-arm is post-31.

## Pointers
- PR: https://github.com/SatanshuMishra/field-notes/pull/33 (base main, head fix/macos-capture-finalize)
- third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift — initCamera (crash fix); movie-output delegate (301232b H2 fix)
- lib/features/capture/core/journal_capture_service.dart — disk-verify guardrail (_finalize/_awaitFileReady)
- lib/features/capture/video/video_composer.dart — "Saving..." + 20s persist timeout
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-24-03-journal-app-design.md — SHIP: VIDCAP stripped, crash fix committed (a714961) + pushed; PR #33 mergeable
- sessions/2026-07-24-02-journal-app-design.md — video VERIFIED working (human run); SHIP steps recorded
- sessions/2026-07-24-01-journal-app-design.md — REAL crash found (videoRotationAngle) + fixed
- sessions/2026-07-22-03-journal-app-design.md — video BUILT + guardrail + 2 review passes; PR #33 opened
