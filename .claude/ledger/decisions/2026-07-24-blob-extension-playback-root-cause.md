Status: accepted
Date: 2026-07-24
Thread: journal-app-design

## Context
Saved voice AND video entries would not play back. Capture/save was hardware-proven in PR #33/#34; the read path never was. Media is stored as extensionless SHA-256 content-addressed blobs at `media/blobs/<2-hex>/<62-hex>`.

## Decision
Store the file extension in `media_blobs.rel_path`, backfill existing rows, and add a three-candidate resilient read path (stored -> derived -> legacy). Shipped in PR #35.

## Consequences
- ROOT CAUSE, proven by a Swift AVURLAsset probe against the REAL blobs: AVFoundation selects a demuxer from the path UTI and never content-sniffs local files. Extensionless -> video `OSStatus -12847`, audio `-11828`. Identical bytes + any media extension -> opens with tracks + duration. `.txt`/`.bin` fail identically to no extension; a wrong-but-media extension (`.mp4` on QuickTime) plays fine.
- Both engines were affected because both route through AVURLAsset, which is why voice and video failed together.
- EXPORT was broken identically (ZIP entries keyed off `rel_path`) and nobody had noticed; this fix repairs it.
- NO schema migration: `rel_path` is free-form TEXT with no unique constraint, so `schemaVersion` stays 1 and `app_database.dart`'s fail-closed `onUpgrade` throw is never armed.
- REJECTED link shim: `dart:io` exposes no hard-link API (only symlinks), and a link outside `blobs/` survives `JournalDeleteAllService._wipeMediaFiles` and `MediaGarbageCollector._sweepFiles` — "Delete All Journal Data" would report success while the bytes stayed readable on disk.
- REJECTED forking video_player + just_audio to pass `AVURLAssetOutOfBandMIMETypeKey`: two more vendored plugins to fix what a filename fixes.
- `idFromRelPath` is the GC keystone and must accept BOTH forms: a false null leaks orphans (safe), a wrong non-null deletes a live blob (catastrophic).
