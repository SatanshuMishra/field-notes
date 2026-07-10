Status: accepted
Date: 2026-07-10
Thread: journal-app-design

## Context
All 14 prototype-vs-requirements reconciliation points (docs/design/prototype-analysis.md) resolved by the user, unblocking the design spec. Includes the 4 starred: E2EE/pairing UX, app name, v1 scope, dark mode.

## Decision
- Nav (#1,#4): keep the prototype's 5 destinations — Today, Calendar, + Capture, Garden, Search — plus Settings via gear. Calendar grid and ambient Garden meadow are both kept as distinct screens.
- Browse (#2): keep the prototype "Search / Your days" day-list; do NOT build an entry-level filter feed.
- Day view (#3): modal overlay on BOTH macOS and Android, per the prototype (Android hardware/gesture back dismisses the modal).
- Memories (#5,#6): photos attach to entries inline only ("add memory"); day-level pooled Memories gallery DROPPED for v1. No standalone photo-only entry. Streak therefore collapses to "any entry that day" (a photo always implies an entry).
- Moods (#7): 10 confirmed; Wilting rose / Thistle are ambient-garden-only, not selectable.
- Name (#12): "Field Notes" is final. Local dir "fireplace" is stale; GitHub repo already renamed.
- Theme (#14): light-only for v1.
- v1 scope (#13): the ENTIRE prototype EXCEPT server sync. Local-only storage. Sync/server/E2EE settings are built as UI but DISABLED/inert; storage mode fixed to "On this device." v2 adds real sync.
- Sync/E2EE design (v2 targets): frequency simplified to Automatic <-> Manual (#8); status shown dynamically, first-run standalone (#10); key = recovery-passphrase-derived via Argon2 + QR pairing for device 2 (#9).
- Video (#11): 30-minute hard cap; informative soft nudges at 5, 10, 20 min.

## Consequences
- v1 ships with NO networking or crypto code: pure local-first Flutter + SQLite + filesystem blobs + local notifications.
- Overrides decisions/2026-07-09-product-model.md: pooled Memories gallery removed; streak simplifies to entry-only.
- Real E2EE/pairing/sync deferred to v2; v1 only renders their disabled UI shell.
