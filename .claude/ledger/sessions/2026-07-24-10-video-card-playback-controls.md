# Session 2026-07-24-10 — video-card-playback-controls

## Where it started
Resumed on the explicit slug. Verified first: branch `fix/video-card-preview-and-controls` clean at
`f732a0c`, `origin/main` still `5cb5bad`, all nine thread pointers on disk — ledger and repo agreed. The
user said "Go", meaning build the decoder gating the thread had sequenced first. Ended early on an explicit
hand-off instruction with the last round of review fixes specified but NOT applied.

## What shipped
Eleven commits, `36eb533..1bbeef7`. Branch is now 23 commits and 38 files ahead of `origin/main`
(+4985/-243). `origin/main` never moved; no rebase was needed.

- `36eb533` / `55aab51` / `dc113b0` — the decoder-slot registry.
  `lib/features/entry_cards/playback/video_slots.dart` plus `video_slots_provider.dart`
  (`@Riverpod(keepAlive: true)` + `ref.onDispose`, following `sound_providers.dart:19-24`). Hard-capped LRU,
  pin-while-playing, coalesced slot-freed notification, `holds()`, drain-on-dispose. Cap is the named
  `assumedConcurrentVideoDecoderCap = 6` — the honesty about that number lives in the decision record, not
  in a comment.
- `32d0b1f` / `3974338` — the card phase machine. Five phases (waiting, preparing, ready, retrying,
  unavailable) in `cards/video_body.dart`. `_prepare()`'s `initState` trigger is UNCHANGED, which is the
  whole reason gating was sequenced before the overlay. 8s load timeout, two bounded retries, no jitter (the
  cap already serialises retries by making each re-acquire a slot, so jitter only cost test determinism).
  `CorruptMediaPlaceholder` gained an optional `onRetry`. `VideoBody` takes a required non-nullable
  `VideoSlots` so the compiler, not a test, guarantees capping.
- `c6f04d7` — `acquire({required onEvicted, required evictionRights})` with
  `enum VideoSlotEvictionRights { none, evictUnpinned }`, explicit at all call sites;
  `addSlotFreedListener` now returns `bool`.
- `4577bd6` / `8645c0d` / `4f421f6` / `bb6c095` / `b370ee6` / `1bbeef7` — remediation of the first review
  round: generation guard, lock-state deferral, non-evicting passive acquire, symmetric resolver re-prepare
  across both cards, `VideoTransport` extracted to `cards/video_transport.dart` (pure move), and
  playback-error recovery given eviction rights.

Test count went 764 -> 825. New files: `test/features/entry_cards/playback/video_slots_test.dart`,
`test/features/entry_cards/cards/video_body_lifecycle_test.dart`,
`test/features/entry_cards/support/video_card_harness.dart`.

## Tried and failed
- **Two CRITICALs shipped into a green suite and were caught only by review.** (1) No generation guard across
  `await player.load(...)`: eviction during load is the DEFAULT past the cap because a `preparing` card is
  unpinned and therefore the LRU victim. The success branch set `ready` with a null player and null token — a
  visibly enabled play button that did nothing forever — and the failure branch released the NEXT attempt's
  token and disposed the NEXT attempt's player, charging retries until it hit red with nothing corrupt.
  (2) Releasing a slot from `dispose()` drove a sibling's `setState` inside `BuildOwner.lockState`; because
  `setState` runs its callback before `markNeedsBuild`, the phase mutated with no rebuild scheduled, the throw
  escaped into an `unawaited` future as an uncaught zone error, and the card held a slot in a dead `preparing`
  state with no player — permanently shrinking the pool. Assert-gated, so debug-only, which means it would
  have fired on the `flutter run -d macos` hardware run specifically.
- **Both were invisible because every receipt drove ONE card at `cap: 1` against a synthetic pinned
  occupant.** The production path — N unpinned holders, an N+1th mounting, evictions landing mid-load — had
  zero coverage. This is the most transferable lesson of the session: the suite was green, thorough-looking,
  and structurally blind.
- **Three vacuous tests, each caught by mutation rather than by reading.** A "release clears the pin" test
  that provably could not fail (tokens are single-use, so a leaked pin has no observable consequence); a
  dispose receipt that built a fresh resolver per `pumpWidget`, so the new re-prepare promoted the sibling and
  the receipt passed with the fix reverted; and `'three cards contending for two slots'`, whose one assertion
  evaluates `false && true` for the waiting card, unfalsifiable under any implementation.
- **Four of my own instructions were wrong and the agents were right to refuse them.** "Run exactly one more
  notification pass" contradicted the at-least-once property I asked for in the same sentence. The corruption
  discriminator could not run pre-`acquire` without reddening two untouchable receipts whose fixtures point at
  a nonexistent file. "`required VideoSlots` plus never edit the receipts" was flatly impossible. And
  "terminal with a visible affordance" for a disposed registry was unachievable because the only
  affordance-bearing placeholder is the red one this branch exists to stop showing.
