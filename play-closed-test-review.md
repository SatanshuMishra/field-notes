# play-closed-test-review: Send Field Notes for its first Google Play review via a closed testing release
Status: blocked: Google's review of the 15 changes sent 2026-10-12 (typically up to 7 days).
Updated: 2026-10-17T05:49:35.162Z
Next ids: c3 D9 R5 S1

## Goal

Get Field Notes through its first Google Play review with a closed testing (Alpha) release, so the temporary name 'dev.satanshumishra.field_notes (unreviewed)' becomes "Field Notes" and the app stops being a Draft app. Per decision 01M4RZJMBA5A6245755SZ8KGWK (option B, owner 2026-10-12), the release sent for review is 1.0.1, whose Play bundle leaves sync out, so it needs no foreground service declaration. Sending for review happens only on the owner's yes.

## Done when

- [ ] c1 Google has approved the first review: the Play Console app list no longer shows App status Draft, and the Internal testing page shows no temporary app name.
- [ ] c2 Tag uploads roll out without a manual click: the PLAY_RELEASE_STATUS repository variable is deleted.

## Where things stand

Converted from the old ledger.

## Next step

When Google finishes reviewing the 15 changes sent 2026-10-12, open Play Console > Publishing overview (play.google.com/console/u/0/developers/6978969439520277724/app/4974274441065980218/publishing). If they sit under Changes ready to publish, the owner presses Publish. If the quick checks or the review flagged anything, read it and report before changing anything. After publishing, check criterion c1: the app list no longer shows App status Draft, and Internal testing shows no temporary app name. Then, on the owner's yes, turn Managed publishing off and delete the PLAY_RELEASE_STATUS repository variable (c2).

## Decisions in force

- D1 Play build leaves sync out (option B) instead of declaring the data-sync foreground service: B, chosen by the owner on 2026-10-12: "The next step is to work on Option B". Scope as proposed: the 10 upload Kotlin files move from src/main/kotlin/.../uploads/ to src/selfUpdate/kotlin/...; a stand-in UploadChannel.kt in src/store/kotlin answers that sync is unavailable, so MainActivity.kt:29 stays unchanged; FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC, RUN_USER_INITIATED_JOBS, UploadJobService and the dataSync SystemForegroundService move to src/selfUpdate/AndroidManifest.xml, and the Play build carries none of WorkManager's own foreground-service entries; Settings hides Sync & storage on an Android copy without the upload code, so sync never starts; CHANGELOG.md gains a dated 1.0.1 section; proof is a test that a Play copy shows no Sync & storage plus a check that the built Play bundle requests no foreground-service permission. The switch keeps its name so release.yml stays untouched, and the spec records why. Nothing changes for the GitHub APK, macOS or Windows.
- D2 Interphase hand-off: play-build-without-sync spec and its 4 Steps go to mitosis: Build the revised spec. Top risks for the final report:U+000AU+002D 7.9 and 7.10 are unproven.U+000AU+002D The android_self_update_test store-listing expectation changes, overriding settings-about-updates criterion 16.37, under which the Play-only folder held only AppUpdateChannel.kt.U+000AU+002D Every Android build made without -P fieldNotesSelfUpdate=true now has no sync, including flutter run, the untagged CI APK and the lab kit's builds.
- D3 Mitosis build 1 result: play-build-without-sync committed, go to review round 1: Review round 1. Run code-reviewer, conformance-auditor, security-reviewer (the diff adds a native channel handler and moves the plain-HTTP refusal) and the full suite on the worktree ~/.mitosis/runs/field-notes/play-build-without-sync/trees/play-build-without-sync, range 7a8fbce7...mitosis/play-build-without-sync. The inert 7.7 mac test goes to the final report as an unchanged-behaviour check.
- D4 Review round 1 verdict: play-build-without-sync is green, ship it as a draft PR: Ship. C1 goes to the PR comment as an advisory.
- D5 Option B shipped as draft PR #307; v1.0.1 waits for the owner's merge and yes: Stop at the draft PR. Top risks for the owner:U+000AU+002D 7.9 and 7.10 are unproven.U+000AU+002D Android builds without -P fieldNotesSelfUpdate=true have no sync (risk 01M4S26AMR686NASC3AZXC22GN).U+000AU+002D The settings-about-updates 16.37 store-listing expectation is overridden.U+000AU+002D The 7.7 mac rail test is an unchanged-behaviour check that passes both ways by design.
- D6 Clear the Play Console blockers: replace rc.2 on Internal testing with 1.0.1, Advertising ID No, keep the 1.0.0 notes: Owner chose: replace rc.2 with 1.0.1 on Internal testing (Claude prepares the release and stops before Save and publish for the owner's yes); answer No on the Advertising ID declaration and save (done 2026-10-12, Play said Change saved; the Play build's 576-line Android dependency list and 214 Dart packages hold no ad or analytics SDK, and its merged manifest has no AD_ID); keep the 1.0.0 notes on the Alpha 1.0.1 draft. The Internal testing draft (release 2, bundle 12, rc.2 not included, the same en-US notes as Alpha) sits on Preview and confirm with no warnings.
- D7 Clear the Play Console blockers: replace rc.2 on Internal testing with 1.0.1, Advertising ID No, keep the 1.0.0 notes: Owner chose: replace rc.2 with 1.0.1 on Internal testing (Claude prepares the release and stops before Save and publish for the owner's yes); answer No on the Advertising ID declaration and save (done 2026-10-12, Play said Change saved; the Play build's 576-line Android dependency list and 214 Dart packages hold no ad or analytics SDK, and its merged manifest has no AD_ID); keep the 1.0.0 notes on the Alpha 1.0.1 draft. The Internal testing draft (release 2, bundle 12, rc.2 not included, the same en-US notes as Alpha) sits on Preview and confirm with no warnings.
- D8 Send the first Play review with Managed publishing on and Data safety set to no data collected: Done 2026-10-12: Managed publishing on; Data safety saved as collects or shares no required data (preview: No data collection declared, No data shared, privacy policy link), Play said Change saved; Submit 15 changes for review confirmed, and Publishing overview shows them under Changes in review, sent to Google once quick checks finish (up to 12 minutes). Google says reviews typically complete within 7 days.

