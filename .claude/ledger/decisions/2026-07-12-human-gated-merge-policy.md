# Human-gated merge policy (autonomous reversed)

Status: accepted
Date: 2026-07-12
Supersedes: autonomous-merge portion of decisions/2026-07-11-foundations-shipped-autonomous-policy.md

## Context
Run wf_b72ceb41-dd5 (mergePolicy "autonomous") shipped 0. The harness safety classifier blocks any
DELEGATED agent from squash-merging its own PR (Merge Without Review + Self-Approval), PROACTIVELY —
the ship agent is blocked before publishing, so nothing reaches origin (gh pr list empty; no remote
msp branches beyond the 4 merged foundations). domain-models/flower-svg-set/sticker-widget-kit built
+ tested fine, stranded on local integration branches. Autonomous-by-agent is unachievable here.

## Decision
Use mitosis mergePolicy "human-gated" (mitosis.js:2529): ship agents publish the green PR and STOP.
The MAIN THREAD merges each green PR (gh pr merge --squash) under explicit per-session consent
(granted this session), then relaunches the next dependency layer.

## Consequences
Layer-by-layer shipping (a merge gates its dependents) -> several relaunch+merge cycles for all 31.
