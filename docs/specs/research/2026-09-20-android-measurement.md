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
             --dart-define=BENCH_OUTPUT_DIR="$PWD" \
             --dart-define=BENCH_GIT_SHA="$(git rev-parse --short HEAD)"
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
| 3 | `firstLayoutWrappedParagraph` | A freshly mounted `NoteBody` pinned to the canonical 560 pt measure on any screen, holding one right/medium photo line and the paragraph after it, with the photo resolved through a `MediaStoreResolver` whose memo is warmed before timing. `PhotoWrapBlock` floats the photo and splits the paragraph around it; the run asserts the float on every sample, so the number is known to contain the split. The photo is decoded into `ImageCache` once, untimed, before sampling starts, and the run asserts on every sample that it painted from that cache, so every timed frame paints the same cached image and decode is not in the number. Every sample uses a distinct source so `parseNote`'s 16-entry memo misses and the parse is inside the number. |
| 4 | `firstLayoutTenThousandWordDocument` | A freshly mounted `NoteBody` over a 10 000-word (73 061-char) source carrying eight `![alt](photo/<prefix> "...")` lines, inside a `SingleChildScrollView` so the whole `Column` lays out. The eight photos render through a `MediaStoreResolver` warmed before timing: the six followed by a paragraph go through `PhotoWrapBlock`, the other two are `StackedPhoto`. A float needs a measure of at least 462 pt at the 16 px body size, so at this 393 pt phone surface every `PhotoWrapBlock` plans its float and falls back to stacked, as it does on a phone; number 3 is where a split is measured. All eight photos are decoded into `ImageCache` once, untimed, before sampling starts, and the run asserts on every sample that all eight painted from that cache, so decode is not in the number. Memo missed per sample, as above. |
| 5 | `feedScrollFrame` | One dragged 60 pt scroll step over the real `TodayScreen` sliver feed, seeded with 40 note entries long enough to truncate at `notePreviewCharLimit`. |

Plus one companion, recorded under measurement 4 because it is the half that 4 cannot see:

| — | `decodeEightPhotos` | Cold decode of eight real 2048×1536 PNGs at the 64 px-quantised `cacheWidth` a note image will request. Number 4 paints from a warm cache, so this approximates the decode cost it leaves out: it decodes all eight at one `cacheWidth` taken from the editor's 357 pt measure, while number 4 requests a width per photo from that photo's size at its own 393 pt measure. |

Both keystroke measurements grow the buffer by one character per sample — 30 characters on 20 000
and 60 000 — and are taken with the field unfocused, so the caret-blink repaint is excluded.

---

## 4. Desktop baseline — measured

Recorded 2026-09-21 (`2026-09-22T05:12:15Z`) at `0fd7075` on branch `mitosis/bench-photos`.
Numbers 3 and 4 changed meaning since the previous baseline (2026-09-20 at `4119297`), which
measured a plain paragraph wrapping at the column edge and a document whose photos were
`NotePhotoStub` placeholders, so neither figure compares with its predecessor. Both now paint their
photos from an `ImageCache` warmed before timing, and the run asserts that on every sample. The host
ran no other test process during this run, but its own applications held the 1-minute load average
between 6.2 and 6.3 on 14 cores. Across three runs that day, at loads from 2.6 to 6.3, the p50s
ranged 7.02 to 8.35 ms for number 1, 11.87 to 13.35 ms for number 2, 2.78 to 4.57 ms for number 3,
122.41 to 129.42 ms for number 4, 26.97 to 27.48 ms for decode and 0.68 to 1.15 ms for number 5;
the first two runs placed two of number 4's photos with a token the photo grammar no longer
accepts. Read numbers 3 and 5 as load-sensitive at this size.

- Host: macOS 26.5.1, Apple Silicon, `flutter_tester`
- Flutter 3.44.8 stable, Dart 3.12.2
- **Build mode: debug** — `flutter test` has no profile mode
- Surface: 393 × 851 logical at DPR 2.75, note measure 357 pt for numbers 1 and 2 and `decodeEightPhotos`, 393 pt for number 4, 560 pt pinned for number 3, `noteBody` 16 px, `liveStyleLimit` 6000

