# Field Notes — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server. Open-source on GitHub (repo SatanshuMishra/field-notes, private for now).

## Constraints
- No paid Apple/Google developer account; manual sideload/install. macOS + Android only (no iOS).
- Works fully standalone with no server; sync is an optional v2 layer.
- Fast, secure (E2EE), robust; offline-capable; reachable via Tailscale.
- Binary assets must be human-provided + committed (harness blocks agent/main-thread downloads).

## Active Decisions
- decisions/2026-07-24-macos-videorotationangle-crash.md — REAL macOS video crash = AVCaptureConnection.videoRotationAngle setter throwing on macOS 26 _Tundra (not a save-path bug); fix = delete the three rotation-angle sets. VERIFIED on the real camera; shipped in PR #33 (a714961)
- decisions/2026-07-22-capture-finalize-fix-strategy.md — voice=record 7.x upgrade (DONE+verified); video=vendor camera_macos->AVCaptureMovieFileOutput; +disk-verify guardrail
- decisions/2026-07-22-save-hang-timeout-noop-root-cause.md — bounded timeout fails GRACEFULLY but does not persist; real fixes are native (see strategy above)
- decisions/2026-07-22-black-window-standalone-binary.md — BLACK window = launching the standalone .app binary yields no first frame (null layer tree); `flutter run -d macos` renders. Always run via `flutter run`, never the raw binary. VM screenshot works only against a flutter-run instance
- decisions/2026-07-21-capture-flow-root-cause-and-fix.md — capture flows: note/voice save-hang (Riverpod retry-limbo, provider_container.dart:948) + video start()/_ready deadlock FIXED; "no prompt" = ad-hoc-signing/TCC env limit [timeout claim corrected by 2026-07-22-save-hang-timeout-noop-root-cause.md]
- decisions/2026-07-21-vm-rpc-screenshot-for-visual-verification.md — screenshot the running macOS app via the `_flutter.screenshot` VM Service RPC (scratchpad/vm_screenshot.dart); `screencapture` is blocked because Claude Desktop lacks Screen Recording TCC until a full quit+reopen. Screenshotting is unblocked; click-driving still needs Accessibility (same relaunch)
- decisions/2026-07-21-shellnav-built-via-delegated-implementer.md — shell-nav BUILT via a delegated implementer on origin/main (fresh-context rule barred a mitosis relaunch; also sidesteps the checkpoint composition); PR #31 open + independently validated (660 tests, CI green), awaiting the HUMAN's final merge -> 31/31
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — `gh pr merge` + the REST merge endpoint are hook-blocked for ALL callers incl. the main thread; the HUMAN merges each PR on GitHub after the agent validates locally. Supersedes the merge mechanism of 2026-07-12-human-gated-merge-policy. `git push` still works, so the agent can still resolve capture-* branch conflicts.
- decisions/2026-07-20-one-run-completion-frontier-train.md — the engine does FRONTIER-TRAIN build-ahead (code-verified): ONE human-gated run completes all 31 if PRs are merged promptly; fix the 2 parked plans first; batching was an expired debugging control, not an engine limit
- decisions/2026-07-20-batch-3-scoping.md — batch-3 four-screen scope; the capture-* "contention" reasoning was a merge-time vs build-time error the user corrected (superseded in spirit by the one-run decision)
- decisions/2026-07-20-keep-stale-worktrees.md — the ~24 .fireplace-worktrees checkouts are KEPT for manual testing after build/deploy; cleanup is never to be proposed again
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — NEITHER GitHub check runs a Dart test (receipts = node-only, 15s; D6 has no Dart import grapher and passes vacuously). Run `fullValidationCmd` locally against the PR head worktree before every merge; never accept receiptsPass/d6Pass as evidence
- decisions/2026-07-20-reminders-day2-prearm-followup.md — reminders ships arming only the NEXT occurrence; day-2+ reach deferred to a batch-3 follow-up MSP (pre-arm ids 1001..1007, inside the existing fileScope)
- decisions/2026-07-20-reminders-android-desugaring-scope.md — reminders' fileScope expanded by one file (android/app/build.gradle.kts) so it ships the flutter_local_notifications desugaring config in the same PR; receipts CI runs no Android build and cannot catch this
- decisions/2026-07-19-symlink-guard-defect.md — all 7 `~/.claude/lib/superpowers-parallel` CLIs were silent no-ops under the lib symlink (main() guard compared import.meta.url to a literal argv[1]); fixed with the realpath idiom. The engine logs NOTHING on this path, so pre-flight the fold CLI's stdout before EVERY launch
- decisions/2026-07-19-entry-cards-fix-and-batch-2.md — batch 2 = capture-core + entry-cards + reminders; entry-cards fixed-and-included (harness single-ownership); garden-screen deferred to batch 3
- decisions/2026-07-19-pubspec-parallel-conflict.md — pubspec.yaml conflicts are systemic; merge batch PRs one-at-a-time + union-merge each dep-adding PR (regen lock via flutter pub get)
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json MUST be one compact line (pretty-print breaks `foldRunManifest` -> silent full re-decompose + overwrite); engine has NO MSP-filter input, so scope batches by out-of-band trim from the pristine backup; batch 1 = 4 leaf MSPs
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main onto origin/main before EVERY mitosis relaunch; the engine cuts worktrees from the bare LOCAL `main` ref (mitosis.js:946/:1114), so local main must contain every merged dependency
- decisions/2026-07-12-direct-ship-built-msps.md — ship the 3 ALREADY-BUILT foundations via main-thread push+PR+squash-merge (not a mitosis relaunch); engine reserved for building the unbuilt dependents (Option B)
- decisions/2026-07-12-human-gated-merge-policy.md — autonomous is structurally blocked by the harness classifier (delegated agents can't self-merge); switched to mitosis "human-gated" mode + main-thread merge with per-session consent, layer-by-layer (still governs Option B builds)
- decisions/2026-07-11-foundations-shipped-autonomous-policy.md — force-push authorized; 4 foundation PRs merged (origin/main ef3e8c6, 4/31 shipped); autonomous-for-27 part SUPERSEDED by 2026-07-12-human-gated-merge-policy.md
- decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md — receipts.yml npm-ci fix (ec7b959); relaunch rebuilds open-PR MSPs; keep run.json + remove worktrees each relaunch
- decisions/2026-07-10-mitosis-run-contract.md — fresh mitosis run inputs; sourcePrefix "msp" (no trailing slash)
- decisions/2026-07-10-fonts-vendored-human-provided.md — vendored OFL fonts, human-provided (downloads blocked)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; ULID/updated_at/deleted_at/content-addressed media in v1
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 reconciliation points resolved; v1 = prototype minus sync, light-only, "Field Notes"
- decisions/2026-07-09-tech-stack.md — Flutter + SQLite both sides + custom REST sync + E2EE + Tailscale + Docker Compose
- decisions/2026-07-09-standalone-first.md — app works fully without a server; sync optional
- decisions/2026-07-09-product-model.md — day/entry/memory model, 10 moods, streak, reminders, navigation
- decisions/2026-07-09-design-baseline.md — Field Notes prototype is the canonical visual baseline

## Threads
- journal-app-design — paused — macOS video crash (videoRotationAngle on _Tundra) FIXED + VERIFIED on real camera; VIDCAP stripped, crash fix committed (a714961) + pushed. PR #33 OPEN/MERGEABLE, awaiting human merge. See sessions/2026-07-24-03.

## State snapshot (2026-07-22)
- DB ROUND-TRIP PROVEN (session 2026-07-22-01): real capture write path stored 2 new entries into the on-disk DB (~/Library/Containers/dev.satanshumishra.fieldNotes/Data/Documents/field_notes.sqlite); a separate sqlite3 process confirmed them AFTER the writer exited (entries 2->4); live app rendered DB rows (live-feed-01.png). Store+retrieve are proven end-to-end.
- CAPTURE SAVE-HANG (real bug, fixed): PR #32's save `.timeout()` was a NO-OP — on TimeoutException it re-awaited the same unbounded future, so a never-completing native recorder.stop() hung "Saving..." forever. Fixed in voice/text/video (branch fix/capture-save-hang, commit 0a9902c) + save-hang receipts (RED->GREEN); analyze clean. UNPUSHED, no PR. OPEN: whether a real-mic voice save now actually PERSISTS or only fails-gracefully (native stop() may never return). decisions/2026-07-22-save-hang-timeout-noop-root-cause.md.
- BLACK WINDOW (resolved): the standalone .app binary launch yields no first frame (null layer tree); `flutter run -d macos` renders. ALWAYS run via `flutter run`; VM screenshot works only against a flutter-run instance. decisions/2026-07-22-black-window-standalone-binary.md.

## State snapshot (2026-07-21)
- CAPTURE FLOWS COMPLETE (session 07): note/voice save-hang + video deadlock FIXED; 4 code-review touch-ups applied (finally-flash removed, single-flight timeout-dedupe, error logging, one root ProviderScope); the COMPLETE real-UI app test PASSES 3/3 on -d macos (integration_test/capture_ui_flow_test.dart drives real widgets Save->dismiss->card). analyze clean; full host suite 671 green. Shipped in PR #32, human-merged (origin/main c2fbefd). Live VM screenshots deferred; real camera/mic+TCC human-gated. See sessions/2026-07-21-07.
- LOCAL RUN ACHIEVED (macOS): Xcode 26.6 + CocoaPods 1.17.0 installed (gate cleared); `flutter build macos --debug` -> field_notes.app; app launches + renders the designed home screen against live DB data; analyze clean + 660/660 tests on integrated main. Screenshot the running app via the `_flutter.screenshot` VM RPC (scratchpad/vm_screenshot.dart) — `screencapture` is TCC-blocked; click-driving needs a Claude Desktop quit+reopen for Accessibility. Set LANG=en_US.UTF-8 for CocoaPods. Next phase: debug/troubleshoot.
- Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. 26 squash-merges + ledger commits on origin/main (main = ca2e6f0).
- NO ANDROID SDK on this machine — `flutter build apk` is impossible, and receipts CI never builds Android. File-content assertion is the only receipt for the new desugaring task; do NOT add an Android build to receipts.config.json.
- Plan-review findings are NEVER persisted by the engine; recover them from the harness journal at ~/.claude/projects/<slug>/<session>/subagents/workflows/<runId>/journal.jsonl.
- 31/31 SHIPPED: all v1 MSPs merged (origin/main 54b81a2). shell-nav-integration (#31) was built via a delegated implementer on origin/main and human-merged. App is code-complete (main.dart runnable; no stray TODOs; only the inert v2 sync placeholder). Local main reconciled. Remaining work is the LOCAL RUN phase (macOS build/run for testing), not more MSPs.
- macos/Flutter/GeneratedPluginRegistrant.swift shipped in #21 despite the plan ordering it reverted. Content is byte-identical to what `flutter pub get` regenerates, so it was harmless — but capture-photo/voice/video all add plugins and will all regenerate this same file. Treat it as a SECOND systemic conflict file alongside pubspec.yaml: merge those three one-at-a-time and regenerate rather than hand-resolving.
- THE SYMLINK DEFECT (decisions/2026-07-19-symlink-guard-defect.md): all 7 CLIs under ~/.claude/lib/superpowers-parallel/ were silent no-ops (exit 0, zero bytes) because the main() guard compares a realpath to a literal argv[1] path. It made the engine silently full-re-decompose with NO log line — engine logs CANNOT catch it. Fixed in all 7; THE FIX IS UNCOMMITTED in the .windful-ocean working tree.
- LESSONS: exit code 0 is NOT evidence a Node CLI ran — pre-flight the fold CLI's stdout before EVERY launch. `result.shipped` is MISLEADING — verify via `gh pr list --state open`. pubspec.yaml conflicts are systemic (merge one-at-a-time + union). Classifier blocks DELEGATED gh create/merge but ALLOWS the main thread with per-batch consent. Investigate run `failures` rather than trusting them: batch 2's `git branch -f` security warning was a proven false alarm (the branch did not previously exist).
- THE PROJECT IS NAMED "field-notes" (repo https://github.com/SatanshuMishra/field-notes, PRIVATE). "fireplace" is NOT the project name — it survives only as the local directory path and the .fireplace-worktrees root, both legacy and both load-bearing for hardcoded paths. Never call the project fireplace. The `origin` remote was repointed to the field-notes URL on 2026-07-20 (the old URL only worked via a 301 redirect); this supersedes the "repoint was denied" note in decisions/2026-07-10-mitosis-run-contract.md.
- WORKTREES ARE KEPT ON PURPOSE (decisions/2026-07-20-keep-stale-worktrees.md). Do not propose cleanup.

## Pointers
- .claude/ledger/plans/2026-07-19-next-round.md — TURNKEY plan; Stages A-F DONE, resume at F3 (launch)
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (§0 = implementation status + pre-vendored fonts)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
- .claude/ledger/sessions/2026-07-24-03-journal-app-design.md — latest (VIDCAP stripped; videoRotationAngle crash fix shipped; PR #33 mergeable)
- integration_test/capture_ui_flow_test.dart — real-UI -d macos capture receipt (note/voice/video)
- .claude/ledger/sessions/2026-07-19-02-journal-app-design.md — batch 2 staging + verification
- .claude/ledger/sessions/2026-07-16-02-journal-app-design.md — fold-defect root cause; run.json fixed+trimmed to batch 1
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch block (contract args; flip mergePolicy to "human-gated")
- .mitosis/run.json — STAGED for batch 2 (21 MSPs; base line + entry-cards park delta = 2 lines)
- .mitosis/run.json.pristine-backup — durable 31-MSP source of truth (gitignored, uncommitted)
- .mitosis/batch-tooling/ — trim + verify scripts; MERGED=21, BATCH=[] (fill BATCH with batch-3 ids)
- .mitosis/entry-cards.plan.md — plan carrying the harness-ownership defect
