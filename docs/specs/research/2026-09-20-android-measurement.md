# The Android measurement — U6

Unit: `u6` of `docs/specs/2026-09-20-note-editor-and-scrapbook-photos.md`. Base: `4119297`
(`main` after `u1`–`u5`).

**Status: the Android figures are NOT YET RECORDED.** This machine has no Android SDK, so no
agent can produce them. Everything below is in place and re-runnable: the harness, the runbook,
a measured desktop baseline for all five numbers, and a decision rule fixed *before* the device
data exists. A human with a mid-tier Android phone runs one command and fills one table.

---

## 1. What this unit decides

`u10` (`SegmentNoteEditor`) is conditional. The spec builds it **only** if this measurement shows
the single-buffer editor is unusable on a mid-tier phone. U10 is expensive — hand-built
cross-boundary Backspace-merge, arrow traversal and focus handoff, unverifiable by golden image,
and it costs cross-segment drag-selection in a writing app. Two of three judge lenses called it
the worst-propertied subsystem anyone proposed.

So the burden of proof runs one way: **absent a measurement that condemns the single buffer, U10
is not built.** This document exists to give that measurement somewhere to land while it is still
cheap to act on — before any photo work.

---

## 2. Runbook

### What you need

| Requirement | Why it is not negotiable |
|---|---|
| A **physical** mid-tier Android phone | An emulator runs on the host CPU. It measures the wrong machine, and the whole unit is about the mid-tier Android multiplier. The script refuses an `emulator-*` serial unless you pass `--allow-emulator`. |
| **Profile** mode (the default) | Debug mode carries asserts and JIT and is several times slower. Debug numbers are not a baseline. |
| `adb` reachable | On `PATH`, or under `$ANDROID_HOME`, `$ANDROID_SDK_ROOT`, `~/Library/Android/sdk` or `~/Android/Sdk`. Ships with Android Studio. |
| USB debugging authorised | Accept the RSA prompt on the phone once. |
| The screen awake and the app foregrounded | See "the one trap", below. |

"Mid-tier" means the class the spec targets: a Snapdragon 6-series / Dimensity 700-900 / Exynos
1x80-class phone, 60 Hz or 90 Hz, from the last three or four years. Record what you actually
used; the script reads `ro.product.model` and `ro.build.version.release` off the device so you
cannot mislabel the run by accident.

### The command

```
scripts/android-bench.sh
```

That is the whole thing. It asserts a single connected physical device, reads the model, Android
release and SDK level off it, and runs:

```
flutter drive --driver=test_driver/perf_driver.dart \
              --target=integration_test/note_perf_bench_test.dart \
              --profile -d <serial> --dart-define=...
```

It writes `build/note_perf_bench.json` and prints the path. Options: `-d SERIAL` when more than
one device is attached, `--debug` to measure the same-mode pair against the desktop baseline
below, `--allow-emulator` if you accept a labelled non-answer.

### The one trap

`integration_test/fixtures/long_note_fixtures.dart` builds its eight photo blobs with
`PictureRecorder` → `Picture.toImage` → PNG. `Picture.toImage` completes on the raster thread,
and the raster thread only runs while the platform is delivering frames. **If the app window is
occluded, backgrounded, or the screen locks, that call never returns and the run hangs with the
process idle at 0% CPU.** This is observed, not theoretical — it is exactly how the macOS device
run of this harness stalled for ten minutes.

So: leave the phone unlocked and untouched for the run. `adb shell svc power stayon usb` before
you start is the cheap insurance.

### If `adb` is missing

The script exits 3 and says so. There is no substitute — a desktop run measures Apple Silicon,
which the design already has too much of. Borrow a phone, or leave the Android table empty and
say so rather than filling it with a projection.

### Reproducing the desktop baseline

```
flutter test -d flutter-tester integration_test/note_perf_bench_test.dart \
             --dart-define=BENCH_OUTPUT_DIR="$PWD"
```

