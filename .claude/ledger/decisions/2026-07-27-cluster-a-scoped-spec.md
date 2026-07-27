Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
The run contract ruled "Cluster A (A1-A5) only" but never named a mechanism. Mitosis has no scope parameter — its input parser accepts only `{spec, repoRoot, baseBranch, sourcePrefix, verify, build, models, worktreeRoot, fixLoopMax, retry}` (`mitosis.js:3303-3312`) and its decomposer is told to read the spec at `${spec}` and decompose all of it (`:3762-3768`). Passing the parent spec would have produced all 39 MSPs — the exact single-run shape the contract rejected.

## Decision
Scope a mitosis run by writing an **execution slice**: a spec document containing only the target cluster's MSPs verbatim, plus every constraint, finding and verification rule that binds them, plus a hard scope fence. `docs/specs/2026-07-27-prototype-alignment-cluster-a.md` is that slice for Cluster A. It is committed and lands on main before dispatch; `spec` points at the SLICE, never the parent.

## Consequences
- The slice carries the FULL non-negotiable set even where a row binds no Cluster A MSP, so an implementer can distinguish "preserved by decision" from "leftover to clean up". Non-binding rows are labelled as such, and the slice states outright that no MSP in this run touches N1-N11.
- Scratchpad placement was rejected: `computeLogicalRunId` hashes the spec path (`:307-308`) and the manifest's `specContentHash` must still match on relaunch (`:1496-1502`), so an ephemeral path would silently force a full re-decompose. Human-gated merges make a cross-session relaunch near-certain.
- Branch-only placement was also rejected, though decompose and plan run with `worktree: null` against `repoRoot` (`:3771`, `:4292`) and would have read it. The run contract's generalization — spec on base before dispatch — governs.
- Generalises: every remaining cluster (B-H) needs its own slice cut the same way. The parent spec stays the authority and the citation source; slices are execution inputs, never a fork of it.
