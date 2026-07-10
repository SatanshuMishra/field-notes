---
thread: journal-app-design
status: paused
updated: 2026-07-10
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Launch a FRESH mitosis run (new runId, NOT a resume of wf_6b26b84f-135) using the exact Workflow call in sessions/2026-07-10-02-journal-app-design.md. Fonts are pre-vendored so design-tokens should clear. Watch /workflows.
branch: main
---

## Status
Design complete + user-approved. Implementation BOOTSTRAPPED: Flutter 3.44.6 installed; minimal Phase 0 skeleton committed (Riverpod 3.3.2 + drift 2.34.1, analyze/test green); receipts CI installed; 3 OFL fonts vendored under assets/fonts/. Two mitosis runs failed on fixable issues (run 1: `sourcePrefix` double-slash ref; run 2: font-download blocked by the harness safety classifier) — BOTH root-caused and resolved. Repo clean: main == origin/main == 54a2c51, only `main`, no worktrees. Ready for a FRESH mitosis run (31 MSPs).

## Active Goal
Execute Field Notes v1 via mitosis (fresh run) — decompose + ship the 31 MSPs into the private repo.

## Next Step
Launch the fresh mitosis run (exact args in sessions/2026-07-10-02-journal-app-design.md and decisions/2026-07-10-mitosis-run-contract.md). Do NOT resume wf_6b26b84f-135 (spec changed since its cached decompose).

## Open Risks
- camera_macos community plugin + macOS video thumbnails — verify early (Phase 2).
- Binary assets CANNOT be agent-downloaded (harness blocks curl/wget for agents AND main thread) — must be human-provided + committed (see fonts decision). Applies to sound effects / any future binaries.
- Platform build toolchains (full Xcode + CocoaPods, Android SDK) not installed — needed only at Phase 8 (human step).
- mitosis is multi-hour and opens ~31 PRs on the private repo; expect churn.

## Key Decisions
- decisions/2026-07-10-mitosis-run-contract.md — exact fresh-run inputs; sourcePrefix "msp" (no trailing slash)
- decisions/2026-07-10-fonts-vendored-human-provided.md — vendored OFL fonts, human-provided (downloads blocked)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only
- decisions/2026-07-09-tech-stack.md — Flutter + SQLite both + custom REST sync + E2EE + Tailscale

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery.

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 now notes pre-vendored fonts + skeleton status)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-10-02-journal-app-design.md
- sessions/2026-07-10-01-journal-app-design.md
