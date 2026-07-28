# Session 2026-07-27-07 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief reported Cluster A fully merged but locally unvalidated, and flagged what looked like drift: the ledger branch pushed with no PR and its commits absent from main. User directed "Go. Think hard."

## What shipped
- **CLUSTER A IS VALIDATED.** `fullValidationCmd` ran green against a worktree pinned to `81039f3`. This closes the thread's single highest open risk and, because the worktree carried all five merged MSPs at once, also closes "A1/A2/A4/A5 were never tested against each other's merged state" — no PR's CI had ever computed against the combined tree.
- **PR #58** — `ci: re-fire pr title lint on retitle events`. `.github/workflows/receipts.yml` subscribed only to `opened|synchronize|reopened`, so an `edited` title never re-fired `pr-title-lint`; a corrected title could not clear the red at all. Branch `fix/pr-title-lint-retitle-trigger` off `488b48a`.
- `decisions/2026-07-27-pr-title-lint-fix-belongs-at-the-title.md`.
- `decisions/2026-07-27-primitives-cluster-confirms-by-regression.md`.
- Background task chip `task_e10f4f7e` — re-pin the unpinned GitHub Actions in `receipts.yml`.
- **User hardware-confirmed the Cluster A state: "All changes look good."**

## Tried and failed
- **The reported ledger-branch drift was an artifact of a stale ref, not real.** `git rev-parse origin/main` returned `81039f3` and `gh pr list --state open` returned nothing, which read as "ledger commits stranded." Neither was current: no `git fetch` had run this session. PR #57 had already merged; `main` is `488b48a`. **Fetch before reporting a divergence — a local `origin/*` ref is only as fresh as the last fetch.** `git diff --name-only 81039f3..488b48a` is ledger markdown only, so validating `81039f3` still speaks for main.
- **The ledger's two candidate pr-title-lint fixes were both wrong.** Loosening the alternation was rejected: the engine's OWN contract (`~/.claude/lib/superpowers-parallel/pr-format.mjs:1-2`, enforced `mitosis-git.mjs:149-150`) and the skill template (`~/.claude/skills/mitosis/templates/receipts.yml:31`) carry the identical eight types, the engine's being stricter. "Change the engine's title template" rests on a false premise — no such template exists in `SKILL.md`, `prompt-snapshots/`, or any `lib/superpowers-parallel/*.mjs`; `mitosis: ` appears only under `tests/`. **The title source was NOT found.**
- **A PreToolUse hook now blocks bare `gh pr create`** and routes every PR through `mitosis-git pr-create`, which validates the title against `PR_TITLE_PATTERN` and would reject `mitosis: <slug>` outright. PR #56's body carries neither `renderPrCreateBody`'s `## Why/## What` headings nor its exact MACHINE_TRAILER, so #51/#53/#54/#55/#56 were created off that path. `--why` values cap at 200 characters each (max 3); the first attempt was rejected for length.
- **macOS could not be agent-driven.** The app BUILDS and LAUNCHES clean at `81039f3` (Dart VM came up at `http://127.0.0.1:61982/`, files synced), but three drive paths are unavailable: a backgrounded `flutter run` loses stdin and dies ("Lost connection to device"); `curl` to the VM service RPC was permission-denied; and the prior session's `scratchpad/vm_screenshot.dart` no longer exists. The user ran it and confirmed visually instead.
- **`.github/workflows/receipts.yml` has drifted from its skill template and UNPINNED its actions**: `actions/checkout@v4`, `actions/setup-node@v4`, and `shaheershoaib/receipts/enforcer@main` against the template's three SHA pins. The `@main` third-party action is the serious one — it executes whatever that branch holds, on every PR, with the workflow token. Widening the trigger to `edited` increases that exposure. Not fixed here (out of scope for a title-lint PR); chip `task_e10f4f7e` carries it.

## Verification
- `flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test` in `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-a/validate-81039f3` — `flutter analyze` → **"No issues found! (ran in 3.3s)"**; `flutter test` → **"All tests passed!" at +899, zero `-N` failure lines, EXIT_CODE=0**. Log: `/private/tmp/claude-501/-Users-satanshumishra-Documents-DevLabs-fireplace/ccef7f43-2a60-48d6-8851-5c721ec4cdb7/scratchpad/validate-81039f3.log`.
- The 18-file video/playback stack ran inside that green suite (`test/features/entry_cards/playback/`, `.../cards/video_*`, `test/features/capture/video/`), so preserve items N1-N10 survived A1/A2/A4/A5.
- `git diff --name-only 81039f3..488b48a` — ledger markdown only, no Dart.
- `gh pr list --state merged` — #57 `chore: ledger handoff — Cluster A complete` MERGED; #51/#53/#54/#55/#56 titled `mitosis: <slug>`.
- `grep -nE "^#{2,4} +(MSP )?[A-H][0-9]+" docs/specs/2026-07-26-prototype-design-alignment.md` — 39 MSPs; Today is C1-C7, right rail D1-D4, nav rail B1-B4, flowers E1-E4, picker F1-F4, composers G1-G8, goldens H1. **Cluster A contains no screen-composition MSP.**
- **NOT verified:** the five A3 dialogs were not separately opened, and Calendar, Garden, Search, Day Detail and Settings were not individually walked. The user's confirmation followed a Today-screen screenshot.

## Running state
none — both background shells terminal (`bq6epoke2` validation exit 0; `beelf6nh8` `flutter run` exited when stdin closed). No agents. Worktree `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-a/validate-81039f3` left in place per `decisions/2026-07-20-keep-stale-worktrees.md`.

## Deferred + open
- **PR #58 is open and unmerged.** Merges are human-gated (`decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md`).
- **The `mitosis: <slug>` title source is still unlocated.** Until it is fixed, Cluster B parks at `pr-title-lint` exactly as Cluster A did — but with #58 merged, a retitle can now green it.
- Unpinned actions in `receipts.yml` — chip `task_e10f4f7e`.
- The A1 plan fix still lives only in gitignored `.mitosis/a1-token-ladder.plan.md`.
- OQ-3 and OQ-6 remain open; neither touches Cluster A or B.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.

## Pick up here
Cluster A is shipped, validated and user-accepted; the thread's centre of gravity moves to Cluster B. Cut the Cluster B execution slice (B1-B4: app panel gradient and window chrome, nav rail geometry and brand lockup, nav item states and icon glyphs, nav rail footer) from `docs/specs/2026-07-26-prototype-design-alignment.md` using `docs/specs/2026-07-27-prototype-alignment-cluster-a.md` as the reference shape, land it on main before dispatch, then dispatch mitosis with a run-distinct `sourcePrefix` and the REQUIRED `worktreeRoot`. Merge PR #58 first so the next run's parks are clearable.
