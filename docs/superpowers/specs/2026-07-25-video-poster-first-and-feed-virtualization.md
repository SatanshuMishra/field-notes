# Video poster-first decode gate and feed virtualization

Status: AUTHORIZED for execution 2026-07-25, MSPs 1-3 only; MSP 4 remains unauthorized. Project name is **field-notes** (the on-disk directory `fireplace` is a legacy path only, not the product name).

This spec is written for a fresh `mitosis` session with no memory of the analysis that produced it. Every claim about existing code below was verified against the repository at commit range ending `3a24ff6` on branch `fix/video-card-preview-and-controls`; line numbers are exact as of that point but may drift — re-verify with Read/Grep before editing, since the code, not this document, is the source of truth.

## Preconditions (blocking, read first)

1. **SATISFIED as of 2026-07-25.** PR #38 is **MERGED** to `main` as squash commit `da0a487` (verified via `gh pr view 38`). Every seam this spec touches — `VideoSlots`/`LruVideoSlots` (`lib/features/entry_cards/playback/video_slots.dart`), the `VideoBody` phase machine (`lib/features/entry_cards/cards/video_body.dart`), and the controls overlay — is now on `main`. Branch all MSP work from `main`. Note that merging did NOT perform the human macOS hardware run those nine criteria demand; that gap is tracked in the ledger thread and is independent of this spec's execution.
2. Do not start any MSP below against a tree that lacks these files — confirm `lib/features/entry_cards/playback/video_slots.dart` exists on your base before editing.
3. This project's CI runs no Dart tests (stated by the task owner; corroborated by the ledger's repeated warnings that "green checks on PR #38 are vacuous"). Treat every green GitHub check on any MSP branch as non-evidence. `flutter test` run locally, plus an eventual human macOS/Android hardware pass, are the only real gates.

## Problem

### The proximate mechanism

Both entry feeds mount every card for a day unconditionally:

- `lib/features/today/today_entry_feed.dart:59` — `TodayEntryFeed.build` returns a plain `Column` over the full `entries` list (via a `for` loop, no `ListView`/slivers).
- `lib/features/day_detail/day_detail_panel.dart:143` — `_DayDetailPanelState._content` returns the same shape: a plain `Column` over all entries.

Each `VideoBody` (`lib/features/entry_cards/cards/video_body.dart`) calls `_startPrepare(VideoSlotEvictionRights.none)` from `initState` (`:72-75`), which resolves media and attempts to acquire a hardware video decoder slot as soon as the card mounts — regardless of whether the card is on screen.

### Why this is NOT an unbounded-decoder leak

A hard cap already exists. `LruVideoSlots` (`lib/features/entry_cards/playback/video_slots.dart:44`) enforces `assumedConcurrentVideoDecoderCap = 6` (`:11`) as an LRU registry: once 6 slots are held, `acquire` either returns `null` (eviction rights `none`, the case for passive mount) or evicts the least-recently-used *unpinned* holder (eviction rights `evictUnpinned`, the case for an explicit user tap — see `:66-92`). This registry is a single app-wide singleton, provided via `@Riverpod(keepAlive: true)` in `lib/features/entry_cards/playback/video_slots_provider.dart:8-9`, and both feeds watch the *same* instance: `today_entry_feed.dart:106` (`videoSlots: ref.watch(videoSlotsProvider)`) and `lib/features/day_detail/day_detail_entry_tile.dart:35` (identical call). There is no per-feed or per-platform duplication of the cap.

**The real defect is misallocation, not exhaustion.** On a day with, say, 10 video entries, cards 1-6 mount in document order and claim all six slots the instant the feed builds — even if the user is scrolled down to entry 9. Entry 9's card is denied a slot (`acquire` returns `null` under `evictionRights: none`) and falls back to whatever non-decoded state `VideoBody` renders for a denied claim, while six decoders sit warm on off-screen cards nobody is looking at. The cap does its job (no crash, no unbounded growth); it is applied in **mount order** when it should be applied in **viewport order**. Do not propose per-platform cap changes, larger caps, or decoder-pool redesigns to fix this — that solves a problem that does not exist here. The fix is to stop paying for a decoder before the user asks for one (Phase 1) and, if warranted, stop mounting cards the user cannot see (Phases 2/3).