Ten seconds. **Do not** run it as plain `flutter test integration_test/note_perf_bench_test.dart`:
without `-d flutter-tester` that targets the macOS device, spends about ten minutes building the
app bundle, and then hits the trap above. `BENCH_OUTPUT_DIR` is needed because a test process
launched as a device app does not have the repository as its working directory.

---

## 3. What the five numbers are, and what instruments them

Every figure is the wall-clock cost of **one frame driven directly** through
`WidgetTester.pumpBenchmark` under `LiveTestWidgetsFlutterBindingFramePolicy.benchmark`. That
drives `handleBeginFrame` + `handleDrawFrame` without waiting for vsync, so the number is
Dart-side build, layout and paint on the UI thread — not padded by up to a frame of idle. It
excludes rasterisation, which is measured separately in number 5 on device.

| # | id | Surface under test |
|---|---|---|
| 1 | `keystrokeLiveStyled20k` | One character inserted mid-document into a 20 000-char buffer in the real `SingleFieldNoteEditor`, with live Markdown styling **forced on** by building the shipping `MarkdownStyleController` with its `styleLimit` raised to `1 << 30`. At the default `liveStyleLimit` the controller would refuse to style this long a buffer; raising the limit is the only way to learn whether `liveStyleLimit` could ever be raised. |
| 2 | `keystrokePlain60k` | The same insertion into a 60 000-char buffer through the **unmodified** `MarkdownStyleController`, which short-circuits to one plain span past `liveStyleLimit`. This is the shipping path for a long note. |
| 3 | `firstLayoutWrappedParagraph` | A freshly mounted `NoteBody` pinned to the canonical 560 pt measure on any screen, holding one right/medium photo line and the paragraph after it, with the photo resolved through a `MediaStoreResolver` whose memo is warmed before timing. `PhotoWrapBlock` floats the photo and splits the paragraph around it; the run asserts the float after the first sample, so the number is known to contain the split. Image decode is excluded because it completes after the timed frame. Every sample uses a distinct source so `parseNote`'s 16-entry memo misses and the parse is inside the number. |
| 4 | `firstLayoutTenThousandWordDocument` | A freshly mounted `NoteBody` over a 10 000-word (73 063-char) source carrying eight `![alt](photo/<prefix> "...")` lines, inside a `SingleChildScrollView` so the whole `Column` lays out. The eight photos render through a `MediaStoreResolver` warmed before timing: the six followed by a paragraph go through `PhotoWrapBlock`, the other two are `StackedPhoto`. A float needs a measure of at least 462 pt at the 16 px body size, so at this 393 pt phone surface every `PhotoWrapBlock` plans its float and falls back to stacked, as it does on a phone; number 3 is where a split is measured. Image decode is excluded because it completes after the frame. Memo missed per sample, as above. |
| 5 | `feedScrollFrame` | One dragged 60 pt scroll step over the real `TodayScreen` sliver feed, seeded with 40 note entries long enough to truncate at `notePreviewCharLimit`. |

Plus one companion, recorded under measurement 4 because it is the half that 4 cannot see:

| — | `decodeEightPhotos` | Cold decode of eight real 2048×1536 PNGs at the 64 px-quantised `cacheWidth` a note image will request. Number 4 lays the photos out but its timed frame ends before their decode completes, so this figure is the decode cost number 4 excludes. |

Both keystroke measurements grow the buffer by one character per sample — 30 characters on 20 000
and 60 000 — and are taken with the field unfocused, so the caret-blink repaint is excluded.

---

## 4. Desktop baseline — measured

Recorded 2026-09-21 (`2026-09-22T03:06:18Z`) at `fc851dd`. Numbers 3 and 4 changed meaning since the
previous baseline (2026-09-20 at `4119297`), which measured a plain paragraph wrapping at the column
edge and a document whose photos were `NotePhotoStub` placeholders, so neither figure compares with
its predecessor. Other test processes shared the host during this run (1-minute load average 6 to 9
on 14 cores), and an immediate re-run under heavier load came out 17–36 % higher at p50 across all
six rows; read these as a loaded-host baseline, not a quiet one.

