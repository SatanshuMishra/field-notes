# Session 2026-07-27-01 — prototype-design-alignment

## Where it started
The user dropped `docs/prototype/` (the Claude Design handoff bundle) into the repo with six screenshots pairing prototype against shipped app, and reported four areas of drift: the Today landing page, the right sidebar, the flower art, and the video/voice/note capture modals. They asked for an audited spec, not an implementation, and were explicit that app-only UI/UX (the video player) must survive.

## What shipped
- `docs/specs/2026-07-26-prototype-design-alignment.md` — 2,060-line alignment spec, 39 MSPs in 8 clusters (A foundations, B chrome/rail, C Today centre, D right rail, E flower art, F mood picker, G capture, H verification), MSP-ordered bottom-up for mitosis.
- `docs/prototype/` committed (was untracked) — the design bundle is now the in-repo source of truth for every citation in the spec.
- `.claude/ledger/decisions/2026-07-27-prototype-alignment-open-questions.md` — five of seven open questions resolved.
- New MSP C7 (video entry card poster chrome), authored this session after OQ-7 resolved; the first draft deliberately had no MSP for it.
- All in commit `1ebb3f5` on `chore/ledger-handoff-session-07`.

Audit method: a 13-agent dynamic workflow (run `wf_820c28e3-b24`, 1.76M subagent tokens, 389 tool calls, 68 min) — 4 prototype-contract extractors piped into 4 implementation auditors, then a preserve-list sweep, a `researcher` pass on Flutter porting technique, and an adversarial verifier, then spec authoring and an adversarial spec critique that edited the spec in place.

Result: 130 gaps — 21 critical, 48 high, 48 medium, 13 low; 90 drift, 31 missing, 9 additive. 72 elements verified already faithful and fenced off. 23 preserve items bound to the MSPs that endanger them (§2.7).

Three systemic root causes, each producing dozens of symptoms:
1. The token layer is correct but disconnected — `Palette.pageGradientInner`/`panelTop`/`panelCoralTint` carry right values and are referenced by no shell or screen; the app paints flat `Palette.page` `#D9CBB2`, which is the prototype's colour OUTSIDE the device frame.
2. The prototype's shadow ladder (1.5px chips / 2px cards / 3px hero, opaque marking emphasis) was collapsed into two constants, and `StickerButton` applies `Shadows.button` to every variant — but shadow ABSENCE is what makes a button secondary.
3. `lib/app/app.dart:20` builds `MaterialApp` with no `builder`, and five dialogs return sheets straight into the root overlay with no `Material` ancestor, so Flutter's `_errorTextStyle` yellow double-underline is shipping to users. This is MSP A3, dependency-free.

## Tried and failed
- The audit's `card-shadow-offset-and-opacity` finding was **overstated** and the adversarial verifier caught it. Its premise (one default card shadow, one emphasis shadow) is false — the prototype has 33 distinct box-shadow values. `Shadows.card` offset(3,3)/20% is an EXACT match for the mood banner at `:93` and four other hero cards, and `Shadows.button` 1.5px matches the prototype's most common opaque button shadow (12 uses vs 6 at 2px). The spec was re-scoped to ask for a shadow SCALE rather than a corrected offset. Lesson: a gap phrased as "everything is wrong" usually means the reference was sampled once.
- The spec's first draft claimed in §7 that every value had been confirmed at its cited line. False. Two regions are systematically off by one (note-composer body `:467-473`, and the entire voice/video composer `:479-519`, ~20 citations) and three more were simply wrong. The critic corrected them and rewrote §7 to instruct implementers to re-verify rather than trust the document. The same off-by-one bit OQ-7: the video card values are at `:128-130`, not `:127-129`.
- The spec critic found 9 execution blockers in the first draft and fixed all in place — three were MSP-shippability failures of exactly the kind the spec's own governing invariant forbids (A2 not compiling, E1 shipping a stemless Garden, C4 consuming a surface B4 creates).

## Verification
- No application code changed this session — spec and docs only. No test suite was run, and none was warranted.
- Claims were verified individually rather than by suite. Load-bearing checks run in the main thread before accepting OQ-4: `grep -rn "Chooser" lib --include="*.dart"` (only `today_capture_buttons.dart:42,:79` outside the chooser dir) and `grep -rn "onCapture" lib` — confirmed `app_shell.dart:41` resolves to `_openCapture` (`:30-32`) -> `openCapture(...)`, bound at `bottom_bar_shell.dart:116`. The chooser therefore survives removal of the desktop button; expected and observed.
- `grep -rn "Capture'" test/ integration_test/` — found three test files that go red with the button (`today_capture_buttons_test.dart:43`, `today_screen_test.dart:89`, `capture_ui_flow_test.dart:54`) plus `bottom_bar_shell_test.dart:52`, which covers the phone path and must stay green. All four are now named in D3.
- `git status --short` after commit `1ebb3f5` — clean, expected and observed.

## Running state
none

## Deferred + open
- **OQ-3** — entry-card Edit/Delete placement. The prototype puts them in Day Detail (`:406-407`), not on Today cards. Touches no MSP. Note the buttons are currently invisible on Today anyway (`today_entry_feed.dart:100-107` passes neither callback), so live risk is confined to Day Detail.
- **OQ-6** — photo attachment model. Entangles three decisions: which model ships, whether `PhotoTray` gets wired in at all (it is currently dead UI, mounted by nothing in `lib/`), and cap 3 vs 8. No MSP touches photo attachment until this is answered.
- Execution itself. The spec is approved and unstarted; nothing in `lib/` has moved.
- Demoted from PROJECT.md for cap enforcement (files remain on disk, content unchanged): `decisions/2026-07-22-capture-finalize-fix-strategy.md` (voice=record 7.x upgrade done+verified; video=vendor camera_macos->AVCaptureMovieFileOutput, plus a disk-verify guardrail); `decisions/2026-07-22-save-hang-timeout-noop-root-cause.md` (bounded timeout fails gracefully but does not persist; real fixes are native — its timeout claim was already corrected by `2026-07-21-capture-flow-root-cause-and-fix.md`); `decisions/2026-07-19-entry-cards-fix-and-batch-2.md` (batch 2 = capture-core + entry-cards + reminders; entry-cards fixed-and-included under harness single-ownership; garden-screen deferred to batch 3); `.claude/ledger/plans/2026-07-24-video-controls-overlay-plan.md` (the executable overlay plan, superseding the controls spec where they disagreed — its thread closed 2026-07-26).

## Pick up here
Run mitosis against `docs/specs/2026-07-26-prototype-design-alignment.md`, starting with Cluster A — every other cluster depends on it. A3 is the highest value-per-line MSP in the set: dependency-free, and it fixes a real shipping defect (the yellow underline) across five dialogs, so it can land in parallel with A1/A2. Before dispatching, re-read §7 — the spec has been wrong about line numbers once and says so.
