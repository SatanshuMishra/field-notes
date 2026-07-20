# Fireplace — Project Ledger

## Goal
A personal journaling app for macOS + Android with a cozy, hand-drawn cel-shaded aesthetic (prototype "Field Notes"). Daily entries as voice/video/text plus photo "memories," one mood-flower per day, streaks, daily reminders. Local-first, optionally syncing end-to-end-encrypted through the user's self-hosted Arch Linux server. Open-source on GitHub (repo SatanshuMishra/field-notes, private for now).

## Constraints
- No paid Apple/Google developer account; manual sideload/install. macOS + Android only (no iOS).
- Works fully standalone with no server; sync is an optional v2 layer.
- Fast, secure (E2EE), robust; offline-capable; reachable via Tailscale.
- Binary assets must be human-provided + committed (harness blocks agent/main-thread downloads).

## Active Decisions
- decisions/2026-07-20-reminders-android-desugaring-scope.md — reminders' fileScope expanded by one file (android/app/build.gradle.kts) so it ships the flutter_local_notifications desugaring config in the same PR; receipts CI runs no Android build and cannot catch this
- decisions/2026-07-19-symlink-guard-defect.md — all 7 `~/.claude/lib/superpowers-parallel` CLIs were silent no-ops under the lib symlink (main() guard compared import.meta.url to a literal argv[1]); fixed with the realpath idiom. The engine logs NOTHING on this path, so pre-flight the fold CLI's stdout before EVERY launch
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
- journal-app-design — paused — 20/31 merged (origin/main 153e7eb), no open PRs. Main reconciled; reminders plan REWRITTEN and relaunch fully staged but deliberately not launched (context). Next: re-run fold pre-flight, then launch with mergePolicy "human-gated" to reach 21/31.

## State snapshot (2026-07-20)
- Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. origin/main == 153e7eb (20 squash-merges + ledger). Local main RECONCILED 0/0, tree clean.
- RELAUNCH IS STAGED, NOT LAUNCHED. reminders.plan.md rewritten against the recovered review findings; all 3 pre-flight checks green. Launch block: sessions/2026-07-11-03 lines 38-62 with mergePolicy "human-gated".
- Relaunch proven SAFE: skip/build is decided by a LIVE `gh pr list --state merged` reconcile, not by run.json `status`. The 17 merged-but-"planned" units are skipped at the top of runUnit(). Stale status/resumePoint fields are inert.
- NO ANDROID SDK on this machine — `flutter build apk` is impossible, and receipts CI never builds Android. File-content assertion is the only receipt for the new desugaring task; do NOT add an Android build to receipts.config.json.
- Plan-review findings are NEVER persisted by the engine; recover them from the harness journal at ~/.claude/projects/<slug>/<session>/subagents/workflows/<runId>/journal.jsonl.
- 20/31 SHIPPED: the 14 foundations + mood-picker (#15), sound-effects (#16), streak-service (#18), data-management (#17), capture-core (#19), entry-cards (#20). No PRs open. 11 unbuilt dependents remain.
- BATCH 2 (wf_1a14ffc9-038): reuse fired, no Decompose, entry-cards resumed at `execute` off its fixed plan and the harness single-ownership fix held through to merge. reminders parked at plan-review (review did not converge in 3 iterations).
- THE SYMLINK DEFECT (decisions/2026-07-19-symlink-guard-defect.md): all 7 CLIs under ~/.claude/lib/superpowers-parallel/ were silent no-ops (exit 0, zero bytes) because the main() guard compares a realpath to a literal argv[1] path. It made the engine silently full-re-decompose with NO log line — engine logs CANNOT catch it. Fixed in all 7; THE FIX IS UNCOMMITTED in the .windful-ocean working tree.
- LESSONS: exit code 0 is NOT evidence a Node CLI ran — pre-flight the fold CLI's stdout before EVERY launch. `result.shipped` is MISLEADING — verify via `gh pr list --state open`. pubspec.yaml conflicts are systemic (merge one-at-a-time + union). Classifier blocks DELEGATED gh create/merge but ALLOWS the main thread with per-batch consent. Investigate run `failures` rather than trusting them: batch 2's `git branch -f` security warning was a proven false alarm (the branch did not previously exist).
- GitHub repo renamed fireplace -> field-notes (PRIVATE); local directory still "fireplace".

## Pointers
- .claude/ledger/plans/2026-07-19-next-round.md — TURNKEY plan; Stages A-F DONE, resume at F3 (launch)
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 design spec (§0 = implementation status + pre-vendored fonts)
- docs/design/prototype-analysis.md — full prototype extraction + 14 reconciliation points
- .claude/ledger/threads/journal-app-design.md — current line of work
- .claude/ledger/sessions/2026-07-19-03-journal-app-design.md — latest (symlink CLI defect found+fixed; batch 2 -> 20/31; reminders parked)
- .claude/ledger/sessions/2026-07-19-02-journal-app-design.md — batch 2 staging + verification
- .claude/ledger/sessions/2026-07-16-02-journal-app-design.md — fold-defect root cause; run.json fixed+trimmed to batch 1
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch block (contract args; flip mergePolicy to "human-gated")
- .mitosis/run.json — STAGED for batch 2 (21 MSPs; base line + entry-cards park delta = 2 lines)
- .mitosis/run.json.pristine-backup — durable 31-MSP source of truth (gitignored, uncommitted)
- .mitosis/batch-tooling/ — trim + verify scripts for deriving future batches
- .mitosis/entry-cards.plan.md — plan carrying the harness-ownership defect