- The code reviewer's mechanism for the scrubber drag latch was wrong — `GestureDetector` disposes the
  recogniser so `_endDrag` is never called at all — but the symptom was real and there was a SECOND latch in
  `_VideoScrubberState._dragPosition`. Both fixed.
- No hardware verification was attempted. Nothing in this session is confirmed on real macOS.

## Verification
- `flutter analyze` — expected `No issues found!`; observed clean at every commit boundary and at `1bbeef7`.
- `flutter test` — 764 baseline -> 781 -> 789 -> 804 -> 824 -> 825, every delta reconciled explicitly against
  the previous count rather than merely reported. Re-verified independently at hand-off.
- Mutation checks were mandated and run on every load-bearing receipt: the registry's reentrancy guard, its
  victim-scan `_granting` guard, `pin` neutrality, cap-denial-vs-red, the zero-retry corruption
  discriminator, never-red-on-eviction, the generation guard, the lock-state deferral, and the recovery
  eviction rights. Each reverted mutation reddened exactly the intended test and nothing else.
- The three pre-existing defect receipts were confirmed byte-identical by BLOB HASH (not by diff) at both
  `3974338` and HEAD, and green: `video_body_test.dart` = `4a16235...`,
  `media_image_test.dart` = `dc1c59e...`. The only edit either file ever took was six identical
  `slots: const UnlimitedVideoSlots(),` argument lines forced by the required parameter.
- `git fetch` + `git rev-parse origin/main` — expected `5cb5bad`; observed `5cb5bad`.

## Running state
- none. The remediation agent (`a80745066c0b48ce5`) was stopped at the hand-off instruction BEFORE it wrote
  any code — `git status` showed only ledger files dirty. HEAD `1bbeef7` is clean and green. Nothing to
  reconcile.

## Deferred + open

### The exact fix list the next session should apply (from the scoped re-review of `3974338..1bbeef7`, verdict APPROVE-WITH-FIXES)

MEDIUM, all in `lib/features/entry_cards/cards/video_body.dart`:
1. `:156-157` — `await _resumeIfInterrupted();` and `await _playIfRequested();` are consecutive with no
   `_isCurrentAttempt(gen, token)` between them. `_resumeIfInterrupted` -> `_seek` -> `await player.seek(...)`
   spans a real event-loop turn whenever `_resumeFrom > 0`, i.e. exactly the evicted-and-reclaimed path.
   Compounds with `dispose()` (`:546-559`) NOT routing through `_teardownPlayer()` — unlike
   `voice_body.dart:176` — so `_player` is never nulled and `_playWhenReady` never cleared, and `_play()`
   runs against a disposed controller, surviving only because a broad `try/catch` swallows it. Worse symptom
   with no dispose involved: if `_recoverFromPlaybackError` fires during the seek await, `_playIfRequested`
   BURNS `_playWhenReady` against a null player, so the retry that succeeds 400ms later does not play the
   video the user asked for. Silent loss of user intent — receipt this one.
2. `:372-395` — `_recoverFromPlaybackError` is generation-blind. Fine for the two stream `onError` callers
   (subscriptions die at teardown) but NOT for the `_toggle` (`:524`) and `_play` (`:542`) catch blocks, which
   hold a player captured before their await. A stale rejection landing while a new attempt sits in
   `preparing` passes the phase check and runs `_releasePlayerAndSlot()` on the LIVE attempt. Same defect
   class as the fixed CRITICAL, reached on the interaction path. Fix: `_onPlaybackFailure` captures
   `_generation`/`_token`; recovery checks `_isCurrentAttempt` as well as phase.
3. `:471-495` + `:119-158` — mute is not re-applied after a reload, so the control LIES: mute, get evicted,
   and the new player is at full volume while the toggle paints struck-through and announces "Unmute video"
   over audible sound. Re-apply `setVolume(_volume)` after `_enterPhase(ready)` when `_volume != _fullVolume`;
   gate `_toggleMute`'s continuation (`:486`) on `_isCurrentAttempt`, not just `mounted`.
4. `test/features/entry_cards/cards/video_body_lifecycle_test.dart:18-63` — the vacuous receipt described
   above. Keep it as the non-evicting-acquire receipt but assert per-card state directly (card 0
   ready-and-mounted, card 2 neither, `built hasLength(2)`) and rename it to what it proves. Real
   stale-attempt coverage is at `:65` and `:108`, both confirmed red-before-fix.

LOW:
5. `video_body.dart:76-83` — `didUpdateWidget` compares only `resolver` identity, so a same-key widget whose
   `entry.mediaId` changed keeps playing the old file.
