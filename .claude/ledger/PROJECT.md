# Fireplace — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server. Open-source on GitHub (repo SatanshuMishra/field-notes, private for now).

## Constraints
- No paid Apple/Google developer account; manual sideload/install. macOS + Android only (no iOS).
- Works fully standalone with no server; sync is an optional v2 layer.
- Fast, secure (E2EE), robust; offline-capable; reachable via Tailscale.
- Binary assets must be human-provided + committed (harness blocks agent/main-thread downloads).

## Active Decisions
- decisions/2026-07-12-human-gated-merge-policy.md — autonomous is structurally blocked by the harness classifier (delegated agents can't self-merge); switched to mitosis "human-gated" mode + main-thread merge with per-session consent, layer-by-layer
- decisions/2026-07-11-foundations-shipped-autonomous-policy.md — force-push authorized; 4 foundation PRs merged (origin/main ef3e8c6, 4/31 shipped); autonomous-for-27 part SUPERSEDED by 2026-07-12-human-gated-merge-policy.md
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
- journal-app-design — paused — 4/31 shipped (ef3e8c6); autonomous proven blocked (classifier bars agent self-merge); next = HUMAN-GATED relaunch (agents publish PRs, main-thread merges), layer-by-layer

## State snapshot (2026-07-12)
- Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. origin/main == ef3e8c6 (4 foundation squash-merges); local HEAD 07e38fc (ef3e8c6 + ledger commits).
- 4/31 SHIPPED: platform-permissions, mood-catalog, design-tokens, drift-database (PRs #1-4, green CI). 27 dependents remain.
- AUTONOMOUS BLOCKED: run wf_b72ceb41-dd5 shipped 0 — the harness classifier bars delegated ship agents from self-merging, proactively (before publish). Pivoted to human-gated (decisions/2026-07-12-human-gated-merge-policy.md). domain-models/flower-svg-set/sticker-widget-kit BUILT + tested on local branches, unshipped.
- Next relaunch: mergePolicy "human-gated"; agents publish green PRs + stop; main thread merges (authorized). Pre-flight: KEEP run.json; PRESERVE the 3 ship worktrees (reused idempotently); leave remote alone; launch from a FRESH context.
- GitHub repo renamed fireplace -> field-notes (PRIVATE); local directory still "fireplace".

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (§0 = implementation status + pre-vendored fonts)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
- .claude/ledger/sessions/2026-07-12-01-journal-app-design.md — latest session (autonomous blocked; human-gated pivot)
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — verbatim relaunch block (set mergePolicy to "human-gated")
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches for PR reuse)
