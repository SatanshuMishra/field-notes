# Session 2026-07-27-03 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`; the user directed "Go. Think Hard." The thread's next step was to dispatch mitosis on the approved alignment spec scoped to Cluster A (A1-A5). All inputs were recorded as resolved. No application code had moved.

## What shipped
- **The Cluster A scoping gap was found and closed.** `docs/specs/2026-07-27-prototype-alignment-cluster-a.md` (537 lines, commit `3fb33e4`) — an execution slice carrying MSPs A1-A5 verbatim plus every constraint that binds them.
- `.claude/ledger/decisions/2026-07-27-cluster-a-scoped-spec.md` — the decision record for the slice-a-spec mechanism.
- Mitosis was **NOT** dispatched. Two rulings deferred it (see Deferred + open).

**The gap.** The run contract ruled "Cluster A only", but that scope had no mechanism. `mitosis.js` accepts exactly `{spec, repoRoot, baseBranch, sourcePrefix, verify, build, models, worktreeRoot, fixLoopMax, retry}` (parsed at `:3303-3312`) — **there is no scope parameter**, and the decompose agent is prompted to "Read the approved spec/batch document at: ${spec}" and decompose all of it (`:3762-3768`). Passing the parent spec would have produced all 39 MSPs across 8 clusters — precisely the single-run shape the run contract rejected. The only lever is the document handed to the decomposer.

**What the slice carries** (nothing paraphrased; every value and citation reproduced verbatim from the parent):
- A hard scope fence naming the directories no MSP in this run may enter, and the instruction to STOP and report rather than widen if decomposition suggests a unit outside A1-A5.
- The FULL non-negotiable set §2.1-§2.6. Deliberate: an implementer restyling a shared token must be able to tell "preserved by decision" from "leftover to clean up". Paired with an explicit statement that no MSP in this run touches N1-N11.
- §2.7 filtered to the five rows that actually bind Cluster A (entry-card actions, camera picker/N12, PhotoTray, N15-N19, N24), with the non-binding rows named as such.
- §3.0 (shadow-inventory correction) and §3.1 (token/primitive findings) — the sources A1/A2/A4/A5 implement.
- §5.1-§5.4 with the A-scoped test table, and the note that with H1 undispatched, gate 2 (the 106 playback tests) is the only automated pixel-adjacent net in this run.
- §6.2 in full (binds A2's no-FontVariation / no-ThemeExtension rules and A5), plus an added bullet: no renames or removals in the existing token layer.
- §7 in full — the citation-trust rule — with the two corrections that land directly in A1's target tables (`ink08`/`ink12`, `Shadows.chip`) called out.

## Tried and failed
- **Assumed mitosis could be scoped by argument.** It cannot. Checked `input` parsing at `mitosis.js:3299-3312` and the decompose prompt at `:3757-3772`; no scope, filter, cluster or subset key exists. The skill's own input list is complete.
- **Considered writing the scoped spec to the scratchpad.** Rejected. `computeLogicalRunId(spec, baseBranch)` hashes the spec path (`:307-308`) and the manifest stores a `specContentHash` that must still match on relaunch or the whole manifest is discarded (`:1496-1502`). Human-gated merges make a cross-session relaunch near-certain, so a session-ephemeral spec path would silently force a full re-decompose.
- **Considered dispatching off the branch-committed copy without landing it on main.** Ruled against by the user. The decompose and plan stages both run with `worktree: null` against `repoRoot` (`:3771`, `:4292`), so they WOULD have read it fine via absolute path — the risk was confined to relaunch after a working-copy branch switch, not to agent readability. The run contract's own generalization (spec on base before dispatch) settled it.

## Verification
- `git log --oneline -5`, `git branch --show-current`, `git rev-list --left-right --count main...HEAD` — expected the thread's recorded branch and a clean tree; observed `chore/ledger-handoff-session-08`, clean, `0 1` (left=main, right=HEAD: 1 ahead, 0 behind). Columns confirmed against the session-02 misread.
- `git diff main --stat -- lib/` — expected empty, confirming execution had not started; observed empty.
- All four thread Pointers checked with a file-existence loop — expected all present; observed 4/4 OK.
- `grep -n "args\.\|args =" mitosis.js`, `sed -n 3290,3400p`, `sed -n 3757,3775p` — expected a scope parameter; observed none. This is the finding, not a failure.
- `grep -n "planGroundTruthSeed\|worktree: " mitosis.js` — expected to learn where plan agents run; observed `worktree: null` on both the decompose (`:3771`) and plan (`:4292`) dispatches, i.e. against `repoRoot`.
- `wc -l docs/specs/2026-07-27-prototype-alignment-cluster-a.md` — 537.
- `wc -l .claude/ledger/PROJECT.md` — 80, at cap, before the demotion below.
- No application code changed this session, so no test suite was run and none was warranted.

## Running state
none

## Deferred + open
- **The mitosis dispatch.** Still not run. Blocked on the scoped spec reaching main. Inputs, ready to pass verbatim: `spec` = `/Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/2026-07-27-prototype-alignment-cluster-a.md` (the SLICE, not the parent); `repoRoot` = `/Users/satanshumishra/Documents/DevLabs/fireplace`; `baseBranch` = `main`; `sourcePrefix` = `msp` (NO trailing slash); `verify` = `{scopedCheckCmd, fullValidationCmd}` from `receipts.config.json:16-17`; `build` = `{sha_source: "git rev-parse HEAD"}` from `:9`; `fixLoopMax` 2.
- **Dispatch deferred to a fresh session** by user ruling at ~80% context. Mitosis runs in the background but needs an orchestrator with headroom to retitle every PR past `pr-title-lint` and shepherd five human-gated merges.
- **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model) remain open. The slice states explicitly that neither may be resolved implicitly by a Cluster A implementer: A4 preserves the entry-card actions and A4/A5 preserve `PhotoTray` exactly as they are today.
- **WIP:** two unrelated non-terminal threads — `post-ship-hardening` (paused) and `prototype-design-alignment` (paused). Surfaced for disposition, not auto-closed.
- Demoted from PROJECT.md for cap enforcement (file remains on disk, content unchanged): the "Mitosis engine-era residue" State-snapshot line — plan-review journal recovery, the symlink defect, engine lessons and `.mitosis/` artifacts, held verbatim in `sessions/2026-07-25-01-video-card-playback-controls.md`. It was already a pointer-to-a-pointer and is historical now that 31/31 shipped and the app is code-complete.

## Pick up here
Merge the PR carrying `docs/specs/2026-07-27-prototype-alignment-cluster-a.md` (human-gated; `gh pr merge` is blocked by hook). Once the slice is on main, dispatch mitosis with the inputs above — pass the **slice** path as `spec`, not the parent. Expect to retitle every PR the engine opens (`mitosis: <msp-id>` fails `pr-title-lint`). A3 is dependency-free and fixes a shipping defect, so it can land in parallel with A1/A2. Before dispatching, re-read the slice's §7: line citations are pointers to verify against `docs/prototype/project/Field Notes.dc.html`, not authority.
