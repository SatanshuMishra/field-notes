Status: accepted
Date: 2026-07-20
Thread: journal-app-design

## Context
reminders parked after 3 non-converging plan-review iterations. Findings are NOT persisted by the engine; recovered from the harness journal for run wf_1a14ffc9-038 (see sessions/2026-07-20-01 for the path). The surviving HIGH finding, independently verified: flutter_local_notifications 22.1.0 requires Android core-library desugaring in the app's Gradle file (plugin README:214), and `android/app/build.gradle.kts` has none — no `isCoreLibraryDesugaringEnabled`, no `multiDexEnabled`, no `coreLibraryDesugaring` dep. Every receipts gate is `pub get && build_runner && analyze && test`, so it merges GREEN while leaving the app unbuildable on any machine with an Android toolchain. No MSP owns that file. AGP 9.0.1 / Gradle 9.1.0 are above the plugin's 8.11.1 floor, so only config is missing.

## Decision
Expand reminders' fileScope by exactly one file — `android/app/build.gradle.kts` — so the MSP ships the desugaring config in the same PR that adds the dependency. Rejected: deferring it as a documented gap and merging Android-broken, which violates the green-branch invariant and trades Quality for Speed. Zero collision risk: reminders is the only unit worked, and no other MSP declares that path.

## Consequences
Verified: there is NO Android SDK on this machine (`flutter doctor`; ANDROID_HOME/ANDROID_SDK_ROOT unset; absent from all standard locations). So `flutter build apk` is impossible for worker, orchestrator, and CI alike. Two rulings follow: (1) `receipts.config.json` is NOT extended with an Android build — it would fail instantly and break every gate for every MSP; file-content assertion is therefore the strongest verification available, not a weak substitute. (2) The worker must not attempt the build or install an SDK.

Honesty correction: the reviewer called this "a regression to a currently-buildable target." That premise is false — Android is not buildable here either way. Accurate claim: the config is wrong for any toolchain-equipped machine; the fix is correct and ships; it is unverifiable by execution in this environment.

The worker must NOT copy the README's legacy `kotlinOptions` block — this project already sets the JVM target via `kotlin { compilerOptions { ... } }`. Only three additions are permitted. This grant licenses no further self-service carve-outs; the macOS `GeneratedPluginRegistrant.swift` case keeps its opposite treatment (revert on branch; integration `flutter pub get` regenerates it) per commit 326686a.
