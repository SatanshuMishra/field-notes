---
thread: journal-app-design
status: paused
updated: 2026-07-10
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: User reviews the drafted design spec (docs/superpowers/specs/2026-07-10-field-notes-design.md); on approval, decompose into MSPs via mitosis (plan-to-task-graph inside)
branch: main
---

## Status
Brainstorming through design Parts 1-3 complete and user-approved. All 14 reconciliation points resolved (decisions/2026-07-10-reconciliation-resolutions.md); client stack locked via cited research (decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift). The v1 design spec is DRAFTED at docs/superpowers/specs/2026-07-10-field-notes-design.md and passed self-review; awaiting user read. v1 = ENTIRE prototype minus server sync (local-only; sync/E2EE UI built but disabled), light-only, "Field Notes".

## Active Goal
Get the drafted v1 design spec user-approved, then produce the implementation plan / MSP decomposition.

## Next Step
User reviews the drafted spec. On approval, route implementation through the mitosis skill (SPEC-shaped, multi-MSP); commit spec + ledger when the user asks (repo has no commits yet — branch first).

## Open Risks
- macOS camera relies on the community camera_macos plugin (Flutter official camera excludes macOS) — verify before relying.
- v2 (deferred): E2EE across devices — recovery-passphrase-derived key (Argon2) + QR device-2 pairing; standalone-to-server first-merge reconciliation rule still to be finalized when v2 is specced.
- v1 forward-compat: local schema must carry stable UUID ids + updatedAt so v2 sync can migrate existing local data without a rewrite.

## Key Decisions
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions (ULID, updated_at, deleted_at, content-addressed media); version/device_id deferred
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points resolved; v1 = prototype minus sync, light-only, "Field Notes"
- decisions/2026-07-09-tech-stack.md — Flutter + SQLite both + custom REST sync + E2EE + Tailscale
- decisions/2026-07-09-standalone-first.md — app works fully without a server; sync optional
- decisions/2026-07-09-product-model.md — day/entry/memory model, 10 moods, streak, reminders, nav (gallery + streak clauses overridden by 2026-07-10 record)
- decisions/2026-07-09-design-baseline.md — Field Notes prototype is the visual baseline

## Out of Scope
- iOS (excluded — no dev account; 7-day resign pain)
- Server-side search/thumbnails (impossible under E2EE; on-device only)
- CRDTs, Postgres, MinIO, Cloudflare Tunnel, multi-user support

## Pointers
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- DesignSync project eafe8d73-b380-44be-9b2e-6431c0f35f26 — Field Notes.dc.html (the prototype)

## Recent Sessions
- sessions/2026-07-10-01-journal-app-design.md
- sessions/2026-07-09-01-journal-app-design.md
