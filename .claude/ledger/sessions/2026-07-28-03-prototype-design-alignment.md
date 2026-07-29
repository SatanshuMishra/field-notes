# Session 2026-07-28-03 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief's next step was the §5.4 macOS visual pass, Cluster B's last gate. The user ran it and reported "everything looks as expected", then directed: new dedicated branch off `main`, proceed to Cluster C, think hard.

Two drifts flagged at resume: the thread's `branch: main` was stale (work sat unpushed on `chore/ledger-handoff-session-16`), and `e8ffdc1` was not an ancestor of `main` despite carrying an accepted decision record.

## What shipped
**The §5.4 visual pass PASSED — Cluster B is fully closed, gate and all.** That was the only thing Cluster B had left.

**The Cluster C execution slice is cut and merged.** `docs/specs/2026-07-28-prototype-alignment-cluster-c.md`, 648 lines, shipped as PR #71 (`93c6865`). `main` moved `f804e97 -> 93c6865`.

- Branch `feat/cluster-c-today-centre` cut from `main` at `f804e97`. `e8ffdc1` was cherry-picked onto it as `3842948` so the orphaned `decisions/2026-07-28-stacked-msps-ship-sequentially.md` and its PROJECT.md index line were not lost when branching off a `main` that lacked them.
- The slice mirrors the Cluster B slice's shape: verified base-state token table, hard scope fence, SERIALIZATION section, §5.5 plan scope-guard rule, verbatim non-negotiables, verbatim C1–C7 bodies.

**Mandated stranded-artifact check, done and clean.** `refs/mitosis/*` holds only `02c68b83` (Cluster A), `55d6da7a` (Cluster B), `5385f00d` (the original 31-MSP build run) and `da41a247` (the video thread). **No C1–C7 artifact exists anywhere**, local or remote. Cluster C genuinely needs fresh work — unlike Cluster B, where two finished MSPs were sitting on a checkpoint ref.

**Three parent-spec file-list defects found by audit and corrected in the slice.** Each would have stopped or misled an implementer mid-MSP:

| Defect | Reality | Slice resolution |
|---|---|---|
| C1's `margin-bottom` listed as `streak_card.dart`'s | The 12px gap lives in the consumer, `sidebar_shell.dart:130` — a file Cluster B closed | One-line carve-out in the fence; C1 may change that literal and nothing else in that file |
| C6 described as only gaining a `headline` slot | `padding` and `borderColor` are already params with defaults, shared by **nine** call sites | C6 binds to applying values at the Today call site; changing a default is a defect |
| C7 told to route the hatch through the A5 primitive | `NeutralMediaPlaceholder` (`media_placeholders.dart:140-145`) forwards only width/height/borderRadius — no variant, no colours | C7 composes `CrossHatchPlaceholder` directly in `video_body.dart`; `media_placeholders.dart` untouched |

**A third citation defect in this spec family, verified at source.** The parent's §3.3 video-tile row cites `:127-129`. `:127` is the `<sc-if value="{{ e.isVideo }}">` guard; the styled elements are at `:128-130`, exactly as C7's MSP body already said. The findings table was wrong and the MSP body was right. Corrected in the slice's §3 and recorded in its §7. Every C7 target value was then read at its line and confirmed.

**Four other slice-time resolutions**, each decided once so seven implementers do not each invent an answer:
- `CrossHatchVariant.video` is already 6px band / 12px pitch at 45° — an exact match for `:128`. **C7 needs no primitive change**, only the two colour overrides. Extending the variant enum is a defect.
- `FlowerBloom` has no `opacity` param; C3 wraps in `Opacity` at the call site rather than changing the primitive.
- `StickerCard`'s `border` is hardcoded to `Shapes.outline` (`sticker_card.dart:30`) — which already equals the 1.5px ink every consumer targets. No MSP edits it; editing it restyles every card in the app at once.
- `IconStickerGlyph` has only `{gear, soundOn, soundOff}`; C4 adds `edit` and `trash` additively, so `icon_sticker_button.dart` joins C4's fence.

