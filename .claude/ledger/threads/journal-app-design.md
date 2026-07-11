---
thread: journal-app-design
status: paused
updated: 2026-07-11
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: User is fixing the mitosis `await import()` blocker separately (inline prepare-plan.mjs + merge-policy.mjs into mitosis.js). Once it lands, grep mitosis.js for `await import` (must be none), pre-flight the repo, then launch a FRESH mitosis run per decisions/2026-07-10-mitosis-run-contract.md. Do NOT resume wf_05cbf0e7-609.
branch: main
---

## Status
Design complete + user-approved; Phase 0 skeleton + fonts + receipts CI committed (main == origin/main == d3726e0). Field Notes v1 execution is blocked on the mitosis engine: FOUR runs have failed on four distinct, root-caused issues (latest: `await import()` unsupported by the Workflow sandbox). The prepare adopt-vs-bootstrap rearchitecture is verified logically correct for this repo; the user is fixing the import-loading blocker separately.

## Active Goal
Execute Field Notes v1 via mitosis (fresh run) — decompose + ship the 36 MSPs into the private repo.

## Next Step
Once the user confirms the mitosis import() fix landed: `grep -n "await import" ~/.claude/workflows/mitosis.js` must return nothing; pre-flight repo clean (remove any stale .mitosis/run.json; no msp/* branches; no worktrees); then launch the FRESH run with the exact args in decisions/2026-07-10-mitosis-run-contract.md (verbatim block also in sessions/2026-07-10-02). Do NOT resume wf_05cbf0e7-609.

## Open Risks
- mitosis engine stability: 4 consecutive early-stage failures (sourcePrefix double-slash, font-download block, weaken false-positive, await-import). Each root-caused; watch for a 5th mode at prepare/decompose before trusting a full run.
- Binary assets CANNOT be agent-downloaded (harness blocks curl/wget); must be human-provided + committed. Applies to sound effects / future binaries.
- camera_macos community plugin + macOS video thumbnails — verify early (Phase 2).
- Platform build toolchains (full Xcode + CocoaPods, Android SDK) not installed — needed only at Phase 8 (human step).
- mitosis is multi-hour and opens ~36 PRs on the private repo; expect churn.

## Key Decisions
- decisions/2026-07-10-mitosis-run-contract.md — exact fresh-run inputs; sourcePrefix "msp" (no trailing slash)
- decisions/2026-07-10-fonts-vendored-human-provided.md — vendored OFL fonts, human-provided (downloads blocked)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only
- decisions/2026-07-09-tech-stack.md — Flutter + SQLite both + custom REST sync + E2EE + Tailscale

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery.

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 notes pre-vendored fonts + skeleton status)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-11-01-journal-app-design.md
- sessions/2026-07-10-02-journal-app-design.md
