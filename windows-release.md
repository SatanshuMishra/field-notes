# windows-release: Windows build and tag-driven release for all three platforms
Status: done
Updated: 2026-10-17T05:49:35.162Z
Next ids: c5 D8 R4 S1

## Goal

Add Windows as a third Field Notes platform that looks and works like the macOS app with no macOS or Android regression, and a GitHub workflow that builds macOS, Windows and Android and publishes them as one release when a v* tag is pushed. Spec docs/specs/windows-build-and-release.md; built by mitosis as three stacked draft PRs (windows-desktop, windows-runner, release-pipeline).

## Done when

- [x] c1 Draft pull requests from mitosis are open for the owner to review: windows-desktop, windows-runner stacked on it, release-pipeline stacked on that. evidence: gh pr view shows all three as drafts, each head matching the commit its suite passed:U+000AU+002D #297: mitosis/windows-desktop (89f7a06f) -> mainU+000AU+002D #298: mitosis/windows-runner (19324d80) -> mitosis/windows-desktopU+000AU+002D #299: mitosis/release-pipeline (3e14f398) -> mitosis/windows-runnerU+000AURLs: https://github.com/SatanshuMishra/field-notes/pull/297, /298, /299.U+000AThe mitosis ship ran with exit 21, because 8 windows-desktop properties are inconclusive. Those 8 were re-proved by hand, as #297's body records.
- [x] c2 The release workflow's pull-request build on the top of the stack produces a macOS DMG, a Windows installer and an Android APK. evidence: release workflow run 37865273929 on PR #299 head 1000e323: macos, windows and android jobs success, release job skipped (not a tag). Artifacts macos 33.5 MB, windows 15.3 MB (field-notes-1.0.0-pr2-windows-x64-setup.exe), android 43.5 MB. Main 48837767 has the same tree as 1000e323 (empty git diff).
- [x] c3 The Windows installer from that build installs and passes the spec 7.26 walk-through in the VM lab's Windows 11 instance, with findings reported. evidence: Main build (run 37865273929) walked through in vmlab Windows 11 Arm64 on the Microsoft Basic Display Adapter: install, Start launch, onboarding, light and dark, caption buttons, maximise/restore/minimise/close, drag, snap, resize from right, top and left edges, Ctrl+B/I/Z, spell check with suggestions, clipboard paste and Explorer drop of photos, Calendar, Search, export zip contents, uninstall, reinstall keeping data. Finding: unowned export dialog opening in the install folder; fixed in PR #300 and re-tested from its CI installer (run 37879286238, all checks green): photo picker and first export open the user folder on a fresh MRU, the export dialog is owned and stays in front when the app is clicked, the second export reopens Documents, voice and video recorders still show their no-device messages. Not observed: recording and playback (no mic, camera or speaker in the lab), the Meadow (software rendering saturates the VM), real-GPU rendering (the lab's VMware SVGA adapter loses the D3D11 device).
- [x] c4 The whole test suite and flutter analyze pass on each PR branch. evidence: suite.zsh passed on each branch at its final head:U+000AU+002D windows-desktop 89f7a06f: 4800 app testsU+000AU+002D windows-runner 19324d80: 4811 app testsU+000AU+002D release-pipeline 3e14f398: 4823 app testsU+000AOn all three, flutter analyze and dart analyze report no issues and 178 relay and message-package tests pass. Each run went folder by folder, with test/features/garden in TZ=America/Edmonton and test/impeller also run with --enable-impeller. Earlier failures were build-hook races on native-asset dylibs, and the final runs were clean without reruns. This proves the Dart suite and the C++ text tests only. The C++ has not been compiled here.

## Where things stand

Converted from the old ledger.

## Next step

Owner merges PR #300, then pushes a first tag (suggested v1.0.0-rc.1 as a trial) from up-to-date main. When the tag's release run finishes, confirm the GitHub Release lists the DMG, the Windows setup exe, the signed APK and SHA256SUMS.txt, and that the APK's signer is the new release key (apksigner verify --print-certs). Then close the thread; the open risks about real-GPU rendering and untested media and Meadow need a real Windows PC check by the owner.

## Decisions in force

