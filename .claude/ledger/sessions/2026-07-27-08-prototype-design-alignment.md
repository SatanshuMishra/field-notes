# Session 2026-07-27-08 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief's stated next step ("merge PR #58") was already done — a fetch showed `origin/main` at `cc23953`, two commits past the ledger's `488b48a`: `6301fde` (#58, the `edited` trigger) and `cc23953` (#59, the session-12 ledger handoff). Nothing was stranded. User directed "Go. Think hard."

## What shipped
- **The Cluster B execution slice** — `docs/specs/2026-07-27-prototype-alignment-cluster-b.md`, 4 MSPs (B1–B4), cut from the parent spec using the Cluster A slice as the reference shape. **Merged as PR #60; main is `b4c5634`.**
- **Local `main` reconciled twice** — `488b48a` -> `cc23953` before the work, `cc23953` -> `b4c5634` after #60 merged. Required before any dispatch: the engine cuts worktrees from the bare LOCAL `main` ref (`decisions/2026-07-16-pre-relaunch-main-reconciliation.md`).
- `decisions/2026-07-27-shared-file-cluster-serializes.md`.

Three things the slice carries that Cluster A's did not need:

1. **A SERIALIZATION section.** All four MSPs edit `lib/app/shell/sidebar_shell.dart`. Cluster A's MSPs owned mostly disjoint files, so its slice never had to say this. B3 and B4 both depend on B2 and both rewrite the same widget; the declared chain `B1 -> B2 -> {B3, B4}` is therefore also a file-contention chain, stated as a hard edge rather than left to the engine's graph.
2. **A base-state table (§0).** Every `Palette` / `Shapes` / `Shadows` / `TypographyTokens` symbol B1–B4 consumes was grepped and confirmed present on base, and the token layer is declared CLOSED — no MSP may add, rename or remove a token. Without this an implementer could re-derive an A1 token that already exists.
3. **§5.5, the plan scope-guard rule** from `decisions/2026-07-27-scope-guard-authorship-oracle.md`, written into the slice so the planner reads it instead of rediscovering it. That finding parked A1 through three review iterations and blocked A2/A4/A5.

Scope decisions inside the slice worth knowing:

- **Three rows of the parent's §3.2 table were carved out** — Streak card, Streak text, Streak flame. They sit physically in the rail but are owned by **C1** and edit `lib/features/streak/streak_card.dart`, which the fence forbids. The slice states explicitly that a rail looking unfinished at the streak card after this run is CORRECT, not a defect — the same failure mode as Cluster A's "primitives confirm by regression".
- **The §3.2 table's "No `#6a5c4a` in Palette" / "No `#A3866A` in Palette" cells are now historical.** Both exist after A1 as `Palette.inkSoft` and `Palette.windowTitle`. Rows reproduced verbatim with a note, rather than silently edited.
- **Fence traps named explicitly**: `app_theme.dart` (B1 overrides at the two shells, never at the theme — `app_theme_test.dart:12` must keep passing), `dashed_divider.dart` (already faithful and already parameterised; B2 passes arguments at the call site only), the token layer, `lib/features/**`.
- **The phone chooser is a live preserve item for the first time.** B1 edits `bottom_bar_shell.dart` and B4 edits `app_shell.dart` — the chooser's only reachability path. `test/app/shell/bottom_bar_shell_test.dart:52` is the standing proof and is named in both MSPs' "Must not regress".

## Tried and failed
- **The ledger's stated next step was stale on arrival.** "Merge PR #58" had already happened, along with #59. The resume brief flagged it rather than acting on it. Second session running where a stale `origin/*` ref or an unfetched state was the first thing to resolve — `git fetch` is now the reflex before any divergence claim.
- **No verification of the slice's reproduced line citations beyond three spot-checks.** The slice reproduces roughly 40 `path:line` and `proto:NNNN` citations from the parent spec. Only the three the slice ADDS were opened (`app_theme_test.dart:12`, `bottom_bar_shell_test.dart:52`, `sidebar_shell.dart:28` / `:76-79`). The rest are inherited on the parent's authority, which §7 of that same document says is worth exactly one re-open. That is why §7 is carried into the slice verbatim.
- **`docs/specs/2026-07-26-prototype-design-alignment.md` is 2056 lines and cannot be read whole cheaply.** Approach that worked: `grep -nE '^#{1,4} '` for the heading map first, then targeted `Read offset/limit` on the four ranges that mattered (1–175, 282–302, 551–702, 1904–1935). Cost roughly 35k tokens against ~55k for a full read.

