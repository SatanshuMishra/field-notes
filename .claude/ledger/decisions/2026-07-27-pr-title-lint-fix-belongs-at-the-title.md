Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
`pr-title-lint` has failed every mitosis PR (#51, #53, #54, #55, #56), all titled `mitosis: <slug>`. The ledger offered two candidate fixes: loosen the CI type alternation, or change the engine's title template.

## Decision
Both were rejected. The lint is right and the TITLE is wrong: `.github/workflows/receipts.yml:31`, the skill template `~/.claude/skills/mitosis/templates/receipts.yml:31`, and the engine's OWN contract (`pr-format.mjs:1-2`, enforced `mitosis-git.mjs:149-150`) all carry the identical eight types, the engine's stricter still. The fix belongs at the title source, never in CI.

## Consequences
- PR #58 landed the one real project-local defect: bare `on: pull_request` excludes `edited`, so a corrected title could not clear the red at all.
- "Change the engine's title template" rests on a false premise — no such template exists in `SKILL.md`, `prompt-snapshots/`, or any `lib/superpowers-parallel/*.mjs`; `mitosis: ` appears only under `tests/`. THE SOURCE WAS NOT FOUND.
- A PreToolUse hook now blocks bare `gh pr create` and routes PRs through `mitosis-git pr-create`, whose validator would reject `mitosis: <slug>`. PR #56's body carries neither `renderPrCreateBody`'s headings nor its exact trailer, so those five PRs were created off that path.
- Cluster B will park identically; with #58 merged a retitle can at least green it.
- Supersedes nothing. Folds the index line of decisions/2026-07-27-pr-title-lint-is-not-merge-blocking.md, which remains accepted and on disk: the check is never a merge gate.
