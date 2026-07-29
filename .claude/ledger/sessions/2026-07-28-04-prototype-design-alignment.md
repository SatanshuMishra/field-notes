# Session 2026-07-28-04 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief showed the Cluster C slice merged (#71, `93c6865`) with zero C-series code written. The user said "Go. Think hard." — dispatch Wave 1.

Two drifts flagged at resume: the thread's `branch: main` was stale, and session 03's whole ledger — including `decisions/2026-07-28-cluster-c-skips-mitosis.md`, the record governing THIS cluster's execution model — sat unmerged on `chore/ledger-handoff-session-17` with no open PR. Same orphaning shape that bit `e8ffdc1` the session before.

## What shipped

**Cluster C execution started. All four Wave 1 MSPs are implemented, green and pushed; none is merged.**

Worktree root `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-c/`, four worktrees, all cut from `main` at `93c6865`. Wave 1's file sets were re-derived before dispatch rather than taken on the slice's word — genuinely pairwise disjoint for `lib/`, but NOT for tests (see Deferred).

| MSP | Branch | Head | State |
|---|---|---|---|
| C1 streak card | `msp-cluster-c/c1-streak-card` | `a0904d3` | validated, **PR #74 open** |
| C2 header + mood set | `msp-cluster-c/c2-header-mood-set` | `b02c842` | complete, unvalidated, no PR |
| C4 eyebrow + card header | `msp-cluster-c/c4-eyebrow-card-header` | `6938034` | complete, unvalidated, no PR |
| C6 feed empty state | `msp-cluster-c/c6-feed-empty-state` | `179e4b8` | complete, unvalidated, no PR |

Only the frontmost MSP gets an open PR (decisions/2026-07-28-stacked-msps-ship-sequentially.md). C2, C4 and C6 wait for #74 to merge, then rebase `--onto main` and re-run `fullValidationCmd` on the new base. Their current greens are NOT transferable.

**PR #73 opened for the orphaned ledger branch** (`db6b30e` + `5d35247`), landing the cluster-c-skips-mitosis decision record on `main`. Ledger markdown only, zero code. Needs a human merge.

**One decision recorded: `decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md`.** Three of four MSPs independently stopped on the same shape — a mandated rendering change reds an assertion in a test file their fence row omits. Ruling: retargeting an existing assertion is maintenance of a receipt, not a new test; a fence row omitting such a file is a spec defect. N24's playback files are carved out and stay untouchable.

**A third `today_screen.dart` carve-out granted to C2** (lines 29-30 only): the short header date and the banner's `margin-top: 16` both physically live in C4's file, so C2's acceptance criteria were unmeetable inside its own fence. Same shape as §0's C1 `sidebar_shell.dart:130` carve-out, missed by the slice audit.

## Slice defects found this session, none previously known

1. **The recorded 902 baseline is STALE — `main` is 903.** PR #70 (`38c2826`) added test cases and landed AFTER the 902 figure was measured at `3842948`; `git merge-base --is-ancestor 38c2826 3842948` is false. C1's diff adds no test case (24 cases before and after), so its 903 is a zero delta, not a regression.
2. **Slice §3's "Current app" column is wrong in all three regions C2 touched.** Different defect class from §7's citation errors: the base-state audit verified tokens exist at value but never verified what the call sites currently USE. Cited:
   - §3 slice line `:272` greeting — claims `eyebrowAccent` Caveat 20 w600 sage; actually `pageEyebrowAccent` Caveat 16 w600 coral, **already at target** (`today_header.dart:20` -> `typography.dart:118-123`). The greeting needed no edit at all.
   - §3 slice line `:273` long date — claims `displaySerif` 32 **w600** h**1.15**; actually 32 **w500** h**1.0** (`typography.dart:19-25`). Real delta is font size only, 32 -> 34.
   - §3 slice line `:276` change control — **four of seven values wrong** about `StickerButton(secondary)` (`sticker_button.dart:102-109`): fill is `cardWarm` `0xFFF8EFE0` not `cardBright`; radius is 12 (`Shapes.radiusControl`) not 11; shadow is **null**, not `Shadows.button`; padding is 13h/10v not 16h/10v. Outline, type role and copy are correct.
   - §3 `:274` and `:275` (banner copy and surface) were checked and are **accurate on every value**. The other halves of `:272`/`:273` are accurate too.
   None of this changed C2's implementation — it replaced the button wholesale — but a later MSP trusting that column would be misled.
3. **`empty_state_test.dart` has FOUR cases, not the three §5.2 and C6's body claim.** The omitted one is the `DashedBorderPainter` `shouldRepaint` unit test at `:65`. C6's named obligation should be stated against four; all four passed unmodified.
4. **C4's `PHOTO` chip copy is unreachable.** `EntryType` is `{text, voice, video}` (`lib/domain/models/entry_type.dart:1-4`); photos are attachments, not an entry type. C4 renders NOTE/VOICE/VIDEO and flagged it rather than inventing a domain change.
5. **The slice's file-overlap matrix covers only `lib/`, not `test/`.** C2 and C4 both need `test/features/today/today_screen_test.dart`. Handled by sequential shipping, but the matrix understates the coupling.
6. **`Shadows.card = hero`** — `shadows.dart:132` is a direct alias, and `hero` is `Palette.ink20` `0x334A3B2E` at offset (3,3) blur 0, where `0x33` = 51/255 = 0.2. That is why `StickerCard`'s DEFAULT shadow already satisfies the prototype's `3px 3px 0 rgba(74,59,46,.2)` exactly. C1, C2 and C5 all inherit it. `Shadows.button = control` (`shadows.dart:134`) is a second such alias.

