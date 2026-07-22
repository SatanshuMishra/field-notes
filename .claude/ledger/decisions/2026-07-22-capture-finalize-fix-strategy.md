Status: accepted
Date: 2026-07-22
Thread: journal-app-design

## Context
Real macOS voice + video captures do not save. Two distinct native root causes (session
2026-07-22-02): voice = record_macos 1.2.2 stop() hang; video = camera_macos 0.0.9 AVAssetWriter
concurrent-queue race. Human directed: proceed with the MOST robust fix, "robust+simple beats
fragile+complex."

## Decision
Voice: upgrade `record` to ^7.1.1 (rewritten record_macos 2.1.1) — DONE + hardware-verified.
Video: vendor camera_macos into the repo as a pinned path dependency and route recording through
Apple's self-finalizing AVCaptureMovieFileOutput (reusing the working preview), eliminating the
AVAssetWriter race at the root. Both: add a verify-on-disk finalize guardrail (poll file
exists+non-empty after stop; surface native errors; keep the bounded-timeout fail-safe 0a9902c).

## Consequences
- Self-owned video path: no dependency on an unmaintained plugin's live code, nothing to rebase.
- Rejected: camera_desktop 1.2.1 (fragile — 5 months old, unproven on this failure class);
  live external fork of camera_macos (fragile — drifts, ongoing rebase). Both fail "most robust."
- Video cannot be camera-tested autonomously (test binary denied camera TCC); human validates the
  real Save. Voice found a second bug (missing-parent-dir) fixed the same session.
- Corrects the open question in 2026-07-22-save-hang-timeout-noop-root-cause.md: the bounded
  timeout fails GRACEFULLY but does not persist; real fixes are the record upgrade + the video
  rewrite + the disk-verify guardrail.