**Cluster C has genuine parallelism**, unlike Cluster B. Computed file-overlap matrix: only `mood_banner.dart` (C2+C3) and `entry_card.dart` (C4+C5) are shared, plus a C5->C7 contract edge on `MediaImage`. Waves: **1 = C1, C2, C4, C6** (pairwise disjoint); **2 = C3, C5**; **3 = C7**.

**Two undeclared consumers named as verify-only**: `mood_banner_for_date.dart:61` constructs the `MoodBanner` C2/C3 restyle, and `day_detail_entry_tile.dart:29` is the **only** call site passing `onEdit`/`onDelete` — so Day Detail is the sole surface where C4's restyled controls are observable.

## Tried and failed
- **`git checkout -b` was refused** because an uncommitted one-line ledger edit (the stale `branch:` field) would have been overwritten. Reverted the edit with the Edit tool rather than stashing or `git checkout --`, then branched. No stash was created and nothing was discarded.
- **The `pr-create` tool is NOT at the repo-relative path the global rule states.** `.claude/lib/superpowers-parallel/mitosis-git.mjs` does not exist in this repo; the tool lives at `~/.claude/lib/superpowers-parallel/mitosis-git.mjs` and the first invocation died with `MODULE_NOT_FOUND`. Use the absolute home path in this project.

## Verification
- `fullValidationCmd` verbatim on `feat/cluster-c-today-centre` at `3842948`: **902 passed, 0 failed, `flutter analyze` clean, exit 0.** This is the green baseline Cluster C starts from and matches the figure the previous session recorded.
- Prototype citation `:128-130` re-read at source in `docs/prototype/project/Field Notes.dc.html`; all four C7 target values (hatch, container, badge, chip) confirmed character-for-character.
- Every token, typography role and primitive C1–C7 consume was audited present on base at value — 10 palette, 5 shapes, 4 shadows, 14 typography roles, 6 primitives. Nothing absent, no hard value mismatch, so the "no MSP may add a token" rule is not tripped.
- The 106-case playback suite was independently re-counted per file and confirmed at 106 across the eight named files. `video_player_impl_test.dart` (1 test) is a sibling and is **not** part of the canonical 106 — including it sums to 107.
- **NOT VERIFIED: the four `integration_test/` flows.** `fullValidationCmd` still excludes them and they have still never been run.

## Running state
none. Both `codebase-analyst` dispatches returned; the backgrounded validation exited 0. Nothing in flight.

## Deferred + open
- **Cluster C execution has NOT started.** No C-series code exists. Wave 1 is the next action.
- **PR #70 merged this session** (`38c2826`), fixing the settings sync-row overflow at 440px width. Chip `task_31a15276` is CLOSED and that risk is retired from the thread.
- **`feat/cluster-c-today-centre` and `chore/ledger-handoff-session-16` are both superseded** — the first squash-merged as #71, the second's only commit was cherry-picked into it. Not deleted; branch deletion needs explicit confirmation.
- A stale `stash@{0}` ("WIP on feat/b4-rail-footer-state") still holds only codegen churn #67 superseded. Two older stashes below it are from the original 31-MSP run. Droppable; left because stash drops need confirmation.
- Standing and unchanged: `receipts.yml` runs unpinned third-party `shaheershoaib/receipts/enforcer@main` (chip `task_e10f4f7e`); A2/A4's app-wide blast radius never walked; the five A3 dialogs never separately opened; OQ-3 and OQ-6 open.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.

## Pick up here
Dispatch **Wave 1 — C1, C2, C4, C6** as four parallel `implementer` agents, one per MSP, each in its own worktree, each scoped to its fence rows in the slice's §0 table. Per the decision recorded this session, **do not dispatch mitosis for this cluster.** Ship one PR per MSP through the centralized `pr-create` tool at `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`, run `fullValidationCmd` locally against each head before asking for a merge, and rebase `--onto main` plus revalidate between merges. Then Wave 2 (C3 after C2, C5 after C4), then Wave 3 (C7).