- Host: macOS 26.5.1, Apple Silicon, `flutter_tester`
- Flutter 3.44.8 stable, Dart 3.12.2
- **Build mode: debug** — `flutter test` has no profile mode
- Surface: 393 × 851 logical at DPR 2.75, note measure 357 pt (number 3 pins its own 560 pt), `noteBody` 16 px, `liveStyleLimit` 6000

| # | Measurement | p50 | p90 | p99 | max | n |
|---|---|---|---|---|---|---|
| 1 | keystroke, 20 000 chars, live-styled | 8.23 ms | 10.04 ms | 13.10 ms | 13.10 ms | 30 |
| 2 | keystroke, 60 000 chars, styling off | 12.78 ms | 13.86 ms | 17.04 ms | 17.04 ms | 30 |
| 3 | first layout, one wrapped paragraph | 3.33 ms | 4.60 ms | 9.69 ms | 9.69 ms | 30 |
| 4 | first layout, 10 000-word doc, 8 photos | 139.40 ms | 148.00 ms | 167.48 ms | 167.48 ms | 12 |
| — | decode 8 photos @ cacheWidth 1024 | 27.17 ms | 42.74 ms | 42.74 ms | 42.74 ms | 8 |
| 5 | feed scroll frame, 40 entries | 1.02 ms | 2.07 ms | 10.32 ms | 10.32 ms | 34 |

### Three things this baseline already settles

**Live styling is not the cost, and `liveStyleLimit = 6000` buys no typing headroom.** A 20 000-char
buffer with full Markdown styling costs 8.23 ms per keystroke. A 60 000-char buffer with styling
*switched off* costs 12.78 ms — three times the characters, 1.6× the cost, and the cheaper
configuration is the styled one. Cost tracks document length through `RenderEditable`'s
whole-paragraph relayout, exactly as the terrain survey's source-confirmed mechanism says, and
span construction is noise beside it. The 6000-character threshold changes what is painted, and
mid-sentence at that, without moving the number it was introduced to protect.

**The heaviest path measured here is not the editor.** Number 4 is 139 ms — roughly eleven times a
keystroke in a document of the same size, and some forty times one paragraph wrapped around a photo.
That is the read view, `NoteDocument` building some 450 block widgets and eight stacked photo figures,
and registering them all with `SelectionArea`. `u10` does nothing for it: the segment
editor changes how text is *typed*, not how a saved note is *opened*. If the Android figure for
number 4 is bad, the fix is a windowed or lazy read view, which is not in the plan and is not U10.

**The lazy feed from `u2` is doing its job.** A scroll frame is 1.02 ms at p50 with spikes to 10.3 ms
when a card enters the viewport — the shape you expect from `SliverList.builder` with a cache
extent, not from a feed that builds everything.

### What the baseline is not

Debug on Apple Silicon against profile on Android confounds two variables: build mode and
hardware. Expect the naive Android ÷ desktop ratio to **understate** the hardware multiplier,
because profile-mode AOT claws back a chunk of the debug penalty on the device side. If you want
the hardware multiplier alone, run `scripts/android-bench.sh --debug` and compare against this
table mode-for-mode — then run it again without `--debug` for the number that decides the verdict.

Also absent on `flutter_tester`: the real `Newsreader` and `Instrument Sans` fonts are not loaded,
so glyph shaping is measured against a test font. Rasterisation is excluded everywhere on desktop.
Both differences push the desktop figures **down**, which is the safe direction for a baseline
that exists to be beaten.

---

## 5. Android results — TO BE FILLED BY THE DEVICE RUN

Paste the environment block from `build/note_perf_bench.json` here and fill the table from its
`measurements` array. Do not round; the file already reports to a microsecond.

| Field | Value |
|---|---|
| Device model (`ro.product.model`) | |
| Android release (`ro.build.version.release`) | |
| SDK level (`ro.build.version.sdk`) | |
| SoC / `ro.hardware` | |
| Display refresh rate | |
| Flutter version | |
| Build mode | |
| Repository commit | |
| Run date | |

