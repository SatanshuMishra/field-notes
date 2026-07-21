---
thread: journal-app-design
status: paused
updated: 2026-07-21
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: FRESH context. Confirm pristine (tree clean, origin/main...main 0 0, run.json 6 lines, no worktrees/branches for the 5 parked units), run the 3 pre-flights, then LAUNCH the same verbatim 2026-07-11-03 block (mergePolicy "human-gated", NOT resumeFromRunId). Validate+merge each PR promptly; capture-* one-at-a-time with regen; shell-nav last.
branch: main
---

## Status
26/31 merged, 0 open PRs. Final run wf_2a283cde-9d0 shipped 3 screens (today #24, calendar #25, search
#26 — each locally validated 515/539/566 tests) then hit the SESSION USAGE LIMIT and ended `partial`,
parking the last 5. Repo left PRISTINE and relaunch-ready (cleaned, reconciled, Stage-F'd).

## Active Goal
Complete the last 5 Field Notes v1 MSPs (settings-screen, capture-photo/voice/video, shell-nav-
integration) via ONE fresh-context relaunch-to-resume, merging PRs promptly, for 31/31.

## Next Step
Fresh session: verify pristine, pre-flight (guard 7/7, fold CLI stdout=31 msps, main 0/0), launch the
verbatim 2026-07-11-03 block. The 26 merged fast-skip via the LIVE `gh pr list --state merged` reconcile;
settings-screen resumes at plan-review (preserves its fixed plan); capture-*/shell-nav rebuild fresh
(their final parks were NOT persisted — the usage limit failed every park-checkpoint).

## Open Risks
- MITOSIS RELAUNCH MUST BE FRESH-CONTEXT (runs die when launched near-full; proven). This is why this
  session handed off instead of relaunching.
- CI IS HOLLOW FOR DART. Run fullValidationCmd locally (FOREGROUND) against each PR head before EVERY
  merge. See decisions/2026-07-20-ci-gates-are-hollow-for-dart.md.
- capture-photo/voice/video each add pub deps AND regenerate macos/Flutter/GeneratedPluginRegistrant.swift
  → merge ONE-AT-A-TIME with `flutter pub get` regen; pubspec.yaml also systemic. shell-nav merges last.
- settings-screen's plan re-review may re-park with a NEW finding (blocks ONLY shell-nav; other 4 ship).
- The run can hit the usage limit again mid-relaunch → cheap relaunch-to-resume on the SAME run.json.
- `.mitosis/` is gitignored: staged run.json + batch-tooling live only on this machine.

## Key Decisions
- decisions/2026-07-20-one-run-completion-frontier-train.md — one run completes the app (frontier-train);
  the engine now also CREATES the PRs itself in human-gated mode (observed this session; I only merge)
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — local validation before every merge
- decisions/2026-07-19-pubspec-parallel-conflict.md — systemic pubspec conflict; serial union merges
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact base line
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main before EVERY relaunch
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated + main-thread/user merge under consent
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories
  gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell). The reminders
  day-2 pre-arm follow-up MSP is post-31 work (needs a NEW msp id; not in this run).

## Pointers
- .mitosis/run.json — STAGED 31-msp manifest (6 lines: base + today/settings park deltas + 3 built)
- .mitosis/run.json.pristine-backup — untouched 31-MSP source (md5 a7ca0a4f…); gitignored
- .mitosis/settings-screen.plan.md — FIXED parked plan (preserve; resumes at plan-review)
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — VERBATIM launch block (mergePolicy human-gated)
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- GitHub: https://github.com/SatanshuMishra/field-notes (PRIVATE). Project name is field-notes.

## Recent Sessions
- sessions/2026-07-21-01-journal-app-design.md — final run: 26/31, usage-limit parked 5, repo pristine
- sessions/2026-07-20-03-journal-app-design.md — 23/31; engine verified; final run staged, not launched
- sessions/2026-07-20-02-journal-app-design.md — reminders shipped, 21/31; CI found hollow
