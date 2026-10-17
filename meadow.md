# meadow: Build the updated Meadow from the prototype
Status: done
Updated: 2026-10-17T05:49:35.162Z
Next ids: c4 D11 R3 S1

## Goal

Bring the prototype's Meadow (renamed from Garden) into the live Flutter app: per-user, per-year randomized meadow generation, the year / day-by-day / year-so-far UI, viewing past years, and hover or select on a flower showing its planted date, while keeping the current aesthetic and making it smooth with up to 366 flowers on macOS and Android. Spec it with the interphase prototype pathway, get approval, then dispatch with mitosis.

## Done when

- [x] c1 An interphase prototype spec for the Meadow, with its items file, is approved by the owner evidence: check_spec.py on docs/specs/meadow.md: 0 errors (1 warning, the control name Fast-forward). check_items.py on docs/specs/meadow.items.json: 0 errors, 22 Steps (warnings: meadow-bench and meadow-old-garden-removal have empty acceptance lists by design). The owner chose Approve for the written spec and 22 Steps on 2026-09-29, recorded in docs/specs/meadow.decisions.md, and then approved two packaging-only fixes (contract_group removed from four page Steps; data edges routed through Scene) before launch. Tree guard verified clean before the guard file was removed.
- [x] c2 The approved Steps are dispatched with mitosis and ship as draft pull requests, none merged evidence: mitosis run 2026-09-29-meadow ended with all 3 MSPs shipped, checked with gh pr view on 2026-09-30: #241 Data (draft, base main, gate 12/12 pass), #242 Scene (draft, base mitosis/meadow-data, gate 34/34 pass), #243 Page (draft, base mitosis/meadow-scene, gate 25 pass + 2 not-applicable, 0 inert/inconclusive). None are merged. The removal Lane 21 failed because garden_view.dart was outside its write-set; the orchestrating session finished it in the Page worktree (removed old GardenPage/GardenView, made the shell_keyboard_test painted-focus guard scroll-aware, now covering a6/a7/a8). Analyze was clean and the full suite passed 3886/3886 on the Page branch before resuming. The resume exited 8 as expected: a foreign write to garden_view.dart (owner Lane 18) and an undeclared write to test/app/shell/shell_keyboard_test.dart, both named in the #243 body. CI on the PRs had not finished when this was recorded.
- [~] c3 A meadow with 366 flowers stays smooth on Android and macOS without changing its look or feel struck: struck in the old ledger

## Where things stand

Converted from the old ledger.

## Next step

PR #247 (branch mitosis/meadow-recolour at 18492bd, draft) waits on CI and the owner's review and merge. If CI fails, fix it on that branch. After the owner merges, clean up: the worktrees ~/.mitosis/field-notes/testkit/work/{recolour-247,pacer,pacing-probe,manual}, the mitosis run trees under ~/.mitosis/runs/field-notes/2026-09-30-recolour*, the local branches mitosis/meadow-recolour-{amend,pacer,fixes}, and old apps under testkit/apps. Then update the Meadow spec's own criterion 10.17 so scene-ready on older devices is reported, not bounded (owner decision, out of scope for this spec).

## Decisions in force