| # | Measurement | p50 | p90 | p99 | max | n | × desktop p90 |
|---|---|---|---|---|---|---|---|
| 1 | keystroke, 20 000 chars, live-styled | | | | | | |
| 2 | keystroke, 60 000 chars, styling off | | | | | | |
| 3 | first layout, one wrapped paragraph | | | | | | |
| 4 | first layout, 10 000-word doc, 8 photos | | | | | | |
| — | decode 8 photos @ cacheWidth | | | | | | |
| 5 | feed scroll frame, 40 entries | | | | | | |

The device run also emits a `feedScrollFrames` key carrying `FrameTimingSummarizer`'s summary over
a real fling — `build`, `raster` and `vsync overhead` percentiles plus GC counts. That is the only
figure in this document that includes rasterisation. Record `frame_build_time_90th_percentile` and
`frame_rasterizer_time_90th_percentile` from it alongside the table.

---

## 6. The decision rule, fixed before the data

Written now, against no Android numbers, so it cannot be bent to whatever comes back. The budget
is one 60 Hz frame, **16.7 ms**. Thresholds are read off **p90 in profile mode on the device**.

| Android p90 for (1) | Android p90 for (2) | Verdict |
|---|---|---|
| ≤ 16.7 ms | ≤ 16.7 ms | PROCEED-WITHOUT-U10, and raise `liveStyleLimit` past 20 000 — styling is provably not the cost |
| ≤ 16.7 ms | 16.7 – 50 ms | PROCEED-WITHOUT-U10. 60 000 characters is roughly 10 000 words in one entry; a journal note that long is an outlier, and the shipping path degrades rather than breaks |
| 16.7 – 50 ms | any | PROCEED-WITHOUT-U10, but lower `liveStyleLimit` to the measured 16.7 ms crossing point and record it |
| > 50 ms | any | **BUILD-U10** |
| any | > 50 ms | **BUILD-U10** |

50 ms is a labelled judgement, not arithmetic: three frames late is where a keystroke stops feeling
immediate and starts feeling like a lagging text field. No study covers it. It is written down so
the call is made once, here, rather than argued after the numbers arrive.

Two conditions that do **not** gate U10 and must not be used to argue for it:

- **Number 4 over 500 ms** means opening a long note in `DayDetailPanel` is visibly slow. The
  remedy is a windowed read view, a new unit that is not in the plan. U10 does not touch it.
- **Number 5 p99 over 16.7 ms** means the feed drops a frame when a card scrolls in. The remedy is
  in `u2`/`u7` territory — the media resolver memo and quantised `cacheWidth` the design panel
  already specified. U10 does not touch it either.

---

## 7. Verdict

**PROCEED-WITHOUT-U10 — provisional, and overturnable by the Android run alone.**

U10 is conditional by construction: the spec builds it only on a showing that the single buffer is
unusable on a mid-tier phone. No measurement in this document makes that showing, and the one
result that bears directly on it cuts the other way — live styling, the specific thing U10 was
designed to escape, is measurably cheaper than the plain path at three times the length. The
`NoteEditor` seam from `u5` keeps this verdict cheap to reverse: `noteEditorFor` in
`lib/features/capture/text/editor/note_editor.dart` is the single place the composer's editor
implementation is chosen, so building `u10` and switching to it is a change there plus a build.

Held provisionally because the desktop projection is honestly undetermined. Carrying the terrain
survey's own 5–15× mid-tier Android band and allowing 2–4× back for profile-mode AOT puts the
Android p90 for number 2 somewhere between 17 ms and 99 ms — straddling every threshold in section
6. That band is too wide to decide anything, which is the point: this is exactly the risk the
spec called the biggest unmeasured one in the design, and only the device retires it.

**When the device run lands**, fill section 5, apply section 6 mechanically, and replace this
section with the resulting verdict and one paragraph of reasoning. If it says BUILD-U10, that is
the answer and `u10` gets built — the seam is there precisely so that the answer is cheap.

---

## 8. Raw `build/note_perf_bench.json`

