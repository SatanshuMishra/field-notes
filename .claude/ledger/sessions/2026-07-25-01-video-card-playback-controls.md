# Session 2026-07-25-01 — video-card-playback-controls

## Where it started
Resumed on the explicit slug. Verification against code found one ledger drift immediately: the spine claimed
23 commits ahead at `1bbeef7`, actual was 22 (23 counted the ledger commit on top). Corrected before any work.
The user then asked to "resolve the CRITICAL issues" — there were NONE open; all three CRITICALs were fixed and
mutation-verified in the prior session. Said so rather than inventing them, and scoped to the four MEDIUMs.

## What shipped
Eleven commits, `ef54164..00f695d`. Branch is now 34 commits ahead of `origin/main` (still `5cb5bad`).
Test count 825 -> 856. All eleven specified review fixes applied, plus one unlisted twin, plus the overlay.

- `ef54164` / `7be6cc1` — the four MEDIUMs. Attempt-identity guard between the resume seek and the requested
  play; `dispose()` routed through `_teardownPlayer()`; generation-blind `_recoverFromPlaybackError` fixed on
  the interaction path; mute re-applied after reload. Plus the vacuous past-the-cap receipt rewritten to
  discriminate per card.
- `a4e98cd` — LOW 8, the scrubber drag latch: cleared on `!_enabled` rather than on `onSeek == null`, so a
  null `total` with a live `onSeek` can no longer strand a stale dragged position.
- `72f02ee` — LOW 10 plus the unlisted twin in `voice_body.dart`.
- `608b423` — LOW 5, 6, 7, 9, 11 in `video_body.dart` / `video_transport.dart`.
- `acf0976` — the hover-reveal overlay, `lib/features/entry_cards/cards/video_controls_overlay.dart` (218
  lines) plus 18 receipts. `video_body.dart` went 674 -> 672 despite gaining the seam.
- `b0c0b9b` / `df9c5f0` / `8daed22` / `00f695d` — three decision records, the overlay plan, thread refresh.

Dispatch shape: wave 1 was two parallel agents (MEDIUMs 1-3 in one file, MEDIUM 4 in another). Wave 2 was
three code agents plus one read-only architect running concurrently. File ownership was fenced per agent;
after wave 1 the fence was tightened to forbid foreign-file edits even for temporary mutation checks.

## Tried and failed
- **An unlisted defect was found by an agent's own rationale and confirmed by the orchestrator.**
  `voice_body.dart` returned early on unchanged resolver identity, so a changed `mediaId` under a stable
  resolver was ignored entirely and the card kept playing the OLD file. That is LOW 5's defect — filed
  against the video card only — sitting unfixed in its twin, in nobody's scope. Swept.
- **Six specified instructions were wrong and the agents were right to refuse them**, continuing the
  thread's pattern. MEDIUM 2's prescribed capture site (`_onPlaybackFailure` captures the generation) is
  called from INSIDE the catch block, after the restart already bumped `_generation`, so it captures the LIVE
  attempt's identity and the guard passes; capture had to move to `_toggle`/`_play` entry. LOW 6 offered two
  remedies and both were wrong: re-acquire-before-release is impossible (the card's own token blocks the
  re-acquire at cap, and `VideoSlots` has no swap API), and `evictUnpinned` would reverse a ratified decision
  while evicting a third innocent holder. LOW 9's suggested `SemanticsService.announce` is `@Deprecated` as
  of Flutter 3.35 and would have broken the clean analyze. The diagnoses held every time; the prescriptions
  did not.
- **The orchestrator's own overlay plan was wrong in three places**, two of which would have silently broken
  every receipt. `setUp`/`tearDown` CANNOT restore `debugDefaultTargetPlatformOverride` — `_verifyInvariants()`
  runs at the end of the test BODY, before `tearDown` — so `TargetPlatformVariant` via `variant:` is the only
  working form. And `find.bySemanticsLabel` reads `debugSemantics`, a STALE cache: probed at full hide with
  `opacity=0.0` and live-tree `labels=[]`, it still returned a match. `find.semantics.byLabel` is required.
- **A null mutation is ambiguous, and this session hit both readings.** On the voice card, a guard that no
  mutation could kill was genuinely REDUNDANT (its regression was already pinned by a sibling receipt) and was
  collapsed. On the overlay, a latch-clear that no mutation could kill was UNCOVERED, not redundant: removing
  it breaks the resume-after-pause path, which had no receipt. Same symptom, opposite correct response. See
  `decisions/2026-07-25-null-mutation-means-redundant-or-uncovered.md`.
- **A fence was violated in wave 1.** The test-integrity agent mutated a file it did not own to run its
  mutation check. It restored correctly (verified by blob hash) and no work was lost, but only because the
  concurrent agent had not yet written. The wave-2 fences were tightened to forbid this outright.
- **Two items could not be receipted and were reported rather than faked.** LOW 11 (`Iterable` -> `List`) has
  no observable runtime difference for any `List` input; the gate is analyze plus existing backoff tests.
  MEDIUM 1's `dispose()` half leaves the suite green under mutation, because once the attempt-identity guard
  exists no continuation can reach `_player` after unmount. Implemented as defensive alignment with
  `voice_body.dart`, unreceipted, and said so.
- No hardware verification was attempted. Nothing in this session is confirmed on real macOS.

## Verification
- `flutter analyze` — expected `No issues found!`; observed clean at every commit boundary and at `00f695d`.
- `flutter test` — 825 -> 829 -> 838 -> 855 -> 856, every delta reconciled explicitly against the previous
  count. Each wave was re-verified by the orchestrator independently of the subagents' claims, never inherited.
