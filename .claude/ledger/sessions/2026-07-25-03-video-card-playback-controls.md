# Session 2026-07-25-03 — video-card-playback-controls

## Where it started
Resumed on the explicit slug for the TEACHING pass the previous session queued: explain the 6-slot
concurrent video decoder cap from first principles. The user then escalated it twice — first to a second
look at whether 6 is right, then to a full architecture question about migrating the feeds to
virtualization. It ended as a written spec, not implementation. No production code was changed.

## What shipped
- The teaching explanation, delivered in chat, every claim verified against `video_slots.dart` rather than
  the ledger. No artifact written for it by design (the user asked for in-line, not `/report`).
- `docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md` (179 lines), commit
  `5ccd7ee`. Four MSPs with file scopes and dependencies, written for a fresh mitosis session with zero
  context. Authored by a delegated technical-writer; orchestrator verified its two most surprising claims.
- `decisions/2026-07-25-poster-first-supersedes-eager-decode.md`.

## The finding that changed the answer
The eager-decode architecture rests on one premise from
`decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md`: interaction gating "cannot meet
criterion 1: the macOS recorder writes no thumbnail." That premise is FALSE, and cheaply so. The vendored
plugin already exposes `CameraMacOSController.takePicture()`
(`third_party/camera_macos/lib/camera_macos_controller.dart:16`), whose native handler reads the live
sample buffer (`third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift:620-644`). It works DURING
recording because the plugin installs an `AVCaptureVideoDataOutput` alongside the `AVCaptureMovieFileOutput`
(`:516,526`) that keeps `latestBuffer` fed (`:1028`). No new native code, no new package.

Second reframing, from the audit: there is NO unbounded-decoder bug. `LruVideoSlots` already caps at 6
app-wide. The real defect is that the `Column` mounts every card at once, so the cap is consumed in MOUNT
order, not VIEWPORT order — on a 10-video day, entries 1-6 hold all six slots while the card the user is
looking at is denied. Misallocation, not exhaustion. This lowers the severity framing materially.

## Tried and failed
- **My own first recommendation was superseded within the same session.** After the teaching pass I
  recommended splitting `assumedConcurrentVideoDecoderCap` per platform (6 desktop / 3 Android) on the
  Android CDD evidence. The deeper audit then made it largely moot: poster-first takes at-rest decoders to
  0 and playback to 1, so the cap stops being the binding constraint. The spec now explicitly records
  "do not split the cap" as a rejected alternative. Lesson: the second-look answer was right for the
  question asked and wrong for the question underneath it — audit the premise before tuning the constant.
- **One of my citations was wrong and the writer caught it.** I cited `PictureFormat.tiff` at
  `camera_macos_controller.dart:144-146`; that file is only 99 lines. Correct location is
  `camera_macos_method_channel.dart:143-160`, and the real root cause is deeper than the hint: the native
  dispatcher IGNORES the per-call format argument entirely (`CameraMacosPlugin.swift:153-154` passes the
  stored instance field), so the format must be set on the `CameraMacOSView(...)` built in
  `CameraMacosVideoRecorder.openSession` (`camera_video_recorder.dart:242-258`), not at the call site.
- **A live trap in the vendored plugin, verified independently.** `PictureFormat` has BOTH `jpg` and `jpeg`
  (`camera_macos_arguments.dart:6`). The Swift switch maps `"jpg"` -> `.jpeg` (`CameraMacosPlugin.swift:326-327`)
  and a typo'd `"jepg"` -> `.jpeg2000` (`:329-330`). `PictureFormat.jpeg.name` matches NEITHER, so it falls
  to `default: .tiff` (`:342`). The implementer must use `PictureFormat.jpg`. The writer's summary back to
  me described this slightly loosely (as hitting the typo case); the spec text itself is accurate.
- The codebase-analyst map was accurate on every point spot-checked this time, unlike session 02. Still
  spot-checked rather than trusted.

## Verification
- `video_slots.dart` read in full (269 lines) before explaining any of it; every mechanism described in the
  teaching pass traced to a line.
- Provider cap: `video_slots_provider.dart:10` omits `cap`, so the default 6 applies; `LruVideoSlots(` has
  exactly one construction site repo-wide.
- Phase machine, pin semantics, waiting render branch, eviction-during-load staleness guard — each grepped
  and read directly (`video_body.dart:27,279-330,390-412,174-195,330-372`).
- `grep -rn "setEnableDecoderFallback" ~/.pub-cache/hosted/pub.dev/video_player_android-2.12.0` — zero hits,
  confirming no ExoPlayer software-decode fallback.
- macOS plugin discards the diagnosis: `FVPVideoPlayer.m:395-397` forwards only `localizedDescription`;
  `FVPEventBridge.m:83` sends `details:nil`. Apple's `-11839` decoder-busy code never reaches Dart.
- `wc -l` on the spec — 179 lines. Committed clean; `git log --oneline -1` returned `5ccd7ee`.
- No `flutter analyze` / `flutter test` run this session: zero production code changed, docs only.

## Running state
- none. No subagents in flight, nothing backgrounded, working tree clean.

## Deferred + open
- **PR #38 is a BLOCKING PRECONDITION and is still open + hardware-unconfirmed.** It contains every seam the
  new spec touches. Nothing in the spec can start until it is merged to `main` or the work branches from
  `fix/video-card-preview-and-controls`.
- Phase 3 (Today `CustomScrollView`) is deliberately NOT authorized. It is conditional on a profile taken
  after Phase 1 ships, because Phase 1 removes the decoder pressure that would justify it.
- No pagination anywhere in the query layer (`entries_dao.dart:70-90` has no `.limit`). Orthogonal,
  unmitigated, and possibly a better answer than slivers for a genuinely huge day.
- Backfill for thumbnail-less macOS videos is NOT needed — the user confirmed all current data is temporary
  and will be purged before release. Do not build one; no file-based frame extractor exists in the repo.
- `post-ship-hardening` sibling thread remains paused and untouched.
- Everything inherited from sessions 09/10/01/02 is still open: controller extraction from `video_body.dart`
  (672 lines), voice-card twins, the unreceipted responsive sizing band, readout contrast ~2.9:1.

## Pick up here
The spec is written and committed; implementation happens in a FRESH session via `mitosis`, not here.
First real action is disposing of PR #38 (hardware run, then merge), because it gates all four MSPs.

## Demoted from PROJECT.md (80-line cap)

Retained verbatim so nothing is lost:

- DB ROUND-TRIP PROVEN (session 2026-07-22-01): real capture write path stored 2 new entries into the
  on-disk DB (`~/Library/Containers/dev.satanshumishra.fieldNotes/Data/Documents/field_notes.sqlite`); a
  separate sqlite3 process confirmed them AFTER the writer exited (entries 2->4); live app rendered DB rows
  (live-feed-01.png). Store+retrieve are proven end-to-end.
- macos/Flutter/GeneratedPluginRegistrant.swift shipped in #21 despite the plan ordering it reverted.
  Content is byte-identical to what `flutter pub get` regenerates, so it was harmless — but
  capture-photo/voice/video all add plugins and will all regenerate this same file. Treat it as a SECOND
  systemic conflict file alongside pubspec.yaml: merge those three one-at-a-time and regenerate rather than
  hand-resolving. (Historical: 31/31 shipped, no further MSP merges of that era remain.)