## Open risks

- R1 After option B, every Android build made without -P fieldNotesSelfUpdate=true has no sync and no background uploads. That includes flutter run, debug and profile builds, the untagged CI APK and the owner's lab-kit builds (testkit build_manual.zsh, postmerge/build.zsh, device-pass build_android.zsh). Testing sync on Android needs -P fieldNotesSelfUpdate=true.
- R2 Code read at 6b095878: syncEngineProvider (lib/state/sync_providers.dart:79-99) builds and starts SyncEngine on every copy, and the engine runs whenever sync_state syncEnabled is set (lib/data/sync/engine/sync_engine.dart:335); syncAvailableProvider gates only backgroundTransfer and the Settings tabs. A Play copy that joined sync before updating to 1.0.1 (Internal testing testers on rc.2, now auto-updating to 1.0.1) keeps syncing in the foreground while Sync & storage is hidden, so the user cannot see or turn sync off. Fresh Play installs cannot enable sync.
- R3 Data safety now declares no data collected (owner's choice 2026-10-12). That holds for fresh Play installs, but a Play copy that joined sync before 1.0.1 keeps syncing (risk 01M4S857ASR4SP1JZ00B95Z2SR) and so sends User IDs and Device IDs the form no longer declares. Fixing the sync-engine gate makes the declaration true for every Play copy. Bears on c1.
- R4 Managed publishing is on (2026-10-12), so every approved change, including future tag uploads, waits for a Publish click in Publishing overview. Criterion c2 (tag uploads roll out without a manual click) also needs Managed publishing turned off again once the first review is published, besides deleting PLAY_RELEASE_STATUS. Bears on c2.

## Settled, do not reopen

## Where the details live

- Play publishing guide (tracks, variables, one-time setup): docs/deploy/play.md
- Release workflow with the play upload job: .github/workflows/release.yml
- Settings, About and updates run home: U+007E/.mitosis/field-notes/settings-about-updates/rounds.md
- Update signing key setup (owner, once): tool/release/UPDATE_SIGNING.md
- Settings, About and in-app updates pull request (merged 5be3c040): https://github.com/SatanshuMishra/field-notes/pull/305
- Release notes for 1.0.0 pull request (draft): https://github.com/SatanshuMishra/field-notes/pull/306
- Release notes run home: U+007E/.mitosis/field-notes/release-1-0-0-changelog/rounds.md
- Field Notes 1.0.0 GitHub release: https://github.com/SatanshuMishra/field-notes/releases/tag/v1.0.0
- Foreground service demo video for the Play declaration: build/play/field-notes-data-sync-upload.mp4
- Play Console draft release 1.0.0, Closed testing (Alpha), release notes saved, not sent: https://play.google.com/console/u/0/developers/6978969439520277724/app/4974274441065980218/tracks/4698600832753635615/releases/1/prepare
- Play Console Internal testing track (inactive, draft release 7 = 1.0.0-rc.2): https://play.google.com/console/u/0/developers/6978969439520277724/app/4974274441065980218/tracks/4701510011285422855?tab=releases
- Option B spec (play-build-without-sync): docs/specs/play-build-without-sync.md
- Option B run home: U+007E/.mitosis/field-notes/play-build-without-sync/rounds.md
- Old ledger record: thread 01M4Q91AATA5ENJ61JHJ34YWDY in refs/logbook/archive/ledger
