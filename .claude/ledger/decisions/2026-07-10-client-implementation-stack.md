Status: accepted
Date: 2026-07-10
Thread: journal-app-design

## Context
The tech-stack decision (2026-07-09) locked Flutter + SQLite but left the client implementation stack open. Per the user's instruction to follow industry standards, two researcher agents validated the choices with cited 2025-2026 evidence (findings folded into the spec's References section).

## Decision
- State management: Riverpod 3.x with code generation (@riverpod). Flutter Favorite; actively released; v3 adds offline persistence + async retry; StreamProvider/AsyncNotifier consume drift .watch() streams with minimal glue; no BuildContext coupling (testable).
- Persistence: drift (typed layer over the sqlite3 package). Flutter Favorite; typed queries + native reactive .watch() + built-in migrations; single API across macOS + Android; no cloud lock-in. Escalation path if throughput ever demands: drift_sqlite_async (no rewrite).
- v1 schema carries (irrecoverable if skipped): client-generated ULID/UUIDv7 TEXT primary keys; created_at; updated_at (ms); nullable deleted_at soft-delete tombstone; SHA-256 content-addressed media (metadata + path in DB, bytes on filesystem); PRAGMA user_version.
- Deferred to the v2 sync migration (cheap lossless backfill): per-record version counter, device_id, sync-cursor bookkeeping.

## Consequences
- Rejected: Bloc (audit-grade ceremony unneeded for a solo app), GetX (not a Flutter Favorite; maintenance/anti-pattern concerns), Isar (abandoned by its author), Hive (NoSQL architecture mismatch), sqflite (no reactive/typed layer).
- LWW (not CRDTs) confirmed sufficient for single-user, 2-3 devices.
