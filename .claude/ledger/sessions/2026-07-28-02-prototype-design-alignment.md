# Session 2026-07-28-02 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief's next step was to cut a fresh B2-B4 slice with a new `sourcePrefix` and pay for a fourth mitosis dispatch. User directed "Go. Think hard."

Three drifts flagged at resume: the thread's `branch: main` was stale (work sat on `chore/ledger-handoff-session-14`, two commits, no PR); `.mitosis/run.json` had grown 7 -> 15 lines from run 3; everything else verified clean.

## What shipped
**CLUSTER B IS COMPLETE. All four MSPs merged.** `main` `9a53222 -> 3786ac8`.

| MSP | PR | Merge commit |
|---|---|---|
| B1 panel wash + window chrome | #62 (prior session) | `9a53222` |
| B2 rail geometry + brand lockup | #63 | `7489303` |
| B3 nav states + glyph set | #64 | `8f0e8f4` |
| B4 rail footer + bound state | #65 | `3786ac8` |

**The fourth dispatch was never needed.** `refs/mitosis/55d6da7a/b3-nav-states-icons` at `54fd9ef` held B2 **and** B3 complete, already rebased onto post-B1 `main`. Two MSPs recovered for the cost of two local validation runs. Only B4 had no artifact anywhere; it went to a single `implementer` dispatch (152k tokens, 67 tool calls) rather than a mitosis run, because one MSP is not mitosis-shaped.

Cost comparison: 3 mitosis dispatches = ~8.1M subagent tokens for 1 MSP. This session = 3 local validations + 1 implementer dispatch for 3 MSPs.

## Tried and failed
Nothing failed. Two judgment calls that could have gone wrong:
- **Shipping `97d91a8` directly would not have worked.** It is the tip the user approved last session, but it predates the B1 squash-merge and is NOT an ancestor of `main`. `f6aae95`, inside B3's lineage, is the same B2 content rebased onto a main base — content-identical in `sidebar_shell.dart`, verified by empty diff. That is what shipped.
- **Stacked PRs were deliberately NOT opened in parallel.** B3's branch carried B2's commits; against `main` its diff would have double-counted B2 and risked a post-squash conflict. Each MSP was rebased `--onto main` only after its predecessor merged, then revalidated on the new base. Never carried a green from one base to another.

## Verification
Every tip ran `fullValidationCmd` verbatim in a disposable worktree. CI is still not evidence — neither GitHub check runs Dart.

| Tip | analyze | test |
|---|---|---|
| `f6aae95` (B2 alone) | No issues found | 899 passed, 0 failed |
| `54fd9ef` (B2+B3) | No issues found | 899 passed, 0 failed |
| B3 rebased onto post-#63 main | No issues found | 899 passed, 0 failed |
| B4 rebased onto post-#64 main | No issues found | 902 passed, 0 failed |

- The 106-case playback suite ran unmodified in every run — N24 gate 2 satisfied throughout. No test was edited.
- `git diff main 54fd9ef` after #63 and #64 merged: **empty**. The two squash merges reproduced the checkpoint content byte-for-byte.
- B4 fence audit: exactly its 4 permitted files, zero comments introduced, red-then-green test evidence in the agent's report.
- **NOT VERIFIED: the four `integration_test/` flows (gate 3) were never run** — `fullValidationCmd` does not include them. **NOT VERIFIED: the §5.4 macOS visual pass.**

## Running state
Nothing in flight from this thread. Two spawned chip sessions run independently: `task_31a15276` (settings sync-row overflow) and `task_c1e65dae` (stale committed `.g.dart`). Neither touches shell files.

## Deferred + open
- **The §5.4 macOS visual pass is the gate before Cluster C** and is unrun. Cluster B is the chrome framing every screen, there is no golden coverage until H1, and the app cannot be agent-driven here — `flutter run -d macos`, never the standalone binary. The streak card will look unfinished; it is C1's.
- **A live phone bug found in passing, not fixed:** `lib/features/settings/sections/sync_storage_section.dart:115` overflows 219px at 440px width. Proven pre-existing at `54fd9ef` with B4's changes absent. `app_shell_test.dart` only passed because `appSettingsProvider` resolved late and `SettingsScreen` rendered its loading placeholder. Chipped as `task_31a15276`.
- **Two committed `.g.dart` files are stale**, so every `build_runner` run yields hash churn. Chipped as `task_c1e65dae`.
- **Two superseded branches left on origin** — `feat/b3-nav-states-icons`, `feat/b4-rail-footer-state` — replaced by rebased twins. Not deleted; force-push and branch deletion need explicit confirmation. The 14 stale `msp-cluster-b/*` branches are likewise still present and now harmless.
- Standing and unchanged: `receipts.yml` runs unpinned third-party `shaheershoaib/receipts/enforcer@main` (chip `task_e10f4f7e`); A2/A4's app-wide blast radius never walked; the five A3 dialogs never separately opened; OQ-3 and OQ-6 open.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.

## Pick up here
Cluster B needs no more code. The next action is the **human macOS visual pass** across Today, Calendar, Garden, Search and Settings plus the phone shell, checking the panel wash and corner glow, the 42px title bar with its centred caption, the 216px rail, the peony and two-line wordmark, the active/inactive treatment on each of the four destinations, and the footer strip with Settings open and sound toggled both ways. Only after that does Cluster C (Today centre column, C1-C7) get dispatched — and per this session's decision record, check `refs/mitosis/*` for stranded artifacts before assuming any cluster needs a fresh run.