The desktop baseline run, verbatim except that each `samplesUs` array is reflowed onto one line.
No value is changed. The device run overwrites this file; keep both.

```json
{
  "noteBench": {
    "schema": "note-perf-bench/1",
    "environment": {
      "runLabel": "desktop-flutter-tester-debug",
      "onDevice": false,
      "deviceModel": "Apple Silicon host, flutter_tester",
      "osRelease": "unknown",
      "osSdk": "unknown",
      "operatingSystem": "macos",
      "operatingSystemVersion": "Version 26.5.1 (Build 25F80)",
      "flutterVersion": "3.44.8 (stable channel)",
      "dartVersion": "3.12.2 (stable) (Tue Jun 9 01:11:39 2026 -0700) on \"macos_arm64\"",
      "buildMode": "debug",
      "gitSha": "fc851dd",
      "recordedAt": "2026-09-22T03:06:18.870922Z"
    },
    "surface": {
      "logicalWidth": 393.0,
      "logicalHeight": 851.0,
      "devicePixelRatio": 2.75,
      "noteMeasurePt": 357.0,
      "noteBodyFontSize": 16.0,
      "liveStyleLimit": 6000
    },
    "measurements": [
      {
        "id": "keystrokeLiveStyled20k",
        "what": "frame cost after one inserted character in a 20 000-character buffer with live Markdown styling forced on",
        "unit": "ms",
        "samples": 30,
        "p50": 8.226,
        "p90": 10.042,
        "p99": 13.099,
        "max": 13.099,
        "mean": 8.647,
        "context": {
          "startingChars": 20000,
          "liveStyling": "on, the shipping MarkdownStyleController with its styleLimit raised above the buffer",
          "styleLimit": 1073741824,
          "liveStyleLimit": 6000,
          "caret": "mid-document, unfocused"
        },
        "samplesUs": [10042, 9248, 9480, 9019, 8527, 8047, 8228, 9344, 11688, 8573, 7943, 8226, 7925, 9517, 9142, 7927, 8282, 7943, 7580, 10997, 13099, 7883, 7919, 7947, 7918, 8269, 7343, 7127, 7060, 7186]
      },
      {
        "id": "keystrokePlain60k",
        "what": "frame cost after one inserted character in a 60 000-character buffer past liveStyleLimit, so the shipping controller returns one plain span",
        "unit": "ms",
        "samples": 30,
        "p50": 12.783,
        "p90": 13.855,
        "p99": 17.043,
        "max": 17.043,
        "mean": 13.082,
        "context": {
          "startingChars": 60000,
          "liveStyling": "off, by the shipping liveStyleLimit short circuit",
          "liveStyleLimit": 6000,
          "caret": "mid-document, unfocused"
        },
        "samplesUs": [12815, 13284, 13046, 13112, 12783, 12700, 12931, 12573, 12881, 12693, 12722, 12547, 12810, 13855, 16954, 13543, 13264, 12994, 12385, 12634, 11991, 12132, 13274, 12345, 12571, 12462, 12184, 12049, 13890, 17043]
      },
      {
        "id": "firstLayoutWrappedParagraph",
        "what": "build, layout and paint of a freshly mounted NoteBody at the 560 pt canonical measure holding one photo line and one paragraph, which PhotoWrapBlock splits around the floated photo",
        "unit": "ms",
        "samples": 30,
        "p50": 3.332,
        "p90": 4.6,
        "p99": 9.688,
        "max": 9.688,
        "mean": 3.719,
        "context": {
          "chars": 534,
          "paragraphChars": 495,
          "measurePt": 560.0,
          "placement": "right medium",
          "photoPixels": "2048x1536",
          "photoBlockRenderer": "PhotoWrapBlock through a warm MediaStoreResolver, the float asserted after the first sample; image decode excluded because it completes after the frame",
          "parserMemo": "missed, every sample uses a distinct source"
        },
        "samplesUs": [4600, 9688, 5384, 8067, 3441, 3766, 3186, 3356, 3457, 3472, 3709, 3939, 4160, 2956, 3305, 3332, 3432, 2766, 3326, 2684, 3182, 2736, 3809, 2852, 3075, 2524, 2726, 2738, 2420, 3484]
      },
      {
        "id": "firstLayoutTenThousandWordDocument",
        "what": "build, layout and paint of a freshly mounted NoteBody holding a 10 000-word note carrying eight photo lines, rendered as photos through a warm media resolver",
        "unit": "ms",
        "samples": 12,
        "p50": 139.401,
        "p90": 147.999,
        "p99": 167.483,
        "max": 167.483,
        "mean": 141.487,
        "context": {
          "chars": 73063,
          "photoLines": 8,
          "photoBlockRenderer": "StackedPhoto or PhotoWrapBlock through a warm MediaStoreResolver; image decode excluded because it completes after the frame",
          "parserMemo": "missed, every sample uses a distinct source"
        },
        "samplesUs": [167483, 144611, 144990, 147999, 133349, 133527, 132576, 139572, 136556, 143042, 139401, 134749]
      },
      {
        "id": "decodeEightPhotos",
        "what": "cold decode of the same eight photos at the quantised cacheWidth a note image will request, the cost number 4 excludes because decode completes after the frame",
        "unit": "ms",
        "samples": 8,
        "p50": 27.172,
        "p90": 42.739,
        "p99": 42.739,
        "max": 42.739,
        "mean": 29.971,
        "context": {
          "photos": 8,
          "sourcePixels": "2048x1536",
          "cacheWidth": 1024,
          "bytesEach": 1189185
        },
        "samplesUs": [26809, 26999, 27792, 42739, 30294, 26637, 27172, 31329]
      },
      {
        "id": "feedScrollFrame",
        "what": "build, layout and paint of one dragged scroll frame over the seeded today feed of truncated preview cards",
        "unit": "ms",
        "samples": 34,
        "p50": 1.015,
        "p90": 2.073,
        "p99": 10.321,
        "max": 10.321,
        "mean": 1.64,
        "context": {
          "entries": 40,
          "stepPt": 60.0,
          "previewCharLimit": 1200
        },
        "samplesUs": [1223, 1015, 741, 1071, 1093, 910, 733, 763, 716, 899, 10321, 1729, 1083, 1048, 1109, 790, 1028, 1015, 917, 908, 1696, 2466, 1538, 1009, 943, 842, 838, 9688, 2073, 1344, 1026, 947, 1007, 1248]
      }
    ]
  }
}
```

