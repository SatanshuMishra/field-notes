---
thread: journal-app-design
status: paused
updated: 2026-07-21
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: DEBUG/TROUBLESHOOT phase. App is 31/31 and now BUILDS + RUNS on macOS (home screen visually confirmed against live data; Xcode 26.6 + CocoaPods 1.17.0 installed). Per the user, on resume PRESENT the brief and WAIT for SPECIFIC debug instructions — do NOT auto-start a test pass or debugging. Visual checks via scratchpad/vm_screenshot.dart (TCC-free); click-driving needs a Claude Desktop quit+reopen for Accessibility. Full detail in sessions/2026-07-21-05.
branch: main
---

## Status
31/31 SHIPPED and now VERIFIED-RUNNABLE on macOS: analyze clean, 660/660 tests pass on the
integrated main, `flutter build macos --debug` succeeds, and the app launches + renders its designed
home screen against live DB data. Next phase per the user is debug/troubleshoot, awaiting specifics.

## Active Goal
Debug and troubleshoot Field Notes v1 on macOS, driven by the user's specific instructions.

## Next Step
On resume: present the Resumption Brief and STOP. Do NOT begin any debugging or test pass until the
user gives a specific instruction. Then relaunch the app and use scratchpad/vm_screenshot.dart for
visual checks; quit+reopen Claude Desktop only if click-driving (Accessibility) is required.

## Open Risks
- DRIVING the app (click/keyboard) needs Accessibility TCC -> full Claude Desktop quit+reopen.
  SCREENSHOTTING is unblocked via the VM RPC. `screencapture` stays blocked until that relaunch.
- Uncommitted macOS pod-install artifacts in the working tree (xcconfig, project.pbxproj,
  contents.xcworkspacedata modified; Podfile + Podfile.lock untracked) — regenerable; commit-vs-ignore TBD.
- Reminders day-2+ reach still unbuilt (deferred MSP). Android SDK absent (macOS is the only target).
- Local main is 4 ledger commits ahead of origin (unpushed, per pattern).

## Key Decisions
- decisions/2026-07-21-vm-rpc-screenshot-for-visual-verification.md — screenshot via `_flutter.screenshot` VM RPC (screencapture is TCC-blocked)
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — the HUMAN merges every PR
- decisions/2026-07-20-reminders-day2-prearm-followup.md — reminders day-2 follow-up DEFERRED
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — CI runs no Dart test; validate locally
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled
  Memories gallery. All sync/server work is v2 (settings ships an inert disabled sync shell). The
  reminders day-2 pre-arm follow-up MSP is post-31 work (new msp id; not in this run).

## Pointers
- build/macos/Build/Products/Debug/field_notes.app — built macOS debug bundle (relaunch via `open`)
- /private/tmp/claude-501/-Users-satanshumishra-Documents-DevLabs-fireplace/f6e6c7d7-5a3f-4705-83c7-e0eb686bb1da/scratchpad/vm_screenshot.dart — TCC-free screenshot tool
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- .mitosis/run.json.pristine-backup — untouched 31-MSP source; gitignored
- GitHub: https://github.com/SatanshuMishra/field-notes (PRIVATE). Project name is field-notes.

## Recent Sessions
- sessions/2026-07-21-05-journal-app-design.md — verified integrated main (660/660); Xcode+CocoaPods installed; first macOS build + run + visual confirm; hand-off to debug phase
- sessions/2026-07-21-04-journal-app-design.md — 31/31 confirmed; local main reconciled; app code-complete
- sessions/2026-07-21-03-journal-app-design.md — shell-nav BUILT via delegated implementer; PR #31 validated
- sessions/2026-07-21-02-journal-app-design.md — 26→30/31; gh-merge hook-block found; shell-nav parked+unblocked
- sessions/2026-07-21-01-journal-app-design.md — final run: 26/31, usage-limit parked 5, repo pristine
