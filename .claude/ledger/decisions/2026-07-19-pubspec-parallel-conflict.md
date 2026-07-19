Status: accepted
Date: 2026-07-19
Thread: journal-app-design

## Context
Batch 1's four leaf MSPs were "independent" but three of them each appended a dependency block to `pubspec.yaml`. After mood-picker (#15) and sound-effects (#16) squash-merged, data-management (#17) — CLEAN at open — went DIRTY: `git merge-tree` showed the ONLY conflict is `pubspec.yaml` (pubspec.lock auto-merges). This is structural: any parallel batch whose MSPs add pub deps collides on `pubspec.yaml` at merge time, regardless of dependency-graph independence.

## Decision
Treat pubspec.yaml conflicts as expected, not exceptional. Merge a batch's PRs ONE AT A TIME; after the first, each subsequent PR that adds deps is resolved by a UNION merge (keep every branch's dependency additions, then `flutter pub get` to regenerate pubspec.lock, push, confirm CLEAN, merge). Delegate the resolution to a subagent (it is code work); the main thread merges under per-batch consent.

## Consequences
No engine change; the ship-stage rebase does not pre-resolve cross-PR pubspec collisions because sibling PRs are not yet merged when each branch is built. Adds one delegated union-merge per additional dep-adding PR per batch — cheap and mechanical. Rejected alternative: forcing a single owner for pubspec.yaml per batch (serializes dep additions, defeats parallelism). Applies to every future batch; batch-2's reminders PR will predictably need this after entry-cards merges.
