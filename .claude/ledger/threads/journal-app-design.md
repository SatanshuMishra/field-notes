---
thread: journal-app-design
status: paused
updated: 2026-07-24
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: AWAIT the user's SPECIFIC instructions for the next line of work; do NOT auto-select. Real voice + video capture saves are shipped and merged to main (902a659). Candidate post-merge follow-ups exist (latestBuffer preview-frame race; 30-min auto-stop UI push) but claim none without direction.
branch: main
---

## Status
Real macOS voice + video capture saves are SHIPPED and MERGED. PR #33 merged to origin/main as squash
902a659, landing: the videoRotationAngle crash fix, the H2 main-thread channel-reply fix, the
self-finalizing AVCaptureMovieFileOutput recording path, the on-disk media verify guardrail, the voice
record 7.x upgrade + dir-create, and the bounded-timeout fail-safe (0a9902c). Both voice and video were
hardware-verified on the real camera/mic before merge. Local main reconciled to 902a659; working tree clean.

## Active Goal
Capture (voice + video) is complete. Awaiting the user's direction for the next line of work.

## Next Step
Await the user's specific instructions in the fresh session; do not auto-select work.

## Open Risks
- Follow-up 1 (post-merge, unclaimed): latestBuffer preview-frame lockless race — PRE-EXISTING upstream,
  not introduced here; a fix needs real-camera testing.
- Follow-up 2 (post-merge, unclaimed): 30-min max-duration auto-stop is recoverable on next stop but the
  UI won't reflect it; wire an onVideoRecordingFinished push callback into the app.
- Branch fix/macos-capture-finalize is merged (squash) and deletable local+remote — left in place;
  branch deletion is destructive and needs explicit confirmation.

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
- third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift — initCamera (crash fix); movie-output delegate (H2 fix)
- lib/features/capture/core/journal_capture_service.dart — disk-verify guardrail (_finalize/_awaitFileReady)
- lib/features/capture/video/video_composer.dart — "Saving..." + 20s persist timeout
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-24-04-journal-app-design.md — PR #33 MERGED (902a659); local main reconciled; awaiting instructions
- sessions/2026-07-24-03-journal-app-design.md — SHIP: VIDCAP stripped, crash fix committed + pushed
- sessions/2026-07-24-02-journal-app-design.md — video VERIFIED working (human run); SHIP steps recorded
- sessions/2026-07-24-01-journal-app-design.md — REAL crash found (videoRotationAngle) + fixed