6. `video_body.dart:82` — `_restart(none)` releases then re-acquires across an `await resolve()` gap, so a
   sibling's freed-slot microtask can demote a card that was ready to `waiting`. Re-acquire before releasing,
   or pass `evictUnpinned` when the card held a slot.
7. `video_body.dart:497-507` — `build` gates `onTap` on `_ready || _canClaimSlot` but `_onTransportTap`
   re-evaluates at call time, so a same-frame second tap falls through to `_toggle()` while `preparing`.
   Guard the head.
8. `cards/video_scrubber.dart:71-76` — `_dragPosition` clears on `onSeek == null` but the recognisers gate on
   `_enabled` (`onSeek != null && _total != null`). If `total` goes null while `onSeek` stays non-null the
   latch survives. Clear on `!_enabled`.
9. `cards/video_transport.dart:52` + `video_body.dart:498-504` — a denied explicit claim is a silent no-op
   while the control announces `'Play video'` and is `enabled: true`. Give it an announced signal; this also
   retires the two tests currently codifying an enabled-but-dead toggle
   (`video_body_lifecycle_test.dart:251`, `video_body_slots_test.dart:130`).
10. `cards/voice_body.dart:46-57` — the re-prepare tears down unconditionally, discarding in-progress
    playback on a card with no Try again. Skip when already `_ready` with an unchanged `mediaId`. Matters more
    than it looks: `todayMediaResolver` (`today_providers.dart:29`) returns a FRESH `MediaStoreResolver` per
    computation, so any future invalidation of `mediaStoreProvider` would restart every mounted player. Not
    reachable today.
11. `video_body.dart:44` — revert `retryBackoff` from `Iterable<Duration>` back to `List<Duration>` with an
    unmodifiable default. My instruction offered "Iterable OR an unmodifiable copy" and the Iterable half was
    wrong: `.length` (`:206`) and `.elementAt` (`:223`) are now O(n) and re-evaluate a lazy generator.

### Still open beyond that
- **The hover-reveal overlay is NOT built** — spec receipts 3, 4, 5 unwritten. Controls are unconditionally
  visible. Build it in ITS OWN FILE, not inside `video_body.dart` (615 lines already): the spec's model is a
  shared gesture layer with only the hover layer additive, which fits a separate widget. It must absorb one
  new obligation the retry work created — controls-enabled can now go true -> false, and when it does the
  overlay must force the always-visible state and cancel the hide timer.
- `defaultTargetPlatform` reports `android` in ALL widget tests; without `debugDefaultTargetPlatformOverride`
  the macOS pointer path is silently untested.
- **Controller-extraction seam, deliberately deferred.** Lifting the token/attempt/timer/player lifecycle out
  of `video_body.dart` into a plain non-widget controller is where both CRITICALs lived and would make that
  lifecycle unit-testable without a widget tree. Not done because the behaviour is now covered by receipts and
  a large refactor before any hardware confirmation adds risk without adding information.
- LOW 11's probe-exception branch has NO test and is unreachable on macOS: `existsSync()` never throws for
  directories, over-long paths or empty paths, and the cases where `lengthSync()` throws are short-circuited
  by `!existsSync()`. A FIFO gives exists-true/length-zero, which is definitely-empty rather than an
  exception. Do not manufacture a probe seam for it.
- `video_body.dart` is 615 lines — inside the 800 ceiling, over the 200-400 target.
- Viewport-aware allocation still deferred; it is a clean later addition as a priority input to the registry.
- Everything from session 09 that is still open: blob backfill has not run against the live container
  (restore point `/Users/satanshumishra/field-notes-container-backup-2026-07-24`); export-ZIP extensions
  unconfirmed; integration tests still write into the real journal container; two junk voice entries pending
  human in-app deletion; merged branch `fix/media-blob-extension-playback` not pruned. Sibling thread
  `post-ship-hardening` remains paused.
- A background task chip was spawned for two stale committed generated files
  (`lib/features/settings/settings_providers.g.dart`, `lib/state/media_provider.g.dart`) whose source hashes
  `build_runner` rewrites on any unrelated run. Not started.

## Demoted from the decision records (cap enforcement, content preserved verbatim)

From `decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md`, the full "Why" section:

