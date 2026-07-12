# Fireplace — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server. Open-source on GitHub (repo SatanshuMishra/field-notes, private for now).

## Constraints
- No paid Apple/Google developer account; manual sideload/install. macOS + Android only (no iOS).
- Works fully standalone with no server; sync is an optional v2 layer.
- Fast, secure (E2EE), robust; offline-capable; reachable via Tailscale.
- Binary assets must be human-provided + committed (harness blocks agent/main-thread downloads).

## Active Decisions
- decisions/2026-07-11-foundations-shipped-autonomous-policy.md — force-push authorized; 4 foundation PRs merged (origin/main ef3e8c6, 4/31 shipped); autonomous merge policy chosen for remaining 27
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
- journal-app-design — paused — FOUNDATIONS SHIPPED (4/31 merged to origin/main ef3e8c6); next = launch autonomous mitosis run 8 from a fresh session to ship the remaining 27, relaunch-to-resume across usage windows

## State snapshot (2026-07-11)
- Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. origin/main == ef3e8c6 (4 foundation squash-merges on top of ec7b959 receipts fix); local main 4bf206e = ef3e8c6 + 1 ledger commit.
- FOUNDATIONS SHIPPED: platform-permissions, mood-catalog, design-tokens, drift-database merged (PRs #1-4, green CI). Engine proven through the full pipeline incl. force-push unblock -> green CI -> squash-merge. 27 dependents remain (whole app UI + data/domain wiring).
- Run 7 (wf_f16b0bef-2bf) parked 3 foundations on a delegated force-push permission denial; resolved by user-authorized main-thread force-push + squash-merge. Run 8 not yet launched (fresh-context discipline).
- Relaunch pre-flight each time: remove stale/empty worktree dirs, KEEP .mitosis/run.json, leave remote alone. RESIDUAL RISK: classifier may also gate the ship agent's `gh pr merge` -> fall back to main-thread merge + relaunch.
- GitHub repo renamed fireplace -> field-notes (PRIVATE); local directory still "fireplace".

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (§0 = implementation status + pre-vendored fonts)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — latest session (foundations shipped; autonomous run 8 launch command verbatim)
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches for PR reuse)
