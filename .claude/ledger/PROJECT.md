# Fireplace — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server. Open-source on GitHub (repo SatanshuMishra/field-notes, private for now).

## Constraints
- No paid Apple/Google developer account; manual sideload/install. macOS + Android only (no iOS).
- Works fully standalone with no server; sync is an optional v2 layer.
- Fast, secure (E2EE), robust; offline-capable; reachable via Tailscale.
- Binary assets must be human-provided + committed (harness blocks agent/main-thread downloads).

## Active Decisions
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main onto origin/main before EVERY mitosis relaunch; the engine cuts worktrees from the bare LOCAL `main` ref (mitosis.js:946/:1114), so local main must contain every merged dependency
- decisions/2026-07-12-direct-ship-built-msps.md — ship the 3 ALREADY-BUILT foundations via main-thread push+PR+squash-merge (not a mitosis relaunch); engine reserved for building the unbuilt dependents (Option B)
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
- journal-app-design — paused — 14/31 merged (origin/main 66a12a46; #14 core-providers merged this session). 17 remain, ALL parked by run wf_bfb12095-952's session-limit death (0 published). Next = relaunch human-gated from a CLEAN context; entry-cards carries a deterministic add/add task-graph defect

## State snapshot (2026-07-16)
- Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. origin/main == 66a12a46 (14 squash-merges); local main b359ddc reconciled (7 ledger commits rebased atop origin/main; CONTAINS core-providers).
- 14/31 SHIPPED: platform-permissions, mood-catalog, design-tokens, drift-database (#1-4), domain-models (#5), flower-svg-set (#6), sticker-widget-kit (#7), app-shell (#8), feedback-motion-kit (#9), settings-fields-kit (#10), journal-repository (#11), settings-repository (#12), media-store (#13), core-providers (#14). 17 unbuilt downstream dependents remain.
- BLOCKER (2026-07-16): entry-cards has a DETERMINISTIC add/add conflict on `test/features/entry_cards/support/entry_cards_harness.dart` — created independently by both its `task-media-resolver-harness` and `task-note-body`. A task-graph ownership defect; re-parks every relaunch until the plan gives that file one owner. Blocks 5 screen MSPs.
- LESSON (2026-07-14, re-confirmed 2026-07-16): the mitosis `result.shipped` array is MISLEADING — it lists only done-oracle fast-skips (already-merged), NOT PRs the run just published. Verify via `gh pr list --state open`. Also: runs die on the account session limit (~2h/window) AND when launched from a near-full context or when their launching process exits; the classifier gates every main-thread `gh pr merge`, needing explicit per-batch consent.
- OPTION B (next, fresh session): relaunch mitosis human-gated against 66a12a46 to build the 17 remaining MSPs (capture-*, entry-cards, mood-picker, screens, streak-service, sound-effects, reminders, data-management, garden-screen, settings-screen, shell-nav-integration); agents publish green PRs + stop; main thread merges (re-confirm consent). Pre-flight: reconcile local main; KEEP run.json; leftover worktrees safe; launch from FRESH context. Do NOT resume any prior run id.
- GitHub repo renamed fireplace -> field-notes (PRIVATE); local directory still "fireplace".

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (§0 = implementation status + pre-vendored fonts)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
- .claude/ledger/sessions/2026-07-16-01-journal-app-design.md — latest session (merged #14 -> 14/31; 3 dead runs, 0 published; entry-cards defect; full parked breakdown)
- .claude/ledger/sessions/2026-07-14-01-journal-app-design.md — 8 -> 13/31; layer-1+repo+media complete; shipped-array lesson
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch block (contract args; flip mergePolicy to "human-gated")
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches for PR reuse)
- .mitosis/entry-cards.plan.md — plan carrying the harness-ownership defect
