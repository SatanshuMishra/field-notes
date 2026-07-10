Status: accepted
Date: 2026-07-09
Thread: journal-app-design

## Context
The original goal was device-to-device sync via a server. The user clarified that the app must be fully usable with NO server configured.

## Decision
The app works fully STANDALONE with no server: local capture, storage, viewing, moods, streaks, and reminders all function offline on-device. Sync is an OPTIONAL layer enabled from the Settings page. Without a server, data simply does not sync across devices. First run defaults to standalone; the nav status ("On this device only" vs "Synced to home") is dynamic.

## Consequences
- Natural fit for the local-first architecture; the sync layer is pluggable, not core.
- Open: when a second standalone device later connects to a server, two independent histories merge — entries have distinct IDs (union merges cleanly); per-day mood conflicts resolve by last-writer-wins on timestamp. Reconciliation rule to be finalized in the spec.
