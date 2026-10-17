# release-1-2-0: Release Field Notes 1.2.0: dated changelog for the recorder update, tag v1.2.0, publish
Status: done
Updated: 2026-10-17T05:49:35.162Z
Next ids: c3 D10 R1 S1

## Goal

Release Field Notes 1.2.0 with PR #318's recorder changes. The steps: write plain-English notes in a dated section of CHANGELOG.md, `## [1.2.0] - 2026-10-15`, through the pipeline as a draft PR; the owner merges it; then a lightweight tag v1.2.0 on the merge commit runs .github/workflows/release.yml, which publishes the GitHub release.

## Done when

- [x] c1 CHANGELOG.md on origin/main has `## [1.2.0] - 2026-10-15` holding plain-English notes for the PR #318 changes, and bash tool/release/changelog_section.sh 1.2.0 CHANGELOG.md exits 0 evidence: PR 319 merged as cb2428e9. On origin/main, CHANGELOG.md holds `## [1.2.0] - 2026-10-15`, and bash tool/release/changelog_section.sh 1.2.0 on it exits 0, printing the New, Improved and Fixed lists. The published release body opens with the same text.
- [x] c2 Tag v1.2.0 points at the merged release-notes commit on main, and the release workflow run for it publishes the GitHub release Field Notes 1.2.0 with the macOS, Windows and Android files, SHA256SUMS.txt, its signature and appcast.xml evidence: git ls-remote origin refs/tags/v1.2.0 shows cb2428e9, the PR 319 merge commit. Release run 38710300690 completed success in every job: android, windows, macos, release and play. gh release view v1.2.0 shows 'Field Notes 1.2.0', not a draft or prerelease, marked Latest, published 2026-10-15T09:20:42Z, with appcast.xml, field-notes-1.2.0-android.apk, field-notes-1.2.0-macos.dmg, field-notes-1.2.0-windows-x64-setup.exe, SHA256SUMS.txt and SHA256SUMS.txt.sig. appcast.xml advertises shortVersionString 1.2.0, build 23. Not observed: installing any of the files on a device, and what the play job put in Play Console.

## Where things stand

Converted from the old ledger.

## Next step

Follow release run 38710300690 with gh run view 38710300690 --repo SatanshuMishra/field-notes until the macos, windows, android, release and play jobs finish. Then confirm gh release view v1.2.0 lists field-notes-1.2.0-macos.dmg, field-notes-1.2.0-windows-x64-setup.exe, field-notes-1.2.0-android.apk, SHA256SUMS.txt, SHA256SUMS.txt.sig and appcast.xml, and mark c1 and c2 done.

## Decisions in force

- D1 Interphase hand-off: release-1-2-0-changelog brief handed to mitosis as one Step in one MSP: Handed off.U+000AU+000ANext:U+000A1U+002E run.zsh --plan-only.U+000A2U+002E Build.U+000A3U+002E Review round 1 with code-reviewer only (brief lane).U+000A4U+002E Ship as a draft PR against main.U+000A5U+002E After the owner merges, push a lightweight tag v1.2.0 on the merge commit.U+000AU+000ATop risks:U+000AU+002D Version 1.2.0 and the note wording were chosen autonomously.U+000AU+002D The notes rest on host tests with fakes; the live checks 7.29 to 7.31 are the owner's.U+000AU+002D The section is dated 2026-10-15 although the tag may be pushed later.
- D2 Interphase hand-off: release-1-2-0-changelog brief handed to mitosis as one Step in one MSP: Handed off.U+000AU+000ANext:U+000A1U+002E run.zsh --plan-only.U+000A2U+002E Build.U+000A3U+002E Review round 1 with code-reviewer only (brief lane).U+000A4U+002E Ship as a draft PR against main.U+000A5U+002E After the owner merges, push a lightweight tag v1.2.0 on the merge commit.U+000AU+000ATop risks:U+000AU+002D Version 1.2.0 and the note wording were chosen autonomously.U+000AU+002D The notes rest on host tests with fakes; the live checks 7.29 to 7.31 are the owner's.U+000AU+002D The section is dated 2026-10-15 although the tag may be pushed later.
- D3 Build result of release-1-2-0-changelog: committed 0a9695d1, gate 2 pass, reconcile clean; review round 1: First option. Write review/round-1/release-1-2-0-changelog.diff, run suite.zsh once on the worktree, then dispatch code-reviewer.
- D4 Build result of release-1-2-0-changelog: committed 0a9695d1, gate 2 pass, reconcile clean; review round 1: First option. Write review/round-1/release-1-2-0-changelog.diff, run suite.zsh once on the worktree, then dispatch code-reviewer.
- D5 Round 1 verdict for release-1-2-0-changelog: green, no findings; ship next: First option. Run SHIP=1 /Users/satanshumishra/.mitosis/field-notes/release-1-2-0-changelog/run.zsh --resume, then open the draft PR with mitosis's title and body.
- D6 Round 1 verdict for release-1-2-0-changelog: green, no findings; ship next: First option. Run SHIP=1 /Users/satanshumishra/.mitosis/field-notes/release-1-2-0-changelog/run.zsh --resume, then open the draft PR with mitosis's title and body.
- D7 Ship of release-1-2-0-changelog: draft PR 319 against main; tag v1.2.0 waits for the owner's merge: First option. Once the owner merges PR 319, push refs/tags/v1.2.0 on the merge commit, as v1.1.0 was, and follow the release workflow run.
- D8 Tag v1.2.0: lightweight tag on merge commit cb2428e9, release run 38710300690: Pushed refs/tags/v1.2.0 pointing at cb2428e9. The push started release workflow run 38710300690 at 09:04:54Z. Next: follow the run through the macos, windows, android, release and play jobs.
- D9 Tag v1.2.0: lightweight tag on merge commit cb2428e9, release run 38710300690: Pushed refs/tags/v1.2.0 pointing at cb2428e9. The push started release workflow run 38710300690 at 09:04:54Z. Next: follow the run through the macos, windows, android, release and play jobs.

## Open risks

## Settled, do not reopen

## Where the details live

- Prior release brief (1.1.0): /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/release-1-1-0-changelog.md
- PR being released: https://github.com/SatanshuMishra/field-notes/pull/318
- Release-notes brief, decisions and record: /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/release-1-2-0-changelog.md
- Release run home: /Users/satanshumishra/.mitosis/field-notes/release-1-2-0-changelog
- Old ledger record: thread 01M4ZACE4KPKBCJC0CWS1VFEJ1 in refs/logbook/archive/ledger
