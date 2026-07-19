# Fireplace — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server. Open-source on GitHub (repo SatanshuMishra/field-notes, private for now).

## Constraints
- No paid Apple/Google developer account; manual sideload/install. macOS + Android only (no iOS).
- Works fully standalone with no server; sync is an optional v2 layer.
- Fast, secure (E2EE), robust; offline-capable; reachable via Tailscale.
- Binary assets must be human-provided + committed (harness blocks agent/main-thread downloads).

## Active Decisions
- decisions/2026-07-19-entry-cards-fix-and-batch-2.md — batch 2 = capture-core + entry-cards + reminders; entry-cards fixed-and-included (harness single-ownership); garden-screen deferred to batch 3
- decisions/2026-07-19-pubspec-parallel-conflict.md — pubspec.yaml conflicts are systemic; merge batch PRs one-at-a-time + union-merge each dep-adding PR (regen lock via flutter pub get)
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json MUST be one compact line (pretty-print breaks `foldRunManifest` -> silent full re-decompose + overwrite); engine has NO MSP-filter input, so scope batches by out-of-band trim from the pristine backup; batch 1 = 4 leaf MSPs
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
- journal-app-design — paused — 18/31 merged (origin/main 326686a), no open PRs. Batch 2 (capture-core + entry-cards + reminders) is user-approved, staged, and verified GO. ONLY the launch remains — run it as the first major action of a fresh session per plans/2026-07-19-next-round.md Stage F3.

## State snapshot (2026-07-19)
- Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. origin/main == 326686a (18 squash-merges). Local main RECONCILED (11 ahead / 0 behind).
- 18/31 SHIPPED: the 14 foundations + mood-picker (#15), sound-effects (#16), streak-service (#18), data-management (#17). No PRs open. 13 unbuilt dependents remain.
- BATCH 1 VALIDATED THE FOLD FIX: run wf_8a56361d-387 completed with reuse FIRED (engine skipped fresh Decompose, confirmed at runtime) — the silent re-decompose that burned every prior window did not recur.
- BATCH 2 IS STAGED AND VERIFIED GO (2026-07-19-02): entry-cards plan fixed (harness single-ownership), batch-tooling merged set corrected to 18, run.json re-derived from pristine (21 msps, 2 lines, park delta retained), stale worktrees/branches/graph artifacts cleaned, full assertion block passed. Launch only — do NOT re-stage or resume a prior run id.
- LESSONS: `result.shipped` is MISLEADING — verify via `gh pr list --state open`. pubspec.yaml conflicts are systemic (merge one-at-a-time + union). Classifier blocks DELEGATED gh create/merge but ALLOWS the main thread with per-batch consent. Launch from a FRESH context; the engine REUSES existing worktrees so clean batch leftovers first.
- GitHub repo renamed fireplace -> field-notes (PRIVATE); local directory still "fireplace".

## Pointers
- .claude/ledger/plans/2026-07-19-next-round.md — TURNKEY plan; Stages A-F DONE, resume at F3 (launch)
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (§0 = implementation status + pre-vendored fonts)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
- .claude/ledger/sessions/2026-07-19-02-journal-app-design.md — latest (tail closed -> 18/31; batch 2 staged + verified GO; launch deferred to fresh context)
- .claude/ledger/sessions/2026-07-16-02-journal-app-design.md — fold-defect root cause; run.json fixed+trimmed to batch 1
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch block (contract args; flip mergePolicy to "human-gated")
- .mitosis/run.json — STAGED for batch 2 (21 MSPs; base line + entry-cards park delta = 2 lines)
- .mitosis/run.json.pristine-backup — durable 31-MSP source of truth (gitignored, uncommitted)
- .mitosis/batch-tooling/ — trim + verify scripts for deriving future batches
- .mitosis/entry-cards.plan.md — plan carrying the harness-ownership defect