- D1 Windows join window offers only the eight words; no QR scanning on Windows: Type-only on Windows, Step windows-join-window, criterion 7.28. The takePicture loop leaks files into a synced folder, and a native frame source could not be proven in the lab without a camera. macOS keeps scanning. A Windows scanner is a follow-up the owner can ask for.
- D2 Stack order: desktop Dart first, Windows runner second, release pipeline last: Desktop, runner, pipeline. Shipped first, the pipeline's own pull-request Windows build would fail because no windows/ folder exists yet. Shipped last, its pull-request build compiles the whole stack on windows-latest and produces the installer for the VM lab check. decisions.md line 15 was rewritten to say so.
- D3 Windows toast status read through WRL, not C++/WinRT: WRL ABI: it compiles under the template's flags with no exception handling and uses the documented API instead of a registry layout. Every runner and bridge task now carries the build-flag rule (no try/catch/throw, check every HRESULT, ComPtr).
- D4 Caption glyph tone follows the real background: no viewer override, Meadow follows its sky: Second option. DarkCaptionSurface gained `dark` and recounts on update. meadowSkyDarkensCaptions(skyTop) uses ThemeData.estimateBrightnessForColor, the same rule the phone full screen uses for its system bars. The viewer and meadow_full_screen.dart are back to HEAD. The garden_view.dart wiring is outside lane 1's write-set, so it is saved as ~/.mitosis/field-notes/windows-release/lead-meadow-sky-captions.patch and is pushed as a lead commit on mitosis/windows-desktop after the PR opens. The spec text for 7.31 still says viewers; the PR body must say so.
- D5 A Windows recording that cannot leave Videos is kept in place, not copied or dropped: The third option, committed as windows-desktop 976d7542. No recording is lost and no orphan is left: the original is claimed and enters _OwnedCaptures, which deletes it once the entry is saved or discarded. The test 'a Windows recording that cannot leave the Videos folder is kept there' makes the folder read-only with chmod 555; it fails on the old code.
- D6 Release workflow: wider PR paths, numeric macOS build name, flutter-action stays at @v2: Committed as release-pipeline 95145a16:U+000AU+002D The four paths are added.U+000AU+002D The version step also writes build_name=${version%%-*}, and only the macOS tagged build uses it.U+000AU+002D Secrets pass through a sed escape that doubles backslashes.U+000AU+002D The Android release notes tell users to uninstall earlier non-release builds.U+000Aflutter-action stays at @v2 to match the repository's existing workflows; the PR body recommends pinning it before the signing secrets are added. Spec 7.20 and 7.21 still state 8 paths and the full version as the build name, and the PR must say so. The spec was not edited, because mitosis checks the spec for drift on resume.
- D7 Windows runner starts in the user folder with the working folder out of DLL search: FOLDERID_Profile at the top of RunFieldNotes plus SetDllDirectoryW(L"") at the top of wWinMain (d4afbc1b). Nobody moves the profile folder, the first dialog opens in the user's home with Documents, Downloads and Pictures one click away, Windows reopens the last folder afterwards, and the working folder is out of DLL search entirely (stricter than main). Cost: the first dialog starts one level above Documents rather than in it, unlike macOS.

## Open risks

- R1 desktop-photo-paste-drop's 'a Windows path is classified by its extension' test is red at HEAD only through a renamed constant; HEAD already classified those paths correctly. Disclose it in the windows-desktop PR body. Bears on c1.
- R2 On the lab's VMware SVGA 3D adapter (Windows 11 Arm64, app running under x64 emulation) Flutter's Impeller OpenGLES-over-ANGLE renderer logged 'D3D11 device was removed' on every launch and the picture froze; Flutter does not recover from device loss. On Windows' software adapter it renders correctly. Unverified on a real Windows PC GPU and on real Windows-on-Arm hardware. Bears on c3.
- R3 Voice and video recording and playback, and the Meadow, were not exercised on Windows: the lab instance has no microphone, camera or audio output, and the Meadow drawn in software saturates its four virtual cores. Needs a real Windows PC. Bears on c3.

## Settled, do not reopen

## Where the details live

- spec: docs/specs/windows-build-and-release.md
- decisions: docs/specs/windows-build-and-release.decisions.md
- interview record: docs/specs/windows-build-and-release.record.json
- Steps for mitosis: docs/specs/windows-build-and-release.items.json
- mitosis run harness (charter, run.zsh, accept, suite, pr adapter): U+007E/.mitosis/field-notes/windows-release/
- mitosis run directory: U+007E/.mitosis/runs/field-notes/2026-10-08-windows-release
- Old ledger record: thread 01M4EH20N6QA6P2KXMVN1NCBH7 in refs/logbook/archive/ledger