---

## 9. What the harness does not measure, stated plainly

- **Rasterisation, everywhere except the on-device `feedScrollFrames` summary.** `pumpBenchmark`
  returns once the layer tree is composited, not once the GPU has drawn it. For text layout, which
  is what the design's risk is about, the UI thread is the right thread. For anything shader-bound
  it is not.
- **The caret and the selection overlay.** The keystroke measurements run unfocused so cursor blink
  does not land inside a timed frame. A focused field pays an extra caret-layer repaint per blink
  interval, which this understates.
- **IME composing.** Both keystroke numbers insert a committed character. A CJK or predictive-text
  composing run rebuilds the span with a live composing range on every intermediate keystroke, and
  that is not measured here.
- **Photo decode inside the read view's frame.** Number 4 lays out its eight photos, stacked at the
  393 pt phone measure, but its timed frame ends before their decode completes.
  `decodeEightPhotos` is that missing half, reported separately; the two must not be silently summed
  as though one frame paid both.
- **Thermal state and CPU governor.** One run on a warm phone is not the same as one on a cold
  phone, and the terrain survey already documented a 5× process-state swing on a desktop. Run the
  script twice with a gap and record both if the numbers land near a threshold.
- **Cross-run comparability of number 5.** The feed scroll step is a fixed 60 pt drag, so which
  card crosses the viewport boundary on which sample depends on card heights, which depend on the
  seeded text. The seed is deterministic, so this is stable run to run at a given commit, and not
  stable across a change to the fixtures.
