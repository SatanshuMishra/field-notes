# release-1-0-2: Release Field Notes 1.0.2 with the Meadow performance fix
Status: done
Updated: 2026-10-17T05:49:35.162Z
Next ids: c3 D8 R1 S2

## Goal

Publish Field Notes v1.0.2 from main at 36964013 (PR 308, the Meadow snapshot pacing fix): add a dated 1.0.2 section to CHANGELOG.md through the pipeline as a draft PR, and once the owner merges it push the v1.0.2 tag so the release workflow builds and publishes macOS, Windows and Android.

## Done when

- [x] c1 CHANGELOG.md on main has a dated ## [1.0.2] section describing the Meadow performance fix, merged by the owner through a draft PR evidence: PR 309 merged by the owner at 2026-10-14T05:56:03Z as cd7e3b1b; bash tool/release/changelog_section.sh 1.0.2 on origin/main's CHANGELOG.md exits 0 and prints the Fixed group with the three plain-English Windows entries.
- [x] c2 GitHub release Field Notes 1.0.2 is published with the macOS dmg, Windows installer, Android APK, checksums, signature and appcast evidence: Run 38519373652 concluded success (macos, windows, android, release, play all success; play 06:08:33-06:09:24Z uploaded the draft). gh release view v1.0.2 at 2026-10-14: published 06:08:27Z, not draft, not prerelease, assets appcast.xml, field-notes-1.0.2-android.apk, field-notes-1.0.2-macos.dmg, field-notes-1.0.2-windows-x64-setup.exe, SHA256SUMS.txt, SHA256SUMS.txt.sig. Downloaded dmg and setup exe match SHA256SUMS.txt, and SHA256SUMS.txt.sig verifies (OpenSSL 3 Ed25519) against UPDATE_PUBLIC_KEY. Not observed: an installed 1.0.1 copy actually offering the update.

## Where things stand

Converted from the old ledger.

## Next step

Ask the owner whether the Mac's Field Notes 1.0.2 (running since they opened it; containers dev.satanshumishra.fieldNotes and fieldNotesFix were still in ~/Library/Containers at the last check) finished sync setup in Settings, Start syncing, with https://sync.satanshu.tech; once they confirm, close thread 01M4WD0YYAJCQKHDA9N4MY736N.

## Decisions in force

- D1 Interphase hand-off: release-1-0-2-changelog brief handed to mitosis as two Steps in one MSP: Handed off. Next: run.zsh --plan-only, then the build, review round 1, ship as a draft PR; after the owner merges, push tag v1.0.2. Top risks: Windows claims rest on 0289cbbf, not the shipped aa8852d1; section dated 2026-10-13 although the tag may be pushed later; rule wording and placement chosen autonomously.
- D2 Mitosis build result: release-1-0-2-changelog committed at 09123737, gate 3 pass: Review round 1 of MSP release-1-0-2-changelog on range mitosis/release-1-0-2-base...mitosis/release-1-0-2-changelog (36964013...09123737).
- D3 Review round 1 of release-1-0-2-changelog at 09123737: green, no findings; ship: Ship. Next: SHIP=1 ~/.mitosis/field-notes/release-1-0-2-changelog/run.zsh --resume, open the draft PR against main with mitosis's title and body, assign it; after the owner merges, push lightweight tag v1.0.2 at the merge commit.
- D4 Ship of release-1-0-2-changelog: draft PR 309 against main; tag v1.0.2 waits for the owner's merge: Opened https://github.com/SatanshuMishra/field-notes/pull/309 as a draft against main, assigned to SatanshuMishra, bound to the session. After the owner merges: git tag v1.0.2 U+003Cmerge commit> and git push origin refs/tags/v1.0.2, then watch the release run; PLAY_UPLOAD is true with status draft, so the tag also uploads a draft 1.0.2 to the Play alpha track.
- D5 Release v1.0.2: let the automatic Play draft upload run; stop before Play Console publishing: Left PLAY_UPLOAD true and PLAY_RELEASE_STATUS draft untouched (checked 2026-10-14 06:0xZ, both unchanged since 2026-10-12). The release job publishes the GitHub release with SHA256SUMS.txt.sig and appcast.xml; the play job uploads a draft only. Nothing is opened or published in Play Console; that step stays with the owner.
- D6 Mac 1.0.2 install: hold the first launch until the owner removes the old containers: Installed 1.0.2 to /Applications (signature valid, no quarantine), revealed the container in Finder, did not launch. Next: owner trashes both containers, then open -a "/Applications/Field Notes.app".
- D7 Mac sync setup: owner enters the server address and invite code; Claude only stages the address: Copied https://sync.satanshu.tech to the Mac clipboard; told the owner to paste it, to use an existing invite or run `docker exec "$relay" /app/bin/relay invite create --note "U+003Cname>"` on the Arch server, and to join the existing journal instead if a device already syncs there.

## Open risks

## Settled, do not reopen

- S1 Out of scope: Opening Google Play Console or publishing 1.0.2 there: the owner does it (2026-10-14)

## Where the details live

- Old ledger record: thread 01M4WD0YYAJCQKHDA9N4MY736N in refs/logbook/archive/ledger
