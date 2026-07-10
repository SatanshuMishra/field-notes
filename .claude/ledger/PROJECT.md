# Fireplace — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype named "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, and daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server.

## Constraints
- No paid Apple/Google developer account; manual sideload/install acceptable. macOS + Android only (no iOS).
- Must work fully standalone with no server; sync is an optional layer.
- Must be fast, secure (E2EE), robust; work offline; reachable anywhere via Tailscale.
- Open-source on GitHub; server self-hosted via Docker Compose on Arch Linux.

## Active Decisions
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; ULID/updated_at/deleted_at/content-addressed media in v1; version/device_id deferred to v2
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 reconciliation points resolved; v1 = prototype minus sync, light-only, "Field Notes"
- decisions/2026-07-09-tech-stack.md — Flutter + SQLite both sides + custom REST sync + E2EE + Tailscale + Docker Compose
- decisions/2026-07-09-standalone-first.md — app works fully without a server; sync optional
- decisions/2026-07-09-product-model.md — day/entry/memory model, 10 moods, streak, reminders, navigation
- decisions/2026-07-09-design-baseline.md — Field Notes prototype is the canonical visual baseline

## Threads
- journal-app-design — paused — v1 design spec drafted (docs/superpowers/specs/2026-07-10-field-notes-design.md); awaiting user review, then mitosis

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (draft, awaiting user review)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
