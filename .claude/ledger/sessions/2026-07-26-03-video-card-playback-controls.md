# Session 2026-07-26-03 — video-card-playback-controls

## Where it started
Resumed on the explicit slug via `/resume-project video-card-playback-controls`. The Resumption Brief
was presented and the user said "Go", authorizing the one documented next step: the MSP 4 explainer.
No code was to be written and mitosis was not to be dispatched. The session then closed the thread.

## What shipped
- THE MSP 4 EXPLAINER (the thread's last outstanding assignment) — delivered in chat, no code. Four
  independent reasons Phase 3 / Today-feed virtualization was never authorized:
  1. Phase 1 (poster-first, #41/#44) removed the decoder pressure that motivated it; at-rest decoders
     went 6 -> 0, so the decoder-SAFETY argument evaporated and only a scroll/widget-count question
     remained.
  2. Virtualization never delivered what it was reached for: Flutter's ~250px `cacheExtent` keeps
     ~3-4 of the ~500px cards alive anyway, already under the 6-slot cap. "Only visible cards decode"
     was never true of virtualization; Phase 1 was always the root fix.
  3. The cheap version is forbidden here. MSP 3's Option B (`shrinkWrap: true`) works only in a
     BOUNDED position; the Today feed has no bounded ancestor, so shrinkWrap would size the viewport
     to its content and build every child anyway. Phase 3 needs a genuine sliver rewrite, done TWICE
     (stacked and withRail are structurally different trees) — a large, risky diff.
  4. The real bottleneck may be a layer down: there is no pagination in the query layer at all.
- THREAD CLOSED `done`. DoD gate passed on verified evidence, not on the prior "appear met" hedge.
- decisions/2026-07-26-msp4-today-virtualization-not-authorized.md — the non-authorization recorded so
  a future reader finding Phase 3 in the spec does not re-litigate it.

## Tried and failed
- `session-continuity:ledgerize` was NOT used despite the user naming it, and this is the load-bearing
  discovery of the session. There are TWO ledger systems visible here and only one is populated:
  the session-continuity MCP store is SEPARATE and EMPTY for this project (its `thread_id` is a 26-char
  ULID, `^[0-9A-HJKMNP-TV-Z]{26}$`; this project's threads are slug-named markdown), and `find` returns
  ZERO non-markdown artifacts anywhere under `.claude/ledger/` — no index, no db, no json. That is why
  SessionStart reported "Session-continuity: no resumable threads" while the UserPromptSubmit hook
  listed two. Ledgerizing through the MCP would have written into an empty parallel store and would NOT
  have closed this thread. Routed to the v1 `session-handoff` writer instead — the write-side pair of
  the `/resume-project` this session entered on.
- No code was attempted, so nothing failed in the build. Mitosis was correctly not dispatched.

## Verification
- DoD audit dispatched to `codebase-analyst` against main (096b3c3), read-only, one criterion at a
  time with `path:line` evidence demanded per verdict: ALL 9 MET, BLOCKERS none. Highlights —
  crit 4 parity: `lib/features/entry_cards/playback/video_playback.dart:3-25` vs
  `audio_playback.dart:1-13`, video is a strict superset (seek/positionStream/duration/completed all
  present). crit 5: `LruVideoSlots` cap 6 at `video_slots.dart:11,:44-92`, gated at
  `video_body.dart:130-152`. crit 7: the macOS pointer path IS covered by a defaultTargetPlatform
  override — `useTargetPlatform(TargetPlatform.macOS)` = `TargetPlatformVariant.only(...)` setting
  `debugDefaultTargetPlatformOverride`, at `test/features/entry_cards/support/video_card_harness.dart:145-146`
  and `video_controls_overlay_test.dart:148-218`. crit 9: both red-before-green receipts trace to
  commit `952017e` ("All three fail on HEAD"), surviving as `video_body_test.dart:370-406` (defect a)
  and `:408-463` (defect b).
- Explainer claims verified against main rather than trusted from the spec:
  `git show main:lib/features/today/today_entry_feed.dart` — the feed IS a non-lazy `Column` with a
  spread `for` loop at `:59-63`, so every card builds today.
  `git show main:lib/features/today/today_screen.dart` — `SingleChildScrollView` in BOTH branches
  (`:39` stacked, `:44` withRail), no bounded ancestor; `main` is a 5-child `Column` at `:25`.
  `git show main:lib/data/journal/entries_dao.dart | grep 'limit('` — NONE. Both watch methods stream
  every matching row. The spec's pagination claim holds.
- `sed -n '110,114p'` on the spec — `:112` lands exactly on the Phase 3 header, confirming the session-02
  line pointers are WORKING-TREE-relative (this branch carries the amendment; main does not, and the
  hunks shift ~2 lines). Read them from the working tree, never via `git show main:`.

## Running state
- none. No background shells, no workflows, no parked mitosis runs.

## Deferred + open
- BRANCH HAZARD, highest priority: `chore/ledger-handoff-session-07` is pushed but UNMERGED to main and
  now carries the session-06/07 ledger trail, the spec amendment (2a383bf), this closure, and this log.
  If it never merges, a fresh session resuming from main sees a STALE ledger with this thread still
  `paused`. Open a PR and merge it before starting the fresh thread. `chore:` satisfies pr-title-lint.
- Criterion 8 carries one observational gap the audit surfaced and it is recorded rather than buried:
  runtime keyboard-press assertions exist for the scrubber (`video_body_test.dart:194-214`) and the
  retry button (`media_placeholders_test.dart:71-76`), but NOT for the play/pause transport or the mute
  toggle — their keyboard reachability rests on code inspection (`FocusableActionDetector` +
  `Semantics`) rather than a `sendKeyEvent` test. Judged not a blocker: the criterion asks for keyboard
  reachability with a Semantics label, and both are structurally present. Cheap follow-up if wanted.
- MSP 3 was never validated locally: `fullValidationCmd` was not run against the PR head. Carried
  unresolved into closure by explicit acceptance, not by oversight. The user's manual hardware pass
  covers user-visible behavior, not the automated suite.
- Refinement on the spec's own cacheExtent estimate, worth having if Phase 3 is ever revisited: the
  ~3-4-cards figure assumes ~500px cards, but the preview sizes 21:9 from WIDTH with a 200px floor and
  no cap, so a NARROW window yields ~200px cards and ~7 alive in 1400px of built content. Post-Phase-1
  that is moot for decoders (slots are consumed only on intent) and bears purely on widget-count cost —
  but the narrow-window case is where a profile would be likeliest to show something, and it is the
  case the spec's estimate did not cover.
- Sibling thread `post-ship-hardening` remains PAUSED: integration tests write into the real journal
  container (`integration_test/capture_save_persist_test.dart:47`), and export-ZIP extensions unconfirmed.
  With this thread closed it is the only non-terminal thread; a fresh thread next session makes two.
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target). `video_body.dart`
  controller extraction still out of scope.
- pr-title-lint will fail on every future mitosis PR in this repo (engine hardcodes `mitosis: <msp-id>`).

## Pick up here
This thread is CLOSED — do not reopen it; reopening creates a NEW thread referencing this one. The user
has stated the next session opens a FRESH thread. Before that: merge `chore/ledger-handoff-session-07`
to main, or the fresh session starts from a stale ledger. Then decide whether `post-ship-hardening` is
resumed or stays parked, so the fresh thread does not silently become the second WIP item.

## Demoted from PROJECT.md (80-line cap)
Demoted verbatim to make room for the MSP 4 decision index line and the ledger-store constraint. Both
are historical; the 31/31 SHA is stale (main is now 096b3c3):
- `DB round-trip proof and the GeneratedPluginRegistrant conflict-file note — demoted verbatim to
  sessions/2026-07-25-03-video-card-playback-controls.md (cap enforcement). Both historical now that
  31/31 shipped.`
- `31/31 SHIPPED: all v1 MSPs merged (origin/main 54b81a2). shell-nav-integration (#31) was built via a
  delegated implementer on origin/main and human-merged. App is code-complete (main.dart runnable; no
  stray TODOs; only the inert v2 sync placeholder). Local main reconciled. Remaining work is the LOCAL
  RUN phase (macOS build/run for testing), not more MSPs.`