- Mutation checks run on every load-bearing receipt across both waves; each reverted mutation reddened exactly
  its intended receipt and nothing else. The one mutation that reddened NOTHING (`M6a`, the overlay latch
  clear) was investigated rather than accepted, and turned out to be a coverage hole; it now reds exactly one.
- The two defect-audit receipts were confirmed byte-identical by BLOB HASH at every wave boundary:
  `video_body_test.dart` = `4a16235ead9e80b26a26e11de14d17571d50c1a0`,
  `media_image_test.dart` = `dc1c59e79a288ef7746e7365682d7dc8820bbf5f`.
- Structural checks at hand-off: `ExcludeFocus` absent from the overlay (0 occurrences), `IgnorePointer` /
  `AnimatedOpacity` / `MouseRegion` all present, no comments added anywhere in `lib/`, shared harness and
  fakes byte-identical except the two additive test-only parameters the overlay plan named.

## Running state
- none. All six subagents completed. Working tree clean at `00f695d`. Nothing backgrounded, nothing to kill.

## Deferred + open
- **THE HARDWARE RUN IS THE ONLY REMAINING GATE.** All nine completion criteria are met in code and NONE is
  hardware-confirmed. Several criteria say "human-confirmed on macOS hardware" in their own text, so the DoD
  gate correctly refuses `done`.
- **The user announced a follow-up on the video-card-preview for the next session, with specific instructions
  to come. Do not start it; wait for the instruction.**
- The branch has NO upstream and has never been pushed. 34 commits. Pushing would be its first publish.
- Controller-extraction seam still deferred. `video_body.dart` is 672 lines — inside the 800 ceiling, over the
  200-400 target. It is where both CRITICALs lived and would make the lifecycle unit-testable without a tree.
- Voice-card twins: three known (uncapped eager init, no retry affordance, 40x40 tap target below the floor)
  and a fourth was found and fixed this session. Assume more exist; sweep deliberately rather than one at a time.
- Overlay items deliberately out of scope: touch double-tap +/-10s seek, scrubber hover-thickening on desktop.
- `AnimatedOpacity` cost on real macOS unmeasured; six visible cards means six extra layers [unverified].
- The 3s hide delay is a design choice, exposed as `hideAfter` so hardware can retune it without touching
  receipts.
- Readout contrast ~2.9:1 (`Palette.muted` on `Palette.cardWarm`) and the Try-again chip on
  `Palette.dangerSurface` remain unmeasured. Both pre-existing token pairings.
- Everything inherited from session 09 is still open: blob backfill not run against the live container
  (restore point `/Users/satanshumishra/field-notes-container-backup-2026-07-24`), export-ZIP extensions
  unconfirmed, integration tests still write into the real journal container, two junk voice entries pending
  in-app deletion, merged branch `fix/media-blob-extension-playback` not pruned. Sibling thread
  `post-ship-hardening` remains paused and carries these.
- Background task chip for two stale committed generated files (`lib/features/settings/settings_providers.g.dart`,
  `lib/state/media_provider.g.dart`) still not started.

## Pick up here
Wait for the user's specific follow-up instruction on the video-card-preview. Do not begin it, and do not
start the hardware run unprompted — `flutter run -d macos`, never the raw binary, is the standing gate and it
is the human's to run. Do NOT open another review round on `video_body.dart`: severity went
CRITICAL -> CRITICAL -> MEDIUM across three rounds and every specified item is now applied.

## Demoted from PROJECT.md (cap enforcement, content preserved verbatim)

Mitosis engine-era residue, historical now that 31/31 shipped and the app is code-complete:

- Plan-review findings are NEVER persisted by the engine; recover them from the harness journal at
  ~/.claude/projects/<slug>/<session>/subagents/workflows/<runId>/journal.jsonl.
- THE SYMLINK DEFECT (decisions/2026-07-19-symlink-guard-defect.md): all 7 CLIs under
  ~/.claude/lib/superpowers-parallel/ were silent no-ops (exit 0, zero bytes) because the main() guard
  compares a realpath to a literal argv[1] path. It made the engine silently full-re-decompose with NO log
  line — engine logs CANNOT catch it. Fixed in all 7; THE FIX IS UNCOMMITTED in the .windful-ocean working tree.
- LESSONS: exit code 0 is NOT evidence a Node CLI ran — pre-flight the fold CLI's stdout before EVERY launch.
  `result.shipped` is MISLEADING — verify via `gh pr list --state open`. pubspec.yaml conflicts are systemic
  (merge one-at-a-time + union). Classifier blocks DELEGATED gh create/merge but ALLOWS the main thread with
  per-batch consent. Investigate run `failures` rather than trusting them: batch 2's `git branch -f` security
  warning was a proven false alarm (the branch did not previously exist).
- .mitosis/ — engine-era artifacts, all historical now that 31/31 shipped (run.json staged for batch 2,
  run.json.pristine-backup as the durable 31-MSP source, batch-tooling/ trim+verify scripts, entry-cards.plan.md
  carrying the harness-ownership defect).

Engine-era pointers demoted from the PROJECT.md Pointers section, all files still on disk:

- .claude/ledger/plans/2026-07-19-next-round.md — TURNKEY plan; Stages A-F DONE, resume at F3 (launch)
- .claude/ledger/sessions/2026-07-19-02-journal-app-design.md — batch 2 staging + verification
- .claude/ledger/sessions/2026-07-16-02-journal-app-design.md — fold-defect root cause; run.json fixed+trimmed to batch 1
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch block (contract args; flip mergePolicy to "human-gated")
