Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
Every mitosis PR fails this repo's `pr-title-lint` because the engine hardcodes `mitosis: <msp-id>` and the lint demands a Conventional Commits type. The standing instruction was to retitle every PR before merging. PR #51 was merged with the check RED and the title unchanged, which settles the question by observation.

## Decision
`pr-title-lint` is NOT merge-blocking; no branch protection enforces it. Retitling is squash-message hygiene, not a gate. It stays worth doing (the title becomes the permanent squash message on main) but it never blocks a merge and must not be treated as a step on the critical path.

## Consequences
- The merged squash message for A3 is `mitosis: a3-dialog-material-host`, non-conventional and now permanent in main's history. Accepted.
- A retitle alone cannot turn the check green: the job reads `PR_TITLE: ${{ github.event.pull_request.title }}` (`.github/workflows/receipts.yml:27`) and the workflow triggers on bare `on: pull_request`, whose default types are opened/synchronize/reopened — `edited` is absent, and `gh run rerun` replays the stale payload. Only a push (synchronize) or a close+reopen re-fires it with the new title.
- Supersedes the "retitle the PR before merging" framing in the PROJECT.md state snapshot; the receipts job (enforcer + D6) remains the check that carries real signal, subject to `decisions/2026-07-20-ci-gates-are-hollow-for-dart.md`.
