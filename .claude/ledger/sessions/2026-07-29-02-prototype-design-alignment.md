# Session 2026-07-29-02 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief flagged a FIFTH ledger drift: PR #84 was recorded as awaiting merge and had already merged (`48a7a74`), and the session-22 ledger handoff had also landed as PR #85 (`5f51c07`). Local `main` was six behind. The user asked why mitosis cannot be re-dispatched, then directed: continue without mitosis, proceed, dispatch subagents.

## What shipped
No code. This session produced two rulings and the verified inputs for the Cluster D slice.

| Artifact | Where |
|---|---|
| Local `main` reconciled `8098e5c` -> `5f51c07` | fast-forward, clean |
| Working branch cut | `docs/cluster-d-slice` |
| Ruling: C7's 3 rows deferred to §5.4, Cluster D first | decisions/2026-07-29-c7-rows-wait-on-the-visual-pass.md (`e70bf25`) |
| Ruling: D3 and D4 fence defects resolved pre-dispatch | decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md |

**Cluster C is CLOSED.** All of C1-C7 merged; 16 of 39 MSPs. `origin/main` is `5f51c07`.

## Cluster D recon — VERIFIED, do not re-run (cost ~460k subagent tokens)

Four agents: right-rail app map, prototype citations + tokens, C-slice format, copy-forward sections.

**Citations: ZERO errors across D1-D4.** Every cited line in `Field Notes.dc.html` resolved byte-identical — the first cluster where the spec's numbers held. Scoped to D only; §7's rule still stands for E-H.

**Tokens: no token work needed.** Cluster A pre-provisioned every value D1-D4 wants — `sectionHeaderAccent`, `caption8/9/10Sans`, `monoMicroSans`, `memoryTitleSerif`, `captureLabelSans`, `Shapes.radiusCell`(10)/`radiusControl`(12)/`radiusPill`(13), `Shadows.cellToday/cellFilled/cardDefault/emphasis`. All exact matches. D touches no token file.

**Four traps needing binding §0 resolutions, each with a receipt:**
1. D1's rail border is **1px**; `Shapes.outlineWidth` is 1.5 and no 1px token exists. Must not round to the house stroke.
2. D4's hatch band: `CrossHatchVariant.photo`'s DEFAULT is byte-exact (`#E2D3BA`/`#ECDFC8`, 6px/12px, `cross_hatch_placeholder.dart:27-32`). Pass NO `hatchColor` — it alpha-blends at 0.5. Same trap that cost C7.
3. `Shapes.radiusPill`(13) is numerically correct for D4's card but named for a pill. Layer is rename-closed; state the oddity, do not fix.
4. `lib/design/icons/capture_icons.dart` does not exist — D3 creates it.

**Stale "Current app" claims (Cluster A shipped them; spec written 2026-07-26 pre-A):**
- Section headers ALREADY use `sectionHeaderAccent` (Caveat 17 w600 sage) at `this_week_garden.dart:30`, `today_capture_buttons.dart:77`, `on_this_day_card.dart:100`. D1 owes only the lowercase copy and the 2/10/9 bottom margins.
- The primary/secondary shadow split ALREADY exists (`sticker_button.dart:102-109`), and `StickerButton` ALREADY has an `icon` param with 10px gap (`:24`, `:58-61`) and matching geometry.
- `this_week_garden_test.dart` is labelled "new" in the spec. It EXISTS, 3 cases.

**Confirmed base state:** `todayRailWidth = 300` (`today_layout.dart:3`, target 266); rail has no left border/padding, `SizedBox(width: 24)` gap, one `SingleChildScrollView` wrapping feed + rail (`today_screen.dart:74-87`); three sections each wrapped in `StickerCard(cardLight)` separated by `SizedBox(height:16)`, no hairlines (`today_right_rail.dart:18-28`); week grid is a single 7-wide `Row`, `_WeekCell` has NO container decoration at all (`this_week_garden.dart:32-38`, `:59-84`); empty-day dash uses wrong `Palette.placeholder` (`:66-69`) where `Palette.dashMuted` is the target; no tap handler anywhere.

**File-overlap matrix — D1 collides with ALL of D2/D3/D4:**
`this_week_garden.dart` D1∩D2 · `today_capture_buttons.dart` D1∩D3 · `on_this_day_card.dart` D1∩D4.
So the wave graph is **D1 -> {D2, D3, D4}**: D1 serializes first, then D2/D3/D4 are pairwise disjoint on source files and run parallel. D1's stated `Depends on` (A1, A2) does NOT say this — the edges come from the file matrix per decisions/2026-07-27-shared-file-cluster-serializes.md.