- Retryability is UNREADABLE from the error. macOS never reads `error.code` (FVPVideoPlayer.m:380-401, so
  AVError -11839 never reaches Dart); Android passes `details: null` (ExoPlayerEventListener.java:131-137,
  dropping media3's errorCode). Worse, `initialize()` has no timeout (video_player.dart:698) and
  `AVPlayerItemStatusUnknown` is a no-op, so exhaustion may STALL rather than throw — the likeliest
  presentation is the one error-matching would miss. Never string-match a localized message.
- Interaction gating cannot meet criterion 1: the macOS recorder writes no thumbnail
  (camera_video_recorder.dart:345, vs its non-macOS sibling at :77), so poster slot 1 is dead on macOS forever.
- Slivers are a primary-screen restructure: macOS Today is `withRail` inside a `SingleChildScrollView`
  (today_layout.dart:8, today_screen.dart:44-57); `cacheExtent` bounds only softly (~5-7) and `FadeIn` replays.
- Cap 6 is OUR design choice, not a platform fact — no published concurrent-decode number exists (-11839
  proves the pool is bounded but names no size) [unverified]. Same honesty as the spec's 3s.
- `dispose()` awaits `_creatingCompleter`, not `initializingCompleter` (video_player.dart:708), so the timeout
  path reclaims a slot without deadlocking. A retry must build a NEW player: dispose closes the stream
  controllers (video_player_impl.dart:131-136), so both streams re-subscribe per attempt.
- `visibility_detector` rejected on maintenance state (0.4.0+2, ~3 years stale, open sliver/null-check crash
  issues), not on resolvability — it does resolve on this SDK.

From `decisions/2026-07-24-non-evicting-acquire-for-passive-mount.md`, the full Context:

`LruVideoSlots.acquire` evicts the LRU unpinned holder and only denies when every holder is pinned. Code
review found two consequences of giving that power to passive card mount. (1) A wake/evict STAMPEDE: every
card that has ever waited keeps a slot-freed listener, so one `release` runs one pass in which the first
waiter takes the free slot and every subsequent waiter EVICTS a healthy unpinned holder, which enters
`waiting`, re-registers, and repeats on the next release — on a 20-video day one failed load cascades into
~14 player create/dispose cycles, ~13 healthy cards flashing to neutral, and ~13 fresh mid-load eviction
windows. (2) First-paint inversion: in a non-lazy feed every card mounts before any eviction, so the LAST
`cap` cards keep slots and the TOP-of-feed cards — the ones on screen — fall back to neutral.

From `decisions/2026-07-24-playback-recovery-counts-as-interactive.md`, the full Why:

Without rights, a transient decoder error on the video being WATCHED drops it to a neutral placeholder while
cards the user is not watching keep their decoders. The stampede that motivated non-evicting passive acquire
does not transfer: that was one pass over every waiting card per release, whereas a mid-playback error is
singular, and the retry budget plus reset-on-`ready` already bound the churn. Receipt: at a full cap, a
mid-playback error on a playing card reclaims a slot from an unpinned sibling and resumes from the last
position rather than degrading to neutral. Mutation-verified — reverting the single rights argument reds
exactly that receipt and nothing else.

## Demoted from the thread spine (cap enforcement, content preserved verbatim)

- EVICTION ORDER IS INVERTED FOR FIRST PAINT (now fixed by the non-evicting-acquire decision, retained
  because the mechanism explains why the fix exists): `acquire` evicts the LRU unpinned holder; denial happens
  only when every holder is pinned. In a non-lazy feed all cards mount before any eviction, so on a day with
  more videos than the cap the LAST `cap` cards keep their slots and the TOP-of-feed cards — the ones on
  screen — fall back to neutral. Not red, and tap-recoverable, so the defect this branch targets stays fixed.
- PRE-EXISTING RED LATCH, resolver race (fixed this session in `4f421f6`, retained for the mechanism):
  `today_entry_feed.dart:54-55` falls back to `_PendingMediaResolver` (reports every id missing) on any frame
  where entries have arrived but `todayMediaResolverProvider` has not resolved. `VideoBody`/`VoiceBody`
  `_prepare()` once from `initState` and never reacted to a changed `resolver`, so a card mounted on that
  frame latched red PERMANENTLY, violating criterion 3. The feed receipt had been reshaped to emit a text
  entry and `pumpAndSettle()` before the video entry, which dodged the path — the suite documented the
  workaround instead of the defect. Both the defect and the receipt are now fixed.
- Non-null-but-unresolvable `thumbnailMediaId` still renders red over a playable video (unreachable today,
  nothing writes it).

## Pick up here
Apply the eleven fixes above — they are fully specified, so no re-derivation is needed. Stage the behaviour
fixes separately from the test-integrity fix, red-first per fix, and mutation-check item 3 (the mute lie)
since it is the most user-visible. Then build the hover-reveal overlay in its own file against spec receipts
3-5. Only then hand the branch to the human for `flutter run -d macos` — never the raw binary — to confirm
the preview frame, the controls, and that a day with more videos than the cap degrades to neutral rather than
red. Do NOT open another review round on `video_body.dart`; severity went CRITICAL -> CRITICAL -> MEDIUM and
the remaining items are all specified.