- D1 Meadow: build the prototype's scene, seeded per person and year, 60 fps at 366 flowers, three PRs: Owner chose, 2026-09-29: the prototype's new scene; a random meadow key saved with the settings and mixed with the year; Play the day and Now stay debug-only (the study's time slider ships); 60 fps at 366 flowers on the Note10+ and the Mac in every view, day and night; past years titled by weather; nothing deferred; month buttons for keyboard and screen readers; one shared entry-count query; scene appears within 1 s with no frame over 100 ms; three PRs merged in order (data, scene, page); both light and dark themes. Full list in docs/specs/meadow.decisions.md.
- D2 Fix Impeller's colour-filter-plus-blend fault by moving each blend onto its own layer: Chosen: blend on a saveLayer, filter on the image. The mask's dstIn layer is clipped with clipRect(rect), because on Skia restoring a dstIn layer clears everything outside the layer; without the clip the unclipped version wiped the night overlay from the whole meadow. This leaves Skia's layer images byte-identical, gives mountains a median of 1 and lake/falls within a few levels of Skia on Impeller, and changes page goldens only on the mountain band's edges. Shipped in PR #245 (Step meadow-impeller-compositing).
- D3 Bake the sun rays from two colour-neutral masks held beside the creature sprites: Chosen: MeadowRays in lib/features/garden/render/meadow_rays.dart, with colour-neutral masks recorded once and image-only tinting. It keeps the no-vector-after-build rule and leaves the landscape budget alone. The tinted masks match today's rays within 3 levels on Skia and 5 on Impeller. The owner chose to fold it into PR #245. Built by a follow-up mitosis run (~/.mitosis/field-notes/impeller/rays-run.zsh, --no-push) on mitosis/meadow-impeller.
- D4 Owner shaped the Impeller round as three stacked PRs, with PR 2 owning the Meadow page goldens: The owner chose three stacked PRs: #244 toolchain; #245 Meadow on #244; #246 small fixes on #244. Loading text is in PR 2, PR 2 owns the Meadow page goldens, and the rays commit is to be added to PR 2. Also chosen: Android 10 minimum, spruce reworded, unknown mood tolerated, camera_macos SPM, shared window clearance, and Impeller tests run locally and in the gate only.
- D5 Run the sweep in the VM lab, not Parallels or the real phone: The owner, in their own words: "Parallels VM will no longer be used for sandbox testing. Rely upon the `VMLab` skill to use the new sandbox environment to test both macOS and Android changes fully without needing a real device. Defer testing on a real phone for afterwards ONLY if necessary and recommended."U+000AU+000ASo macOS journeys run in a lab macOS VM (`macos-1`) and Android journeys in the lab `android-phone` emulator. Speed is judged by before/after runs in the same lab instance: the baseline bench is f552f46 built with Flutter 3.47.5 from `testkit/work/meadow-bench`. A phone run is proposed afterwards only if the lab leaves 10.17 undecided.
- D6 Recolour the Meadow one piece per frame, on every sky change: The owner chose to pace every recolour with pieces switching one at a time (one piece per frame, order mountains, lake tiles, waterfalls, clouds, newest palette each), bounded: the lake is always redrawn straight after the mountains, every piece shows the newest colour within one frame per piece plus one (15 frames for the bench meadow), and the Meadow never opens half-coloured. The owner accepted that a lake tile's faint reflection may take up to about 22 frames when a change lands mid-lake. Spec: docs/specs/meadow-opening-recolour-stutter.md.
- D7 The Meadow bench warms up before measuring: The owner chose the warm-up: integration_test/meadow_perf_bench_test.dart registers an unmeasured 'meadow warm-up before measuring' test before the 12 cases, whose names and 48 records stay the same.
- D8 Amend PR #247: shared recolour allowance, time-budgeted build, bench without semantics: The owner chose to fold one amendment into PR #247. It makes one recolour piece per frame app-wide, implemented as a used flag cleared by one end-of-frame callback, with covered Meadows queued and drawing only from it. It paces the build by an 8 ms time budget per frame (meadowBuildBudget, meadowKeepBuilding, at least one advance), replacing the fixed four. It runs the bench with semanticsEnabled: false, and it tightens the mid-opening test. Spec sha256 0caeaedd…; Steps recolour-amendment and bench-semantics.
- D9 Pace the Meadow build by live GPU feedback, not numbers tuned on one phone: GPU back-pressure with a processor budget derived from the display refresh rate, probed first on the Note10+, lab emulator and lab Mac VM, then specced for approval and dispatched with mitosis. Quality step-down for ongoing animation is deferred: only if necessary and only when the owner asks for it.
- D10 Carry the Meadow's 60 fps criterion to the meadow-sweep thread and close this thread: Moved: meadow-sweep criterion 01M42HJ47P2RAS147T6HYHD7G6 carries the same text and the owner's words "366 flowers at 60 fps", with the device-pass benchmark as its check. This thread's copy is struck and the thread closes as done for its build work.

## Open risks

- R1 macOS builds render with Skia (no FLTEnableImpeller), and under Skia the Meadow crashes the app on io.flutter.raster in GrResourceCache purge or ref-count release, reached from Rasterizer::MakeSkiaGpuImage and frame flushes. On 2026-09-30 it crashed 5 times in the Parallels guest (full screen, month hover, about a minute idle on the page, empty Meadow after Delete all) and once on the host M4 Pro bench. The same builds with FLTEnableImpeller do not crash. Crash reports are in ~/.mitosis/field-notes/testkit/results/macos/sbx-2026-09-30/. Bears on c3.
- R2 Phone speed misses spec 16.22 (Note10+, bottom-bar layout, 366 flowers, two runs on 2026-09-30). Noon ran at 49.7 to 51.7 fps with raster p50 of 19.5 to 20.4 ms; midnight met 60 fps. Scene ready took 1.46 to 1.87 s against a 1 s target, and the longest frame was 331 to 522 ms against 100 ms. The Mac under Impeller missed the 100 ms limit only in study (114 to 132 ms). Bears on c3.

## Settled, do not reopen

## Where the details live

- Meadow spec (git-ignored, main checkout only): /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/meadow.md
- Meadow decisions (binding): /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/meadow.decisions.md
- Meadow Steps (22) for mitosis: /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/meadow.items.json
- Mitosis run template: charter, wrappers, PR adapter, run.zsh, run.log: /Users/satanshumishra/.mitosis/field-notes/meadow/
- Mitosis run directory (state, lanes, worktrees): /Users/satanshumishra/.mitosis/runs/field-notes/2026-09-29-meadow
- Prototype design source (untracked, main checkout only): /Users/satanshumishra/Documents/DevLabs/fireplace/docs/prototype/project/Meadow Scene.dc.html
- Old ledger record: thread 01M3QXP7EMFB3XCH1KN7K9PA90 in refs/logbook/archive/ledger