**UNDECLARED test-file collisions (spec defect):**
- `today_screen_test.dart` — D1 (`'This week'`/`'Quick capture'`/`'On this day'` `:86-91`) + D3 (`'Capture'` `:89`) + D4 (`'1 year ago'` `:91`). Declared under D3 only.
- `this_week_garden_test.dart` — D1 (title copy `:37`) + D2. Declared under D2 only, mislabelled new.
- `on_this_day_card_test.dart` — D1 (title) + D4 (years-ago `:40-45`, long-date `:68-70`, preview `:86-90`, FlowerBloom `:100`). Declared under NEITHER.

**Preserve items binding to D:** on-this-day empty + error states (endangered by D1 unwrapping the section and D4 rewriting the card; `on_this_day_card.dart:36-40`, `:116-123` both CONFIRMED at those lines); chooser + `'Coming soon'` phone reachability (D3 removes the desktop button; standing proof is `bottom_bar_shell_test.dart:52`, must stay green unchanged); N25 bloom semantics (D2 — note `this_week_garden.dart:54-58` double-wraps `Semantics > ExcludeSemantics`, so D2's new button role must land on the OUTER Semantics, not inside the excluded subtree).
**Zero N24 exposure in Cluster D** — confirmed by path disjointness.

**Test admission:** exactly one new test qualifies — D2's tap-to-Calendar is genuine new behaviour. D4 needs an additive case for its new short-date formatter. Everything else is restyle, no new test.

## Slice format (from the C slice, 649 lines)
Header C-style: title / `Slice of:` / `Cluster:` / `MSPs:` / `Base: main at 5f51c07` / `Citation source:` — no `Date:`, no `Status:`.
Sections: §0 (rationale, token table `Token|path:line|Value|Consumed by`, PRIMITIVE RESOLUTIONS, HARD SCOPE FENCE `File|Owning MSP|New?` + carve-outs + verify-only consumers + named traps, SERIALIZATION `Shared file|Claimed by|Edge` + contract edges + ASCII graph + wave table `Wave|MSPs|Justification`) · §1 BLUF · §2 Non-negotiables 2.1-2.7 · §3 findings `Element|Prototype|Current app|Sev|Citations` · §4 per-MSP prose fields (Outcome, Files, Depends on, [Decision context], Target values, Must not regress, [Slice note / Slice resolution (binding)], Acceptance criteria, [Verification]) · §5 (5.1-5.5) · §6 (6.1-6.3) · §7 Traceability. Bare `---` between sections.

**Corrections the D slice must make, not inherit:**
- **§5.2 contradicts the ledger.** It says existing tests must pass "unmodified" and never mentions retargeting; decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md rules an MSP MAY retarget assertions pinning a rendering it is mandated to change. Carry the retargeting rule explicitly with the N24 carve-out as the hard boundary.
- **Enumerate N24's eight files inline in the FENCE**, not just in §2.5 — the fence currently cross-references by N-number, and a `cards/` test reads as ordinary without the list.
- **Every §0 resolution names the test that would red if wrong.** C's resolution 6 was reasoned, not receipted, and cost C7 three rows.
- Baseline line: **904**, not C's 902.
- §7 for D: state that zero citation errors were found in D's own region; the parent's count stays at three.
- C dropped B's 8-cluster dependency table with no rationale. Decide deliberately for D.

## Verification
- `gh pr view 84` -> MERGED `48a7a74`; `origin/main` `5f51c07`; zero open PRs. Ledger drift confirmed and corrected.
- All four pointer paths spot-checked on disk. `grep` for `force-with-lease` across global/project/local settings: **NOT FOUND** — the granted rule is still unwritten.
- No code was run this session. No `fullValidationCmd`, no `flutter` invocation.

## Running state
none. Four agents completed and returned. No background shells.

## Deferred + open
- **The Cluster D slice is NOT written.** All inputs above are verified and sufficient to compose it without re-running recon.
- §5.4's macOS visual pass now owes FOUR rulings: C1's flame cusp at (9,8), C5's tilt scatter, C7's badge/chip anchors, the chip's tokenless ground `#2A241D`.
- Orphan branches now ten (`docs/cluster-d-slice` will merge; `chore/ledger-handoff-session-22` joins the list) plus three stale stashes — one confirmed batch removal still owed.
- Standing: `--force-with-lease` rule unwritten/unproven; four `integration_test/` flows never run; OQ-3 and OQ-6 open; `receipts.yml` unpinned third-party action (chip `task_e10f4f7e`); A2/A4 blast radius never walked; five A3 dialogs never opened.

## Pick up here
Compose `docs/specs/2026-07-29-prototype-alignment-cluster-d.md` from the verified inputs above — format, values, fence, wave graph, corrections and both rulings are all settled. Land it on `main`, then run D1 alone, then D2/D3/D4 in parallel as direct `implementer` dispatches with a local `fullValidationCmd` per head.