### Why it is more acute on Android

- The Android Compatibility Definition Document guarantees 6 simultaneous hardware video decoder sessions **only** for devices that declare a `MEDIA_PERFORMANCE_CLASS` — baseline (non-performance-class) devices get no such guarantee. See https://source.android.com/docs/compatibility/14/android-14-cdd (search "concurrent codec instances" / performance class sections).
- A real mid-range device has been reported failing at exactly 6 concurrent `video_player` instances: https://github.com/flutter/flutter/issues/79623.
- Grepping the vendored `video_player_android` 2.12.0 package source (`~/.pub-cache/hosted/pub.dev/video_player_android-2.12.0`) for `DefaultRenderersFactory` and `setEnableDecoderFallback` returns **zero matches** (verified directly, not inferred) — the plugin never configures a software-decoder fallback path. On Android, running out of hardware decoder sessions is a hard failure with no software-decode floor beneath it.
- macOS has materially more headroom and Apple documents no fixed concurrent-decode-session limit for AVFoundation `[unverified]` — no authoritative Apple source for a numeric cap was found; this is stated as an asymmetry (Android has a documented floor risk, macOS does not), not a guarantee macOS is limitless.

## Phase 1 — Poster-first (the root fix)

Stop acquiring a hardware decoder just to show a still frame. Render the captured thumbnail immediately; acquire a decoder only when the user expresses intent to play.

### Phase 1a — macOS capture writes a thumbnail

**Current state, Android/iOS (already correct):** `CameraVideoRecorder.stop()` (`lib/features/capture/platform/camera_video_recorder.dart:69-96`) calls `_captureThumbnail(controller)` at `:77`, implemented at `:98-105` via the `camera` package's `controller.takePicture()`, wrapping the result as `CaptureFile(file: File(still.path), mime: videoThumbnailMime)` where `videoThumbnailMime = 'image/jpeg'` is declared at `:13`. This `CaptureFile` is threaded into `VideoRecording(thumbnail: thumbnail, ...)` at `:79-87`.

**Current state, macOS (the gap):** `CameraMacosVideoRecorder.stop()` (`camera_video_recorder.dart:332-358`) returns `VideoRecording(media: ..., durationMs: ..., ...)` at `:345-352` with **no `thumbnail:` argument at all**, so it defaults to `null`. This is the entire reason macOS-recorded videos have no poster today.

**The fix requires no new native code and no new package.** The capability is already vendored in `third_party/camera_macos`:

- `CameraMacOSController.takePicture()` — `third_party/camera_macos/lib/camera_macos_controller.dart:16-18` — calls through to the platform instance's `takePicture()`.
- The concrete implementation is `third_party/camera_macos/lib/camera_macos_method_channel.dart:143-160`, which invokes the native `'takePicture'` method channel call and returns `CameraMacOSFile(bytes: result["imageData"] as Uint8List?)` (`:157`) — **bytes, not a file path.** `CameraMacOSFile` (`third_party/camera_macos/lib/camera_macos_file.dart:3-9`) carries both a `url` and a `bytes` field; only `bytes` is populated by `takePicture`. The implementer must write these bytes to a temp file (`dart:io` `File(...).writeAsBytes`) to build a `CaptureFile(file: File(path), mime: ...)` matching the shape `CameraVideoRecorder` already uses.
- The native Swift handler is `takePicture(_:_:)` in `third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift:620-644`. It reads a live sample buffer (`latestBuffer`, `:622` / `:635`) and encodes it — **this works during an active recording** because when the session uses `AVCaptureMovieFileOutput` (set up when `useMovieFileOutput` is true, which `CameraMacosVideoRecorder.openSession` already passes via `CameraMacOSView(useMovieFileOutput: true, ...)` at `camera_video_recorder.dart:247`), the plugin *also* installs a parallel `AVCaptureVideoDataOutput` (`CameraMacosPlugin.swift:516` for the movie-output branch, `:526` for the always-present preview output) whose sample buffer delegate keeps `latestBuffer` fed on every frame (`:1028`, `latestBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)`).

