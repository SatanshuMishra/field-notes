Status: accepted
Date: 2026-07-20
Thread: journal-app-design

## Context
`reminders` parked at plan-review after 3 non-converging adversarial iterations. Findings were NOT persisted by the engine (it never writes review artifacts to disk); they were recovered from the harness journal at `~/.claude/projects/<slug>/<session>/subagents/workflows/wf_1a14ffc9-038/journal.jsonl` (review agents a91e88a4bc11bef4c, a3813bc6f990ace4c, a4a9aea165ab33143). Two findings survive iteration 3.

The HIGH one, independently verified: flutter_local_notifications 22.1.0 requires Android core-library desugaring in the APP's Gradle file — "Developers will need to update their application's Gradle file to enable desugaring even if they don't use scheduled notifications" (`~/.pub-cache/hosted/pub.dev/flutter_local_notifications-22.1.0/README.md:214`). `android/app/build.gradle.kts` has NO `isCoreLibraryDesugaringEnabled`, no `multiDexEnabled`, and no `coreLibraryDesugaring` dependency (grep across `android/` returns nothing). Every gate in `receipts.config.json` is `flutter pub get && build_runner && flutter analyze && flutter test` — no Android build — so this merges GREEN while breaking `flutter build apk` for the whole app. The file is outside reminders' fileScope AND outside every other MSP's fileScope: no MSP owns it. Project AGP is 9.0.1 / Gradle 9.1.0, above the plugin's 8.11.1 floor, so version is not a gap; only the config is.

## Decision
Expand `reminders`' fileScope by exactly one file — `android/app/build.gradle.kts` — so the MSP closes the desugaring gap itself in the same PR that adds the dependency. Rejected: escalating it as a documented deferred gap and merging Android-broken.

Rationale is the green-branch invariant (`rules/common/git/pull-requests.md`): a PR merged into any branch must not break the application on that branch. Adding the plugin without desugaring does exactly that, invisibly to CI. Deferring trades Pillar 1 (Quality) for Pillar 3 (Speed), which the pillar order forbids. Collision risk is zero: reminders is the only unit worked this relaunch, and no other MSP declares that path.

The second surviving finding (MEDIUM, in-scope): the Task 4 adapter's `bool _initialized` latch is set after two awaits, so concurrent `_ensureInitialized` calls re-run `tz_data.initializeTimeZones()`, whose tail calls `setLocalLocation(_utc)` (`timezone-0.11.1/lib/src/env.dart:49-57`) — an in-flight `schedule()` can then compute `tz.TZDateTime.from(at, tz.local)` against UTC and fire at the wrong absolute instant. Fixed within fileScope: cache the init Future (`Future<void>? _ready`) and serialize `ReminderCoordinator.sync` with a last-wins guard.

## Consequences
The worker must NOT copy the plugin README's `kotlinOptions` block verbatim — this project already uses the modern `kotlin { compilerOptions { jvmTarget } }` form and has Java 17 source/target set. Only three additions are needed: `multiDexEnabled = true`, `isCoreLibraryDesugaringEnabled = true`, and `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.

Sets a precedent: when a dep-adding MSP requires a platform-config change that no MSP owns and CI cannot see, the fix ships in the same PR under a minimal orchestrator-granted fileScope expansion, recorded here. It does not license planners to self-grant carve-outs — iteration 2 correctly rejected exactly that. The macOS `GeneratedPluginRegistrant.swift` case remains DIFFERENT and keeps its existing treatment (revert on branch; integration-time `flutter pub get` regenerates it), per commit 326686a's precedent.