**No fourth prototype-citation defect.** Every citation checked at source this session was accurate: C1 `:70-72` + the flame path `:1228` + the `icon()` helper `:1244-1250`; C6 `:145-147` (em dash hexdumped `e2 80 94`); C2 `:89`, `:93-96`, `:1318`, `:1659`; C4 `:107`, `:1666`, `:113-115`, `:1574-1575` + `fmtStamp` `:1316` / `partOfDay` `:1317`. The §7 warning held and the re-verification found nothing — worth knowing the discipline is now clearing.

## Tried and failed
- **My `shouldRepaint` latent-defect inference was wrong.** From C6's phrase "added a `radius` input to `DashedBorderPainter`'s call" I inferred a new painter input uncovered by `shouldRepaint`. C6 disproved it with `git show 93c6865:lib/design/feedback/empty_state.dart`: `radius` already existed and was already compared at `:128`. Its diff only forwards an argument. No code change resulted; no test extension was legitimate.
- No other failed attempt. Nothing was reverted, no stash created, no branch deleted.

## Verification
- `fullValidationCmd` verbatim against C1 head `a0904d3`: **903 passed, 0 failed, `flutter analyze` clean, exit 0.** This is the only full-suite run of the session and the only gate C1's PR rests on. It includes the 106-case playback suite green.
- C4: `flutter analyze` clean; `test/features/entry_cards/ test/design/` = **264 passed**, a run that includes the **106-case playback suite unmodified** (N24 satisfied); `entry_card_test` + `today/` + `day_detail/` + `sidebar_footer_test` = 86 passed. `day_detail_entry_tile_test.dart`, the named regression proof for the Edit/Delete controls, passed in both runs.
- C6: `flutter analyze` clean; `test/design/feedback/ test/features/today/` = 66 passed; `empty_state_test.dart` **4/4 unmodified**, with the painter's `Palette.ink` default assertion as the direct receipt that no default moved; **eight of eight** other `EmptyStatePlaceholder` call sites green by actual test run, none by inspection alone.
- C1: 24/24 on its surface (was 23/1 before the authorized retarget).
- C2 at `b02c842`: `flutter analyze` clean; `test/features/mood/ test/features/today/` = **53 passed**, after seven authorized assertion retargets. The five `on_this_day_card` cases are the proof `longDateLabel`'s year-bearing output did not regress — it is now derived as `'${headerDateLabel(m)}, ${m.toLocal().year}'`, byte-identical for `on_this_day_card.dart:71`. `today_screen_test.dart:64` asserting `find.text('Sunday, July 19')` is the direct proof the header renders undated on the composed screen.
- **NOT run, all still true:** the four `integration_test/` flows (never run on this project, §5.3 gate 3); `fullValidationCmd` against the C2, C4 and C6 heads; the §5.4 macOS visual pass.

## Running state
none. All four Wave 1 subagents reported complete and pushed before hand-off. No background shells, no `flutter run` instance, nothing to kill. All work is durable on the four `msp-cluster-c/*` branches — recover from git, never from an agent transcript.

## Deferred + open
- **Two PRs need a human merge: #73 (ledger) and #74 (C1).** Nothing else can proceed past C1 until #74 lands.
- **C2 and C4 both edit `lib/features/today/today_screen.dart` and `test/features/today/today_screen_test.dart`.** C2's production diff there is exactly 4 lines (`+4/-4`, its granted `:29-30` carve-out); it reports leaving `:32`'s `SizedBox(height: 20)` and the eyebrow region untouched, and C4 reports confining itself to the eyebrow. A clean rebase is expected but **was not proven** — neither branch has been rebased onto the other. Whichever ships second must resolve and revalidate.
- Wave 2 is C3 (after C2) and C5 (after C4); Wave 3 is C7 (after C5). No Wave 2 or 3 work started.
- The six slice defects above should be folded back into the slice document, or recorded in its §7, before Wave 2 dispatch. Do NOT edit a spec mid-run without deciding that deliberately.
- C4's two judgment calls, unreviewed: the Edit/Delete finders now match on `IconStickerButton.semanticLabel` via `find.byWidgetPredicate` against new exported constants (`find.bySemanticsLabel` rejected — it throws without `tester.ensureSemantics()`); and `TodayFeedEyebrow` deliberately renders nothing over a load failure rather than asserting `today · 0 logs` next to the feed's error message.
- Standing and unchanged: `receipts.yml` runs unpinned third-party `shaheershoaib/receipts/enforcer@main` (chip `task_e10f4f7e`); A2/A4's app-wide blast radius never walked; the five A3 dialogs never separately opened; OQ-3 and OQ-6 open; `feat/cluster-c-today-centre` and `chore/ledger-handoff-session-16` superseded but not deleted; three stale stashes.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.

## Pick up here
Merge #73 and #74. Then run the ship loop once per remaining MSP, one at a time, never two PRs open: rebase the branch `git rebase --onto main <prev-tip>`, re-run `fullValidationCmd` verbatim against the new head (expect 903+ passing, 0 failing, analyze clean), open one PR via `~/.claude/lib/superpowers-parallel/mitosis-git.mjs pr-create` (the absolute home path — the repo-relative path in the global rule does not exist), and wait for the human merge before starting the next. All three are ready now: C2 `b02c842`, C4 `6938034`, C6 `179e4b8`; suggested order C4 -> C2 -> C6, since C4 and C2 share `today_screen.dart` and C6 is disjoint from both. Only then dispatch Wave 2 — C3 on the merged C2, C5 on the merged C4.
