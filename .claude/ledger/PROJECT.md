# Fireplace — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server. Open-source on GitHub (repo SatanshuMishra/field-notes, private for now).

## Constraints
- No paid Apple/Google developer account; manual sideload/install. macOS + Android only (no iOS).
- Works fully standalone with no server; sync is an optional v2 layer.
- Fast, secure (E2EE), robust; offline-capable; reachable via Tailscale.
- Binary assets must be human-provided + committed (harness blocks agent/main-thread downloads).

## Active Decisions
- decisions/2026-07-12-direct-ship-built-msps.md — ship the 3 ALREADY-BUILT foundations via main-thread push+PR+squash-merge (not a mitosis relaunch); engine reserved for building the ~24 unbuilt dependents (Option B, fresh session post-handoff)
- decisions/2026-07-12-human-gated-merge-policy.md — autonomous is structurally blocked by the harness classifier (delegated agents can't self-merge); switched to mitosis "human-gated" mode + main-thread merge with per-session consent, layer-by-layer (still governs Option B builds)
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
- journal-app-design — paused — 7/31 shipped (5e73d67); Option A done (3 built foundations direct-shipped by main thread); next = Option B: human-gated mitosis relaunch to BUILD the 24 unbuilt dependents, layer-by-layer

## State snapshot (2026-07-12)
- Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. origin/main == 5e73d67 (7 squash-merges); local main synced (ledger commits rebased on top).
- 7/31 SHIPPED: platform-permissions, mood-catalog, design-tokens, drift-database (#1-4) + domain-models (#5), flower-svg-set (#6), sticker-widget-kit (#7). 24 unbuilt dependents remain.
- LESSON (this session): the 3 second-layer foundations were already BUILT (by prior autonomous run); shipping them needed only main-thread push+PR+squash — NOT a multi-hour mitosis relaunch. mitosis ship step adds no receipt metadata, so a plain push passes receipts CI. Relaunching the engine for already-built code kept failing (autonomous classifier; wf_a1015521-c4c killed on process exit).
- OPTION B (next, fresh session): relaunch mitosis human-gated to BUILD the 24 dependents against 5e73d67; agents publish green PRs + stop; main thread merges. Pre-flight: KEEP run.json; optionally prune the 3 now-merged worktrees; launch from a FRESH context. Do NOT resume wf_a1015521-c4c.
- GitHub repo renamed fireplace -> field-notes (PRIVATE); local directory still "fireplace".

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (§0 = implementation status + pre-vendored fonts)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
- .claude/ledger/sessions/2026-07-12-02-journal-app-design.md — latest session (Option A: 3 direct-shipped; direct-vs-engine lesson)
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch block (Option B: set mergePolicy "human-gated")
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches for PR reuse)
