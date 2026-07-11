# Fireplace — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server. Open-source on GitHub (repo SatanshuMishra/field-notes, private for now).

## Constraints
- No paid Apple/Google developer account; manual sideload/install. macOS + Android only (no iOS).
- Works fully standalone with no server; sync is an optional v2 layer.
- Fast, secure (E2EE), robust; offline-capable; reachable via Tailscale.
- Binary assets must be human-provided + committed (harness blocks agent/main-thread downloads).

## Active Decisions
- decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md — receipts.yml npm-ci fix (ec7b959); relaunch rebuilds open-PR MSPs; keep run.json + remove worktrees each relaunch
- decisions/2026-07-10-mitosis-run-contract.md — fresh mitosis run inputs; sourcePrefix "msp" (no trailing slash)
- decisions/2026-07-10-fonts-vendored-human-provided.md — vendored OFL fonts, human-provided (downloads blocked)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; ULID/updated_at/deleted_at/content-addressed media in v1
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 reconciliation points resolved; v1 = prototype minus sync, light-only, "Field Notes"
- decisions/2026-07-09-tech-stack.md — Flutter + SQLite both sides + custom REST sync + E2EE + Tailscale + Docker Compose
- decisions/2026-07-09-standalone-first.md — app works fully without a server; sync optional
- decisions/2026-07-09-product-model.md — day/entry/memory model, 10 moods, streak, reminders, navigation
- decisions/2026-07-09-design-baseline.md — Field Notes prototype is the canonical visual baseline

## Threads
- journal-app-design — paused — mitosis engine PROVEN (run 5 built code + opened PRs #1-4); receipts CI bug fixed (ec7b959); next = relaunch run 7 from fresh session, resume across usage windows until all 31 MSPs ship

## State snapshot (2026-07-11)
- Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. main == origin/main == ec7b959 (receipts.yml `npm ci` fix landed).
- Mitosis engine PROVEN: run 5 (wf_2a220c77-2e6) ran end-to-end, decomposed 31 MSPs, opened PRs #1-4 (all were CI-red on the now-fixed npm-ci bug). Run 6 (wf_0e9953fd-8e2) failed only on the Claude usage limit (~18min) — not a bug.
- Relaunch-ready: no stale worktrees, .mitosis/run.json + 4 remote `msp/*` branches/PRs intact. Full run spans multiple usage windows -> relaunch-to-resume.
- GitHub repo renamed fireplace -> field-notes (PRIVATE); local directory still "fireplace".

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (§0 = implementation status + pre-vendored fonts)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
- .claude/ledger/sessions/2026-07-11-02-journal-app-design.md — latest session (receipts fix + runs 5/6; relaunch semantics)
- .claude/ledger/sessions/2026-07-10-02-journal-app-design.md — full verbatim fresh-run Workflow command