**Two verified landmines the implementer must resolve, not just "reconcile":**

1. **Default format is TIFF, not JPEG, and the per-call format argument is silently ignored.** `CameraMacOSController.takePicture()` (`camera_macos_controller.dart:16-18`) takes **no parameters** — it cannot select a format per call. The actual output format comes from an instance-level Swift field, `pictureFormat` (`CameraMacosPlugin.swift:71`, `var pictureFormat: NSBitmapImageRep.FileType? = .tiff`), which is set **once, at `initialize()` time**, from the `pformat` string sent by `CameraMacOSView.pictureFormat` (Dart default `PictureFormat.tiff`, `third_party/camera_macos/lib/camera_macos_view.dart:75`, flowed through `initState` at `:96-110` to `initialize(pictureFormat: widget.pictureFormat, ...)`). The native `"takePicture"` dispatch case (`CameraMacosPlugin.swift:153-154`, `case "takePicture": takePicture(result, pictureFormat)`) passes this stored instance field, **not** anything from the per-call method-channel arguments that `camera_macos_method_channel.dart:150` sends (`{'format': format.name, ...}` — that payload is dead code as far as this native handler is concerned). **Fix:** the `CameraMacOSView(...)` constructed in `CameraMacosVideoRecorder.openSession` (`camera_video_recorder.dart:242-258`) must pass an explicit `pictureFormat:` argument; changing anything at the `takePicture()` call site alone will not work.
2. **`PictureFormat.jpeg` is the wrong enum value — it silently falls back to TIFF.** The Dart enum is `enum PictureFormat { jpg, jpeg, tiff, bmp, png, raw }` (`third_party/camera_macos/lib/camera_macos_arguments.dart:6`). The Swift string switch that maps the `pformat` argument to a native format (`CameraMacosPlugin.swift:325-344`) only matches the literal string `"jpg"` to map to `NSBitmapImageRep.FileType.jpeg` (`:326-328`); there is a typo at `:329` (`case "jepg":`, not `"jpeg"`) that maps to `.jpeg2000` and is unreachable for the value we care about. `PictureFormat.jpeg.name` is the string `"jpeg"`, which matches neither `"jpg"` nor the typo'd `"jepg"`, so it falls through to the `default: .tiff` case (`:341-343`). **The implementer must use `PictureFormat.jpg`, not `PictureFormat.jpeg`,** or the fix will appear to compile and run but silently keep producing TIFF bytes. This is a genuine bug in the vendored library, worth a one-line note in the diff (not a comment in code) so a future reader is not tempted to "fix the typo" upstream without checking whether that changes call-site behavior expectations elsewhere in the repo (grep for other `pformat`/`PictureFormat` usages first if that path is ever taken; out of scope here).

Once bytes are captured, the mime stored on the resulting `CaptureFile` must match the actual encoded bytes (JPEG bytes stored under `videoThumbnailMime = 'image/jpeg'`, matching the Android/iOS convention) — do not store a mismatched mime.

**Explicitly rejected approach:** the `video_thumbnail` pub package. It supports Android and iOS only, with no macOS platform implementation — https://pub.dev/packages/video_thumbnail. Do not add it as a dependency for this work.