## Verification
- `gh pr view 60` — **MERGED** 2026-07-28T03:49:27Z. `git cat-file -e main:docs/specs/2026-07-27-prototype-alignment-cluster-b.md` — exit 0, the slice IS on main at `b4c5634`.
- Token presence on base — `grep` over `lib/design/tokens/{palette,shapes,shadows,typography}.dart` returned every symbol B1–B4 consumes: `inkSoft`, `windowTitle`, `ink16`, `ink18`, `ink22`, `onAccent`, `cardLight`, `cardWarm`, `panelTop`, `panelBottom`, `panelCoralTint`; `radiusIconButton`, `radiusControl`, `radiusCell`, `radiusPill`; `emphasis`, `control`, `cardDefault`, `chip`; `windowTitleAccent`, `wordmarkAccent`, `navLabelSans`, `syncPrimarySans`, `syncSecondarySans`.
- Citation spot-check — `app_theme_test.dart:12` is `expect(theme.scaffoldBackgroundColor, Palette.page);` exactly; `bottom_bar_shell_test.dart:52` is `testWidgets('the center capture invokes onCapture'` exactly; `sidebar_shell.dart:28` is `backgroundColor: Palette.page,` and `:76-79` is the `SizedBox(width: 248)` + `EdgeInsets.all(16)` pair. All four as the parent spec claimed.
- `dashed_divider.dart:9-10` — `thickness = 1.5`, `color = Palette.ink` confirmed as defaults, so B2's "no widget change required" holds.
- `git merge --ff-only` twice, both clean.
- **NOT verified:** no Dart ran this session. `flutter analyze` and `flutter test` were not invoked — the change touches no code. The slice's own content is unexecuted by definition until mitosis decomposes it.

## Running state
none — no background shells, no agents dispatched this session.

## Deferred + open
- **The `mitosis: <slug>` PR-title source is still unlocated.** Cluster B will park at `pr-title-lint` exactly as Cluster A did; with #58 merged a retitle now clears the red.
- **`receipts.yml` still runs unpinned actions**, including third-party `shaheershoaib/receipts/enforcer@main` with the workflow token, and #58 widened the trigger to `edited`. Chip `task_e10f4f7e`.
- **A2/A4's app-wide blast radius was never walked** beyond the Today screen — Calendar, Garden, Search, Day Detail and Settings. No Cluster B MSP revisits them either. Cluster B's own §5.4 requires a five-screen desktop pass at its boundary, which is the natural place to finally catch it.
- The five A3 dialogs were never separately opened.
- The A1 plan fix still lives only in gitignored `.mitosis/a1-token-ladder.plan.md`.
- OQ-3 and OQ-6 remain open; neither touches Cluster B. **OQ-1 binds B4 and is resolved** (prototype's two-line treatment, truthful strings).
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.
- Demoted from PROJECT.md this session to hold the 80-line cap (all files remain on disk unchanged): decisions `2026-07-24-combined-camera-deps-pr`, `2026-07-24-camera-preview-lifecycle-root-causes`, `2026-07-21-capture-flow-root-cause-and-fix`, `2026-07-21-vm-rpc-screenshot-for-visual-verification`. The last two have their load-bearing residue already carried in PROJECT.md's State snapshot (run via `flutter run -d macos`; screenshot via the `_flutter.screenshot` VM RPC).

## Pick up here
The slice is on main and the base is reconciled — the next action is the dispatch itself, nothing before it. Dispatch mitosis with `spec` = `docs/specs/2026-07-27-prototype-alignment-cluster-b.md`, `repoRoot` = the project root, `baseBranch` = `main`, `sourcePrefix` = `msp-cluster-b` (a BARE token, run-distinct — the engine reuses a colliding branch silently), `worktreeRoot` = a run-distinct path beside the Cluster A one, and `verify`/`build` from `receipts.config.json`. Then review before Cluster C.