| # | Measurement | p50 | p90 | p99 | max | n |
|---|---|---|---|---|---|---|
| 1 | keystroke, 20 000 chars, live-styled | 7.02 ms | 8.74 ms | 11.49 ms | 11.49 ms | 30 |
| 2 | keystroke, 60 000 chars, styling off | 11.87 ms | 12.55 ms | 15.79 ms | 15.79 ms | 30 |
| 3 | first layout, one wrapped paragraph | 2.78 ms | 3.63 ms | 7.53 ms | 7.53 ms | 30 |
| 4 | first layout, 10 000-word doc, 8 photos | 129.42 ms | 160.14 ms | 161.17 ms | 161.17 ms | 12 |
| — | decode 8 photos @ cacheWidth 1024 | 26.97 ms | 36.58 ms | 36.58 ms | 36.58 ms | 8 |
| 5 | feed scroll frame, 40 entries | 1.00 ms | 5.49 ms | 7.82 ms | 7.82 ms | 34 |

### Three things this baseline already settles

**Live styling is not the cost, and `liveStyleLimit = 6000` buys no typing headroom.** A 20 000-char
buffer with full Markdown styling costs 7.02 ms per keystroke. A 60 000-char buffer with styling
*switched off* costs 11.87 ms — three times the characters, 1.7× the cost, and the cheaper
configuration is the styled one. Cost tracks document length through `RenderEditable`'s
whole-paragraph relayout, exactly as the terrain survey's source-confirmed mechanism says, and
span construction is noise beside it. The 6000-character threshold changes what is painted, and
mid-sentence at that, without moving the number it was introduced to protect.

**The heaviest path measured here is not the editor.** Number 4 is 129 ms — roughly eleven times a
keystroke in a document of the same size, and some forty-seven times one paragraph wrapped around a photo.
That is the read view, `NoteDocument` building 581 block widgets for the document's 587 blocks, eight stacked photo figures among them,
and registering them all with `SelectionArea`. `u10` does nothing for it: the segment
editor changes how text is *typed*, not how a saved note is *opened*. If the Android figure for
number 4 is bad, the fix is a windowed or lazy read view, which is not in the plan and is not U10.