**Acceptance criteria, Phase 1a:**
- `CameraMacosVideoRecorder.stop()` returns a `VideoRecording` whose `thumbnail` is non-null after any successful recording where at least one frame was buffered.
- The thumbnail's `CaptureFile.mime` is `'image/jpeg'` and the bytes on disk are genuinely JPEG-encoded (not TIFF bytes mislabeled as JPEG).
- No new pub dependency is added. No new native (Swift) code is written — only a Dart-level constructor argument change and byte-to-file plumbing.
- Existing `stop()` behavior (media file path, duration, exception semantics) is unchanged when thumbnail capture itself fails — thumbnail capture failure must degrade to `thumbnail: null` (mirroring `_captureThumbnail`'s existing `catch (error) { return null; }` at `camera_video_recorder.dart:102-104`), never fail the whole recording.

### Phase 1b — Gate decode on user intent

In `lib/features/entry_cards/cards/video_body.dart`, `initState` (`:72-75`) unconditionally calls `_startPrepare(VideoSlotEvictionRights.none)`, which triggers media resolution and decoder-slot acquisition on mount.

**Required change:** when `widget.entry.thumbnailMediaId != null`, the card must render the poster and must **not** call `_startPrepare` (and therefore must not attempt slot acquisition) until the user taps the transport control. The poster-rendering path already exists and is exercised today only as a fallback:

- `_showCapturedPoster` getter, `video_body.dart:483-484`: `widget.entry.thumbnailMediaId != null && !_isRenderingVideo`.
- Its consumer, `video_body.dart:640-645`: renders `MediaImage(resolver: widget.resolver, mediaId: widget.entry.thumbnailMediaId, errorLabel: 'Video')` inside the `Stack` built by `_layers()`.
- The transport tap handler already exists at `_onTransportTap`, `video_body.dart:546-559`, which calls `_attemptLoad(VideoSlotEvictionRights.evictUnpinned)` when `_canClaimSlot` is true — this is the existing "user intent" entry point Phase 1b should route the deferred `_startPrepare`/`_attemptLoad` call through, rather than inventing a new one. (`_canClaimSlot` itself was not re-verified line-by-line in this pass; confirm its current definition before wiring into it.)

**Amendment (ratified 2026-07-25):** `initState` is not the only passive entry into decode. `didUpdateWidget` re-enters via `_restart` whenever the resolver instance or `entry.mediaId` changes, and the Today feed does exactly this after first paint — `today_entry_feed.dart:56-57` swaps `_PendingMediaResolver` for the real resolver — so a gate on `initState` alone is bypassed by every poster card on Today. The gate therefore covers BOTH passive entry points: on any resolver or media-identity change, a poster-bearing card re-arms the gate — invalidating any in-flight prepare (generation bump, `_playWhenReady` cleared) and releasing any decoder slot it holds — instead of decoding. Only explicit user intent (`_onTransportTap`, `_onRetryPressed`) may acquire a slot on a poster-bearing card. This ratifies the review-round `didUpdateWidget` edits as in-scope and is implemented in final form by plan Task 3 (`_deferDecodeUntilIntent`). Ledger record: `.claude/ledger/decisions/2026-07-25-didupdatewidget-gate-ratified-as-amendment.md`.

**Non-negotiable design properties:**

1. **The gate keys off `thumbnailMediaId != null`, never off `defaultTargetPlatform` or any other platform check.** This makes the behavior platform-agnostic by construction: Android and iOS entries (which already carry thumbnails via the existing `_captureThumbnail` path) benefit immediately without any Android-specific code, and macOS benefits as soon as Phase 1a ships. Do not special-case any platform in this gate.
2. **When there is no thumbnail** (`thumbnailMediaId == null` — true for all pre-existing video entries and for any future capture path that still fails to produce one), the current eager-decode-on-mount behavior is retained unchanged as a graceful fallback, still bounded by the existing 6-slot cap. This phase must not regress any entry that lacks a poster.
3. **`assumedConcurrentVideoDecoderCap` stays at 6 and is not split per platform.** Poster-first reduces the number of *at-rest* (mounted-but-not-playing) decoders to zero and *playback* concurrency to however many cards a user actually taps to play (practically 1, rarely more), which removes the pressure a per-platform cap split would have been trying to relieve. Splitting the cap is a **rejected alternative** — record it as such so a future reader does not re-litigate it (see Rejected Alternatives).
4. **No backfill for existing video entries.** Entries captured before this fix have `thumbnailMediaId == null` and will keep falling back to eager decode (property 2) — this is acceptable because, per the project owner, all current data is temporary and will be purged before release. Do not build a backfill migration or a file-based frame extractor for existing entries; no such extractor exists anywhere in this repository today, and none should be added as part of this work.

**Acceptance criteria, Phase 1b:**
- A `VideoBody` whose `entry.thumbnailMediaId` is non-null does not call `widget.slots.acquire(...)` at mount (verifiable via the existing `LruVideoSlots`/harness accounting — see Testing/Receipts).
- The same card, after a simulated transport tap, does acquire a slot and proceeds through the existing prepare/load path.
- A `VideoBody` whose `entry.thumbnailMediaId` is null continues to acquire a slot at mount exactly as it does today (no behavior change on this path).
- No `defaultTargetPlatform`/`Platform.isX` check appears anywhere in the new gating logic.
- (Amendment, 2026-07-25) A poster-bearing card whose resolver instance or `entry.mediaId` changes after mount does not acquire a slot — and releases any slot it already holds — until the next transport tap; this covers the Today-feed resolver swap.

## Phase 2 — Virtualize the Day-detail feed

`day_detail_panel.dart:143` builds a plain `Column`, but unlike the Today feed, it already sits inside a height-bounded ancestor chain:

- `Flexible` at `:113`, wrapping a `SingleChildScrollView` at `:114-116`, which wraps the `Column` in question.
- That `Flexible` lives inside the outer `Column` (`:86-119`) inside a `StickerCard` inside a `ConstrainedBox(constraints: BoxConstraints(maxWidth: 520, maxHeight: 520))` at `:78-82`.
- The whole panel is presented as a modal via `showGeneralDialog` in `lib/features/day_detail/show_day_detail.dart:9-49` (specifically the `pageBuilder` at `:23-29` returning `DayDetailPanel(date: date)`).

Because the max height is already fixed at construction (520 logical px, `DayDetailPanel.maxHeight` default at `day_detail_panel.dart:31`), swapping the inner `Column` + `SingleChildScrollView` for a `ListView.builder` is a direct, low-risk change — no `CustomScrollView`/sliver rewrite is needed, since a single bounded `ListView` is sufficient. Cards already carry `ValueKey<String>(entries[index].id)` (`:150`), so element recycling across scroll positions is already safe with respect to widget identity.

**Acceptance criteria, Phase 2:**
- `_content` in `day_detail_panel.dart` builds a `ListView.builder` (or equivalent bounded, virtualizing scrollable) instead of a `Column` inside `SingleChildScrollView`, within the existing 520px bound.
- With a day containing "many" entries (test-defined, e.g. 30+), only a bounded subset of `DayDetailEntryTile` widgets exists in the widget tree at once — see Testing/Receipts for the exact assertion shape.
- Existing key-based identity (`ValueKey<String>(entries[index].id)`) is preserved.
- No visual regression to the 520x520 modal bound, `DayDetailHeader`, `MoodBannerForDate`, or `DayDetailEntriesBar` sections above the list.

## Phase 3 — Today feed virtualization (CONDITIONAL — do not execute on prediction)

`lib/features/today/today_screen.dart` has **no bounded ancestor** anywhere in its tree, unlike Day-detail:

- Stacked layout: `SingleChildScrollView(padding: ..., child: main)` at `:39-42`.
- macOS "withRail" layout: `SingleChildScrollView(padding: ..., child: Row(...))` at `:44-57`, where the `Row` (`:46-56`) contains `Expanded(child: main)` (`:49`) plus a fixed `SizedBox(width: todayRailWidth /* 300 */, child: TodayRightRail(date: date))` (`:51-54`) — the rail scrolls in lockstep with the main column inside the same `SingleChildScrollView`.
- `resolveTodayLayout` (`lib/features/today/today_layout.dart:7-11`) maps `TargetPlatform.macOS` to `TodayLayout.withRail` and every other platform to `TodayLayout.stacked` — these are two structurally different widget trees, both of which any virtualization change must handle.
- `main` itself (`today_screen.dart:25-35`) is a `Column` containing, in order: `TodayHeader` (`:29`), a `SizedBox(height: 20)` spacer, `MoodBannerForDate` (`:31`), another spacer, then `TodayEntryFeed` (`:33`) — the actual card list is only the last of five children.

**Virtualizing this requires a genuine `CustomScrollView` rewrite** — the header, spacer, mood banner, spacer, and feed each become a `SliverToBoxAdapter` (roughly 5 for the stacked branch) with the feed's own children becoming real slivers (not another `SliverToBoxAdapter` wrapping a `Column` — see forbidden shortcuts below); the `withRail` branch needs an analogous but structurally distinct treatment for the `Row`-with-fixed-rail layout.

**Forbidden shortcuts (with verified/cited reasoning):**

- **`shrinkWrap: true` on a `ListView`/`CustomScrollView` is forbidden as a substitute for a real sliver rewrite.** `shrinkWrap` sizes the scrollable to its children's total main-axis extent, which effectively makes the viewport as tall as its content — the "bounded viewport" laziness the sliver protocol depends on is defeated, so every child still builds. See the discussion and confirmed-symptom reports at https://github.com/flutter/flutter/issues/26072 and the related lazy-rendering fix context at https://github.com/flutter/flutter/pull/181092. This is a rewrite that changes nothing about eager building.
- **Wrapping the entire card list in a single `SliverToBoxAdapter` is equally forbidden and for the same underlying reason** — `SliverToBoxAdapter` adapts one arbitrary box widget into one sliver; that box widget (e.g. a `Column` of every card) still builds and lays out its full non-lazy subtree before the sliver protocol ever gets a chance to skip anything. See https://api.flutter.dev/flutter/widgets/SliverToBoxAdapter-class.html — it is documented as wrapping a single child, not a lazily-built list.

**Phase 3 is conditional, not authorized in this spec.** Execute it only after:

1. Phase 1 has shipped and a profile measurement is taken on real hardware (or as close to it as available) confirming there is still a scroll-performance or widget-count problem worth solving. Phase 1 removes decoder pressure entirely — once at-rest decode cost is zero, Phase 3 becomes a pure scroll/widget-count question, not a decoder-safety question, and may or may not be worth its rewrite cost.
2. The measurement is reviewed by whoever owns this spec's execution; Phase 3 must not be executed purely on the prediction that it is needed.

**Orthogonal risk to flag, not silently resolve:** there is no pagination in the query layer beneath either feed. `EntriesDao.watchActiveEntriesForDay` and `watchActiveEntriesForDate` (`lib/data/journal/entries_dao.dart:70-90`) both stream every matching row with no `.limit(...)` anywhere in the query builder chain. For a day with a genuinely large entry count, adding pagination at the query layer may be a better fix than virtualizing widget building — the implementer executing Phase 3 (if authorized) must surface this as an explicit decision point, not resolve it silently by picking slivers over pagination (or vice versa) without recording the choice.

**Why Phase 1, not Phase 3, is the root fix — record for the reader:** virtualization does not reduce live (mounted) cards to only the ones currently visible. Flutter's default `cacheExtent` keeps roughly 250 logical px of additional content built on each side of the viewport (https://api.flutter.dev/flutter/rendering/RenderAbstractViewport/defaultCacheExtent-constant.html), so with the existing ~500px-tall video cards (21:9 aspect, per the current preview sizing) on a roughly 900px viewport, expect on the order of 3-4 cards alive simultaneously even after virtualization — comfortably under the 6-slot cap on its own, but proof that virtualization alone does not make "only visible cards decode" true. Poster-first (Phase 1) is what actually removes the at-rest decoder cost; Phase 3 is a scroll-performance optimization on top of that, not a substitute for it.

**Acceptance criteria, Phase 3 (if and when authorized):**
- A profile measurement taken after Phase 1 ships, with a written note of what was measured and why virtualization is still warranted.
- Both `TodayLayout.stacked` and `TodayLayout.withRail` trees are converted, each verified independently (they are structurally different).
- The pagination-vs-slivers decision is explicitly recorded, not silently picked.
- No `shrinkWrap: true` and no list-wrapped-in-a-single-`SliverToBoxAdapter` shortcut is present in the diff.

## MSP decomposition

This work is executed by the `mitosis` skill as a set of independently shippable MSPs (minimum shippable products), each leaving the branch green on merge (the green-branch invariant).

| MSP | Scope | File scope | Depends on | Shippable alone? |
|---|---|---|---|---|
| **MSP 1** | Phase 1a: macOS capture writes a thumbnail | `lib/features/capture/platform/camera_video_recorder.dart` (the `CameraMacosVideoRecorder` class and its `CameraMacOSView` construction); no changes to `third_party/camera_macos/**` (vendored, treated as a dependency — only its public API is consumed); test additions under `test/features/capture/video/` | PR #38 merged/branched-from (precondition) | Yes — it writes a thumbnail that nothing yet requires. No behavior downstream changes until MSP 2 consumes it. |
| **MSP 2** | Phase 1b: poster-first decode gate | `lib/features/entry_cards/cards/video_body.dart` **only** in `lib/`; test additions under `test/features/entry_cards/` reusing `test/features/entry_cards/support/video_card_harness.dart` | PR #38 merged/branched-from. Benefits fully from MSP 1 on macOS, but is independently correct and green even if MSP 1 has not shipped yet — Android/iOS entries already have thumbnails today via the existing `_captureThumbnail` path, so the gate is effective there immediately. | Yes |
| **MSP 3** | Phase 2: Day-detail virtualization | `lib/features/day_detail/day_detail_panel.dart`; test additions under `test/features/day_detail/` | PR #38 merged/branched-from. Independent of MSP 1 and MSP 2 — touches a disjoint file. | Yes |
| **MSP 4** | Phase 3: Today feed virtualization | `lib/features/today/today_screen.dart`, `lib/features/today/today_layout.dart` (if the sliver rewrite needs layout-shape changes), possibly `lib/data/journal/entries_dao.dart` if pagination is chosen over/alongside slivers | Gated on the Phase-1 profile measurement described above | **Not yet authorized.** Do not schedule or start until the measurement is taken and reviewed. |

Keep MSP 2 scoped to `video_body.dart` as its only `lib/` file so it stays parallel-safe with MSP 1 and MSP 3, both of which touch disjoint files.

## Rejected alternatives

- **Splitting `assumedConcurrentVideoDecoderCap` per platform (e.g. lower cap on Android).** Rejected: Phase 1 removes at-rest decoder pressure to zero and playback concurrency to (practically) 1, which supersedes the need for a platform-specific cap. A per-platform cap also reintroduces a `defaultTargetPlatform` branch into a subsystem this spec deliberately keeps platform-agnostic (see Phase 1b property 1).
- **`shrinkWrap: true` as a virtualization shortcut.** Rejected: defeats the sliver protocol's laziness by making the viewport's main-axis extent match its content, so every child still builds regardless of visibility. See https://github.com/flutter/flutter/issues/26072 and https://github.com/flutter/flutter/pull/181092.
- **Wrapping the full card list in one `SliverToBoxAdapter`.** Rejected for the same underlying reason as `shrinkWrap` — see https://api.flutter.dev/flutter/widgets/SliverToBoxAdapter-class.html; it adapts a single already-built box subtree, it does not make that subtree lazy.
- **`visibility_detector` (Google-published) as a viewport-gating mechanism.** It does support macOS, but its repository was archived 2025-10-13, is now read-only, with a last commit in December 2023 — https://github.com/google/flutter.widgets. Rejected as an unmaintained dependency being reached for to solve a problem Phase 1 (poster-first) already solves without any new dependency.
- **`video_thumbnail` pub package for macOS thumbnail generation.** Rejected: Android/iOS only, no macOS platform implementation — https://pub.dev/packages/video_thumbnail. The vendored `camera_macos` plugin already has the needed capability (Phase 1a).
- **Backfilling thumbnails for existing video entries.** Rejected: per the project owner, all current data is temporary and will be purged before release. Building a backfill migration spends effort on data that will not exist at release.
- **A file-based frame-extraction fallback (e.g. decoding the first frame of an existing `.mp4` without a capture-time thumbnail).** Rejected for the same reason as backfill, and also because no such extractor exists anywhere in this repository today (verified: no `video_thumbnail`-equivalent, no ffmpeg binding, no frame-extraction utility found under `lib/`) — writing one is new scope this spec explicitly excludes.

## Testing / Receipts

Apply the project's test admission gate: a test is admitted only for new or changed behavior, asserted through a public/observable surface — never for styling or pure-visual tweaks (both exempt by default).

- **MSP 1.** Assert that `CameraMacosVideoRecorder.stop()` returns a `VideoRecording` with a non-null `thumbnail` whose `CaptureFile.mime` is `'image/jpeg'` and whose bytes are genuinely JPEG (not mislabeled TIFF). The existing seam to extend is `test/features/capture/video/camera_macos_release_test.dart`, which already mocks the `camera_macos` platform `MethodChannel` (channel name `'camera_macos'`) via a `_NativeCameraSpy` class (`:25-63`) installed with `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`. As of this pass, `_NativeCameraSpy.handle` only responds to `'listDevices'`, `'initialize'`, and `'destroy'` (`:42-61`) — it does **not** yet handle `'takePicture'` or `'stopRecording'`, so extending it (or adding a sibling spy in a new or existing test file in the same directory) to return fake image bytes for `'takePicture'` and a fake file URL for `'stopRecording'` is required work, not something already covered. `test/features/capture/video/camera_video_recorder_test.dart` exists today but only asserts on string constants (`videoRecordingMime`, `videoThumbnailMime`, filename builders) — it is not itself the behavioral seam, though it is the natural place to add the new assertion or a sibling file in the same directory.
- **MSP 2 — the load-bearing receipt.** Assert that a `VideoBody` with a non-null `thumbnailMediaId` acquires **no** decoder slot at mount, and **does** acquire one after a simulated transport tap. Reuse `test/features/entry_cards/support/video_card_harness.dart`, which already provides: `videoCardColumn({..., String? thumbnailMediaId, ...})` (`:109-144`) to build one or more `VideoBody` cards sharing a single `VideoSlots` instance; `slotsWithCapOf(int cap)` (`:93-97`) to construct an `LruVideoSlots` with a test-controlled cap and automatic teardown; and `cardAt(index)` / `inCard(index, key)` (`:146-149`) for locating widgets within a specific card. Do not build a new harness — this one already exists for exactly this purpose (multi-card slot accounting).
- **MSP 3.** Assert that with "many" entries (pick a number clearly above any plausible single-screen count, e.g. 30) rendered inside the bounded 520px `DayDetailPanel`, the number of built `DayDetailEntryTile` widgets in the tree is materially smaller than the entry count (verifiable via `find.byType(DayDetailEntryTile).evaluate().length` compared against the full entry count).
- **CI is not a gate.** This project's CI runs no Dart tests (per the task owner and corroborated by the ledger's own repeated warnings). A green GitHub check on any of these MSPs' PRs asserts nothing; local `flutter test` plus an eventual human hardware run (particularly for MSP 1's macOS capture path) are the only real gates.
- **Mutation-check the MSP 2 receipt specifically.** This codebase's ledger records a documented history of receipts that were "green and structurally blind" (`.claude/ledger/threads/video-card-playback-controls.md`, Open Risks section: "Receipts were green and structurally BLIND for a whole round... hiding two CRITICALs; four vacuous receipts were caught by mutation and NONE by reading"). Before considering MSP 2 done, deliberately break the gate under test (e.g. temporarily remove the `thumbnailMediaId != null` check, or temporarily call `_startPrepare` unconditionally in `initState`) and confirm the new test goes red, then restore the fix and confirm green again. Do not accept a receipt that has never been observed to fail.

## Out of scope

Everything already recorded as out of scope in this project's video-card work (`.claude/ledger/threads/video-card-playback-controls.md`, "Out of Scope" section): fullscreen playback, playback speed control, captions, quality/resolution controls, controller extraction from `video_body.dart`, and touch double-tap seek. In addition, specific to this spec:

- Any backfill of thumbnails for pre-existing video entries (see Rejected Alternatives).
- Any file-based frame-extraction utility, capture-time or retroactive (see Rejected Alternatives).
- Phase 3 execution itself, until the Phase-1 profile measurement authorizes it.
- Any change to `EntriesDao` pagination unless and until Phase 3 is authorized and the pagination-vs-slivers decision is made at that time.
- Any change to the vendored `third_party/camera_macos` package's Swift or Dart source. This spec consumes its existing public API (`CameraMacOSView.pictureFormat`, `CameraMacOSController.takePicture()`) as-is; the `"jepg"` typo and the ignored per-call `takePicture` format argument documented above are noted for awareness only and are not to be "fixed" upstream as part of this work.
