# release-1-1-0: Release Field Notes 1.1.0: dated changelog section, tag, GitHub release
Status: done
Updated: 2026-10-17T05:49:35.162Z
Next ids: c4 D7 R1 S1

## Goal

Release what PRs #310 to #316 merged as v1.1.0. A dated `## [1.1.0] - 2026-10-14` CHANGELOG.md section holds the merged Unreleased notes, so the release job can publish. After the owner merges that change, tag v1.1.0 and let the release workflow publish the GitHub release and its automatic Play draft upload. Then clean up the merged branches, worktrees, run directories and scratch files.

## Done when

- [x] c1 CHANGELOG.md on origin/main has `## [1.1.0] - 2026-10-14` holding the merged notes, and bash tool/release/changelog_section.sh 1.1.0 CHANGELOG.md exits 0 evidence: PR 317 merged 2026-10-14T18:13:50Z as 53aace5a (parents 5136555b and fe5cd8e6, the reviewed head); origin/main is 53aace5a. bash tool/release/changelog_section.sh 1.1.0 on CHANGELOG.md from 53aace5a exits 0 and prints Improved (3 lines) then Fixed (4 lines), word for word as merged in PR 316. PR checks pr-title-lint and receipts passed.
- [x] c2 Tag v1.1.0 points at the merged release-notes commit on main, and the release workflow run for it publishes the GitHub release Field Notes 1.1.0 with the macOS, Windows and Android files, SHA256SUMS.txt, its signature and appcast.xml evidence: Tag v1.1.0 -> 53aace5a, the PR 317 merge commit on main. Release run 38613519523: macos, windows, android and release jobs success; release job steps Write the release notes, Write the checksums, Sign the update files and Publish the release all success. gh release view v1.1.0: name Field Notes 1.1.0, not draft, not prerelease, published 2026-10-14T18:34:34Z, marked Latest, assets field-notes-1.1.0-macos.dmg (36.8 MB), field-notes-1.1.0-windows-x64-setup.exe (16.0 MB), field-notes-1.1.0-android.apk (95.1 MB), SHA256SUMS.txt, SHA256SUMS.txt.sig and appcast.xml; body is the seven 1.1.0 notes followed by the install footer. Not observed: the assets were not downloaded, so checksums, the signature and the appcast contents were not checked locally, and no installed app was updated from this release.
- [x] c3 No branch, worktree or run directory from the recorder-comets-and-fixes or release-1-1-0 runs is left, apart from the remote _ledger and unmerged branches evidence: git worktree list shows only the user's checkout and the logbook ledger-worktree. git branch --list 'mitosis/*' is empty: 13 local branches deleted after merge-base --is-ancestor against origin/main. ~/.mitosis/runs/field-notes is empty; the recorder and release run directories and both run homes are in the macOS Trash. Remote branches left are _ledger, chore/ledger-handoff-session-10 and -21, msp-cluster-c/c5 and c6, each with commits not on origin/main; PR branches 310 to 317 were auto-deleted. The session scratchpad is empty.

## Where things stand

Converted from the old ledger.

## Next step

When release run 38613519523 (gh run view 38613519523 --repo SatanshuMishra/field-notes) completes, run gh release view v1.1.0 --repo SatanshuMishra/field-notes --json name,assets and confirm the release Field Notes 1.1.0 lists the macOS dmg, the Windows setup exe, the apk, SHA256SUMS.txt, SHA256SUMS.txt.sig and appcast.xml with the seven notes as its body; mark criterion c2, then close the thread.

## Decisions in force

- D1 Interphase hand-off: release-1-1-0-changelog brief handed to mitosis as one Step in one MSP: Handed off. Next: run.zsh --plan-only, build, review round 1 with code-reviewer only (brief lane), ship as a draft PR against main; after the owner merges, push tag v1.1.0. Top risks: version 1.1.0 chosen autonomously; the Windows reminder line rests on 16.33, unproven on a real PC (still offline); section dated 2026-10-14 although the tag may be pushed later.
- D2 Plan of release-1-1-0-changelog: plan 514acbba9727 clean, build Lane 0 on mitosis/release-1-1-0-base: Build run.zsh without --plan-only; then review round 1 of MSP release-1-1-0-changelog with code-reviewer only (brief lane).
- D3 Build result of release-1-1-0-changelog: committed fe5cd8e6, gate 2 pass, reconcile clean; review round 1: Review round 1 of MSP release-1-1-0-changelog: write the diff, run the suite at fe5cd8e6 after the merged-main suite ends, dispatch code-reviewer with the rendered brief, then candidates, record and verdict.
- D4 Round 1 verdict for release-1-1-0-changelog: green, one LOW advisory; ship next: Ship. Save pipeline.mjs comment as review/release-1-1-0-changelog.comment.md with the Write tool, run promote, then SHIP=1 /Users/satanshumishra/.mitosis/field-notes/release-1-1-0-changelog/run.zsh --resume and open the draft PR against main (base mitosis/release-1-1-0-base equals origin/main 5136555b).
- D5 Ship of release-1-1-0-changelog: draft PR 317 against main; tag v1.1.0 waits for the owner's merge: Opened https://github.com/SatanshuMishra/field-notes/pull/317 as a draft against main with mitosis's title and body, assigned to SatanshuMishra, comment posted, bound to the session. After the owner merges: git tag v1.1.0 U+003Cmerge commit> and git push origin refs/tags/v1.1.0, watch the release run, confirm the GitHub release assets; PLAY_UPLOAD true with status draft uploads a 1.1.0 draft to the Play alpha track, and Play Console stays with the owner.
- D6 Tag v1.1.0: lightweight tag on merge commit 53aace5a, release run 38613519523: Pushed refs/tags/v1.1.0 -> 53aace5a at 18:14Z; release workflow run 38613519523 started on push. Windows job succeeded first. The Play draft upload follows the release job as in 1.0.2; nothing is opened or published in Play Console.

## Open risks

## Settled, do not reopen

## Where the details live

- Release-notes brief, decisions and record: /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/release-1-1-0-changelog.md
- Old ledger record: thread 01M4XR53JC96P2QWWVD92ENG53 in refs/logbook/archive/ledger