**The lazy feed from `u2` is doing its job.** A scroll frame is 1.00 ms at p50 with spikes to 7.8 ms
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
Android p90 for number 2 somewhere between 16 ms and 94 ms — straddling both thresholds in section 6,
16.7 ms and 50 ms. That band is too wide to decide anything, which is the point: this is exactly the risk the
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
      "runLabel": "desktop-flutter-test",
      "onDevice": false,
      "deviceModel": "unknown",
      "osRelease": "unknown",
      "osSdk": "unknown",
      "operatingSystem": "macos",
      "operatingSystemVersion": "Version 26.5.1 (Build 25F80)",
      "flutterVersion": "3.44.8",
      "dartVersion": "3.12.2 (stable) (Tue Jun 9 01:11:39 2026 -0700) on \"macos_arm64\"",
      "buildMode": "debug",
      "gitSha": "0fd7075",
      "recordedAt": "2026-09-22T05:12:15.711610Z"
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
        "p50": 7.019,
        "p90": 8.744,
        "p99": 11.493,
        "max": 11.493,
        "mean": 7.538,
        "context": {
          "startingChars": 20000,
          "liveStyling": "on, the shipping MarkdownStyleController with its styleLimit raised above the buffer",
          "styleLimit": 1073741824,
          "liveStyleLimit": 6000,
          "caret": "mid-document, unfocused"
        },
        "samplesUs": [8378, 8447, 7433, 7673, 8316, 7406, 8067, 8744, 10950, 8184, 6979, 7376, 7061, 6712, 7973, 6604, 6940, 6837, 6541, 8796, 11493, 7001, 6970, 6656, 6493, 7019, 6333, 6149, 6321, 6307]
      },
      {
        "id": "keystrokePlain60k",
        "what": "frame cost after one inserted character in a 60 000-character buffer past liveStyleLimit, so the shipping controller returns one plain span",
        "unit": "ms",
        "samples": 30,
        "p50": 11.869,
        "p90": 12.548,
        "p99": 15.789,
        "max": 15.789,
        "mean": 12.146,
        "context": {
          "startingChars": 60000,
          "liveStyling": "off, by the shipping liveStyleLimit short circuit",
          "liveStyleLimit": 6000,
          "caret": "mid-document, unfocused"
        },
        "samplesUs": [12482, 12548, 12135, 12516, 11909, 11716, 12324, 12012, 11865, 11673, 11840, 11921, 11981, 11661, 11714, 11599, 11518, 11869, 11883, 13430, 12149, 15789, 11750, 11635, 11430, 11483, 11501, 11659, 12411, 13985]
      },
      {
        "id": "firstLayoutWrappedParagraph",
        "what": "build, layout and paint of a freshly mounted NoteBody at the 560 pt canonical measure holding one photo line and one paragraph, which PhotoWrapBlock splits around the floated photo",
        "unit": "ms",
        "samples": 30,
        "p50": 2.777,
        "p90": 3.633,
        "p99": 7.531,
        "max": 7.531,
        "mean": 3.058,
        "context": {
          "chars": 534,
          "paragraphChars": 495,
          "measurePt": 560.0,
          "placement": "right medium",
          "photoPixels": "2048x1536",
          "photoBlockRenderer": "PhotoWrapBlock through a warm MediaStoreResolver, the float asserted on every sample; the decoded photo comes from an ImageCache warmed before timing, so decode is not in the number",
          "parserMemo": "missed, every sample uses a distinct source"
        },
        "samplesUs": [7531, 3633, 3195, 2965, 2984, 3260, 2903, 2861, 3552, 3681, 4423, 2715, 2773, 2777, 2564, 2874, 2781, 2471, 2551, 2626, 2504, 2638, 2585, 2488, 2556, 2590, 2429, 2423, 3412, 3022]
      },
      {
        "id": "firstLayoutTenThousandWordDocument",
        "what": "build, layout and paint of a freshly mounted NoteBody holding a 10 000-word note carrying eight photo lines, rendered as photos through a warm media resolver",
        "unit": "ms",
        "samples": 12,
        "p50": 129.421,
        "p90": 160.142,
        "p99": 161.171,
        "max": 161.171,
        "mean": 135.269,
        "context": {
          "chars": 73061,
          "photoLines": 8,
          "photoBlockRenderer": "StackedPhoto or PhotoWrapBlock through a warm MediaStoreResolver; every decoded photo comes from an ImageCache warmed before timing, so decode is not in the number",
          "parserMemo": "missed, every sample uses a distinct source"
        },
        "samplesUs": [161171, 149454, 129421, 160142, 123789, 121678, 120303, 130595, 115775, 115985, 158335, 136587]
      },
      {
        "id": "decodeEightPhotos",
        "what": "cold decode of the same eight photos at one quantised cacheWidth taken from the editor measure, an approximation of the per-photo widths number 4 requests; number 4 paints from a warm ImageCache",
        "unit": "ms",
        "samples": 8,
        "p50": 26.97,
        "p90": 36.578,
        "p99": 36.578,
        "max": 36.578,
        "mean": 28.496,
        "context": {
          "photos": 8,
          "sourcePixels": "2048x1536",
          "cacheWidth": 1024,
          "bytesEach": 1189185
        },
        "samplesUs": [26879, 26970, 28004, 36578, 29285, 26745, 26254, 27255]
      },
      {
        "id": "feedScrollFrame",
        "what": "build, layout and paint of one dragged scroll frame over the seeded today feed of truncated preview cards",
        "unit": "ms",
        "samples": 34,
        "p50": 0.999,
        "p90": 5.489,
        "p99": 7.82,
        "max": 7.82,
        "mean": 1.723,
        "context": {
          "entries": 40,
          "stepPt": 60.0,
          "previewCharLimit": 1200
        },
        "samplesUs": [1325, 897, 852, 1535, 1016, 1303, 1144, 832, 5489, 1435, 7562, 1199, 999, 885, 793, 810, 697, 964, 1236, 826, 1382, 1075, 906, 792, 6488, 1818, 817, 7820, 1933, 1007, 707, 685, 711, 661]
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
- **A cold photo decode inside the read view's first frame.** Numbers 3 and 4 paint from a warm
  `ImageCache`. Opening a note whose photos are not cached yet also pays their decode, which
  `decodeEightPhotos` approximates; the two must not be silently summed as though one frame paid
  both.
- **Thermal state and CPU governor.** One run on a warm phone is not the same as one on a cold
  phone, and the terrain survey already documented a 5× process-state swing on a desktop. Run the
  script twice with a gap and record both if the numbers land near a threshold.
- **Cross-run comparability of number 5.** The feed scroll step is a fixed 60 pt drag, so which
  card crosses the viewport boundary on which sample depends on card heights, which depend on the
  seeded text. The seed is deterministic, so this is stable run to run at a given commit, and not
  stable across a change to the fixtures.
