# Session 2026-07-21-06 — journal-app-design

## Where it started
Resumed at 31/31, app builds+runs on macOS. User reported the "Capture a moment" flows
broken on the prior local build: Write a note + Record voice hang under a "Saving…" modal
(never persist); Record video fails immediately without any permission prompt. Asked to
recreate, root-cause, recommend, then implement fixes and run a COMPLETE APP test (not
back-end-only). Debug/implement phase.

## What shipped
- **Root cause NOTE+VOICE (shared), verified two rounds.** A platform `Exception` in the
  Riverpod capture chain (`captureServiceProvider`→`mediaStoreProvider`→`mediaRootProvider`,
  i.e. `getApplicationDocumentsDirectory()` throwing `MissingPluginException`) is held
  FOREVER by Riverpod 3.3.2 default auto-retry. Gate: `~/.pub-cache/.../riverpod-3.3.2/lib/src/core/provider_container.dart:948`
  — `Error`/`ProviderException` propagate; ANY other thrown object (an `Exception`) →
  exponential-backoff retry → `.future` never completes. Amplified by save composers having
  NO `finally`/timeout (catch arms DO reset). Trigger (b) `NativeDatabase.createInBackground`
  EXCLUDED — DB opens+writes fine on the real sandboxed build. Real-world trigger was
  STALE/INCOMPLETE macOS pods (Manifest.lock listed only camera_macos); a clean
  `flutter build macos` self-heals plugin wiring. Durable guarantee = the code fix.
- **Fix NOTE+VOICE** — `retry:(_,_)=>null` on ProviderScope (lib/main.dart:6 load-bearing;
  lib/app/app.dart:16 inert per review); bounded `.timeout` + `finally` + surfaced error in
  lib/features/capture/text/text_composer.dart and voice/voice_composer.dart.
- **Root cause + fix VIDEO.** (1) Latent deadlock: `start()` awaited `_ready.future` before
  the preview that completes it was mounted → circular wait. Fixed: mount preview (arming
  phase) BEFORE awaiting `_ready`, + 12s timeout backstop (lib/features/capture/video/video_composer.dart,
  platform/camera_video_recorder.dart). (2) Permission gate redesigned: dedicated denied +
  arming states, "Try again", on-screen guidance instead of silent fail (video_recorder_sheet.dart).
  (3) G6 twin: same timeout/finally on video save.
- **"No prompt" is an ad-hoc-signing/TCC ENVIRONMENT limitation, not a code bug** (high
  confidence). `codesign -dvv` on the built .app = `Signature=adhoc`, `TeamIdentifier=not set`;
  `AVCaptureDevice.requestAccess` only prompts when status `.notDetermined`. No paid Apple
  account → cannot be fixed in Dart. Code now surfaces guidance instead of failing silently.

## Tried and failed
- Pinning trigger by armchair reasoning — inconclusive (home screen renders DB data,
  weakening both candidates). Resolved only by empirical `-d macos` reproduction.
- First mechanism attribution ("Riverpod swallows Exceptions via AsyncValue") — WRONG;
  corrected via harness-free `dart run` to the auto-retry gate (provider_container.dart:948).

## Verification
- Host repro receipt `test/repro/capture_save_hang_repro_test.dart` — RED (hang) → GREEN.
- `-d macos` receipt `integration_test/capture_save_persist_test.dart` — note+voice persist
  real DB rows/media blob on the sandboxed app. GREEN.
- Video receipt `test/features/capture/video/video_deadlock_test.dart` — RED→GREEN.
- `flutter analyze` = No issues found. `flutter test` = +667 all pass (660 base + 7 new).
- Code review (note/voice) = APPROVE-WITH-FIXES, no CRITICAL/HIGH.

## Running state
- none. All subagents completed. No app process left running.

## Deferred + open
- COMPLETE APP TEST NOT YET DONE — the integration receipts drive the SAVE PATH, not the
  actual UI button→"Saving…"modal→timeline. Next session: real-UI `-d macos` integration
  across all 3 flows (tap Save → modal dismisses → entry appears) + live VM screenshots.
- Code-review MEDIUM touch-ups to apply first: voice `finally` fires on SUCCESS path (glitch,
  voice_composer.dart:80-84); `.timeout` doesn't cancel non-idempotent `capture()` → possible
  duplicate/phantom entry; errors swallowed with no log; consolidate the inert app.dart retry.
- Human/on-device only: real camera capture + TCC prompt (`tccutil reset Camera dev.satanshumishra.fieldNotes`,
  grant in System Settings) — ad-hoc build expected TCC-flaky; real mic capture for voice.
- NOTHING COMMITTED. On `main` — MUST branch before committing (branching rule). Working tree
  now carries lib/ + test + integration_test + pubspec + macOS pod artifacts.
- Driving the live app (clicks) still needs a Claude Desktop quit+reopen for Accessibility.

## Pick up here
Apply the 4 code-review MEDIUM touch-ups, then run the COMPLETE APP TEST: real-UI-driven
`-d macos` integration across Write-a-note / Record-voice / Record-video (assert modal
dismisses + entry appears), plus live-app VM screenshots. Then decide the commit strategy
(branch off main). Real camera + TCC is the only genuinely human-gated remainder.
