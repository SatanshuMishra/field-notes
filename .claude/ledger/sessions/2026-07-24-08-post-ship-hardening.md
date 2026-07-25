# Session 2026-07-24-08 — post-ship-hardening

## Where it started
Resumed on the explicit slug `post-ship-hardening`, whose next step was the human's hardware test
and merge of PR #35. Verified the ledger against the repo first: working tree clean at 2cbd379, all
six thread pointers present on disk, container backup present, PR #35 OPEN and MERGEABLE. Ledger and
repo agreed — no divergence to correct.

## What shipped
- PR #35 MERGED by the human (`5cb5bad` on origin/main). The blob-extension playback fix is landed.
  Hardware test confirmed the fix works: video entries play, and a newly recorded voice entry plays
  repeatedly without issue.
- Local main fast-forwarded c0e414b -> 5cb5bad. New branch `fix/video-card-preview-and-controls`
  cut from it, working tree clean.
- Two NEW pre-existing video-card defects root-caused and verified against source (see below).
- `decisions/2026-07-24-video-card-eager-player-and-controls.md` — architecture decision, written at
  decision time, with rejected alternatives and their reasons.
- `plans/2026-07-24-video-card-controls-spec.md` — full hover-reveal implementation spec (state
  machine, platform split, accessibility floors, receipts list).
- New thread `video-card-playback-controls` created with crisp completion_criteria, so the umbrella
  thread does not absorb this work the way journal-app-design did.
- Committed as `061dc5e` (ledger + spec only; no code changed this session).

## Root causes established (verified by the orchestrator against source, not taken on report)
Defect 1 — every video card shows the RED crosshatch instead of a preview. Three stacked faults:
- `camera_video_recorder.dart:345` — `CameraMacosVideoRecorder.stop()` builds its `VideoRecording`
  with no `thumbnail:` argument. Its non-macOS sibling captures one via `takePicture()` (:77, :98).
  Every macOS video therefore persists `thumbnailMediaId: null`.
- `media_image.dart:43` — a null id falls to `_corrupt()`, the RED `CorruptMediaPlaceholder`.
  "Never had a poster" renders identically to "file is broken". A neutral tan placeholder exists
  and is simply never reached on this path.
- Existing DB rows already carry null, so fixing capture alone cannot heal them.

Defect 2 — no controls at all after playback. An architectural dead end, not a regression:
- `EntryVideoPlayer` lacks `seek()`, `positionStream`, `duration`; `VideoPlaybackState` has no
  `completed`. `EntryAudioPlayer` has all four — that asymmetry is exactly why the voice card works
  and the video card cannot.
- `video_body.dart:114-118` — `_surfaceReady` latches true and returns a bare `VideoPlayer` with
  zero chrome; `:123` permanently nulls the only play affordance via the `_started` latch. One-way
  door, no path back. Confirmed by reading the file directly.

Both defects are PRE-EXISTING and unrelated to PR #35. They were invisible only because nothing
played at all before it.

## Tried and failed
- Could NOT verify YouTube's auto-hide timeout from any authoritative source. Google publishes no
  number anywhere; third-party claims spread across 2-4s. Video.js documents its own default at 2s.
  Recorded 3s in the spec explicitly labelled as OUR design choice, not a copied fact, so a future
  reader cannot mistake it for spec. Same outcome for progress-bar pixel heights.
- Could not source-verify `flutter_video_thumbnail_plus`' macOS support: its published archive
  declares a `macos:` plugin entry but its public repo lags at v1.0.5 with no `macos/` directory and
  zero tags. Provenance gap; package rejected on that basis rather than on capability.
- No code was written or tested this session, so `flutter analyze` / `flutter test` were NOT run.
  Nothing is claimed as verified beyond the git and gh commands below.

## Verification
- `gh pr view 35` — expected merged; observed `state: MERGED`, `mergedAt: 2026-07-24T23:58:16Z`,
  `mergeCommit: 5cb5bad0706d9263cd9e281a9b42688c5253aab4`.
- `git merge --ff-only origin/main` — expected clean fast-forward; observed main at 5cb5bad.
- `git branch --show-current` + `git status --short` — expected new branch, clean tree; observed
  `fix/video-card-preview-and-controls`, no changes.
- Orchestrator read `video_body.dart`, `media_image.dart`, `video_playback.dart`,
  `audio_playback.dart` and grepped `camera_video_recorder.dart` directly to confirm every
  load-bearing claim in the subagent reports before designing against them.

## Running state
- none.

## Deferred + open
- The blob backfill has NOT yet run against the live container. PR #35 is merged, so the NEXT
  `flutter run -d macos` executes it against real journal media for the first time. Dry-run against
  a copy passed 6/6 with every sha256 unchanged, but this will be the first live run. Restore point:
  `/Users/satanshumishra/field-notes-container-backup-2026-07-24`.
- Export-ZIP-carries-extensions is still unconfirmed by the human (a post-ship-hardening criterion).
- Two junk voice entries (4096-byte synthetic blob) still present; human elected to delete them
  in-app. Do not write to the live DB to do it.
- Integration tests still write into the real journal container — the source of that junk blob.
- Merged branch `fix/media-blob-extension-playback` still exists locally and on the remote. Pruning
  is destructive and was deliberately NOT done without explicit consent.
- Capture-time macOS thumbnail (mirroring `CameraVideoRecorder._captureThumbnail`) is a fallback for
  poster slot 2, to be implemented only if the eager first frame proves blank on macOS hardware.

## Pick up here
Resume `video-card-playback-controls`. Branch `fix/video-card-preview-and-controls` is cut from
5cb5bad and clean. Read `plans/2026-07-24-video-card-controls-spec.md` first — it carries the state
machine, the platform split, the accessibility floors and the receipts list. Start with the
red receipts, then interface parity on `EntryVideoPlayer`, then the card rebuild, then the overlay.
Note the test footgun recorded in the spec: `defaultTargetPlatform` reports `android` in ALL widget
tests, so the macOS pointer path is silently untested without `debugDefaultTargetPlatformOverride`.
