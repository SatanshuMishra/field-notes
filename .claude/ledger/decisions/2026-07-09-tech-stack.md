Status: accepted
Date: 2026-07-09
Thread: journal-app-design

## Context
Personal journaling app for macOS + Android (iOS excluded), self-hosted sync to the user's Arch Linux box, no paid developer account. Must be fast, secure, robust, and work offline. Two researcher agents investigated client stack and backend/sync/security (high confidence, cited).

## Decision
One Flutter codebase for macOS + Android. SQLite on client AND server. Custom lightweight REST sync (per-record last-writer-wins with version + device-id). Media blobs on the server filesystem, content-addressed by SHA-256. Client-side libsodium E2EE (server stores ciphertext only; thumbnails + search happen on-device). Tailscale mesh + Caddy TLS. Server runs as Docker Compose.

## Consequences
- Rejected: two native apps (Swift+Kotlin) — duplicates correctness-critical crypto/sync/DB, corruption risk; KMP+CMP — community-only macOS camera/notifications; Postgres/PowerSync/ElectricSQL/CouchDB — multi-user scale not needed; MinIO — 2025-26 licensing collapse; Cloudflare Tunnel — public shape, we want a private mesh.
- Accepted trade-off: macOS camera rides the community camera_macos plugin (Flutter's official camera excludes macOS).
- Daily reminders use on-device local notifications — no push server or dev account needed.
