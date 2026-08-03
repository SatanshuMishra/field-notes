---
thread: inline-photo-notes
status: paused
updated: 2026-08-02
priority: high
completion_criteria:
  - "[ ] P0 returned a verdict: the float+rotation+tape exclusion spike PASSES (no glyph touches any ink), or the float model is formally abandoned and the ladder stops at P2"
  - "[ ] Every shipped phase left note capture working on its merge commit, proven by a MEASURED fullValidationCmd on that branch, never inherited"
  - "[ ] Photos are reachable from the note composer by a user (today they are not)"
  - "[ ] A photo renders at its authored position in the note text and survives a save/reopen/edit round-trip, which the prototype never did"
  - "[ ] No schema migration was required, or one shipped as its own MSP with a successful-upgrade test and a rollback proven on a copy of a real journal"
  - "[ ] Each phase is one squash-merged PR revertible on its own, and any dropped phase left every phase beneath it green"
next_step: SUPERSEDED 2026-08-03. A rich markdown editor now PRECEDES this ladder by user directive, and P3-P5 must be re-read against flutter#82595 (no text wrap around an inline object inside an EditableText). Write the combined spec — editor first, then OQ-6 — from docs/specs/research/2026-08-02-editor-*.md and decisions/2026-08-02-markdown-source-of-truth-editor.md. LIVE CONTINUITY IS THE LOGBOOK THREAD 01KZ33PK4E5RN3G6MD458S2N5D, not this file.
branch: cut from `origin/main`; RE-READ at dispatch time, never trust this line
---

## Status
NOT STARTED. Opened 2026-08-02 out of OQ-6's resolution. No code exists, no spec is cut, no branch is
made. The model is decided and recorded; the ladder below is the plan, not a claim of progress.

## Active Goal
Let a photo be stuck into a note at a specific place in the story, with the text conforming around the
card AND its tape, so neither obstructs the other — the connection the bottom-strip model lacks.

## Next Step
Phase 0. Test-only. Prove or kill the float model in one MSP before any product code depends on it.

## The six-phase MSP ladder
Ordered by RISK, not convenience, per decisions/2026-08-02-h1-splits-by-font-risk.md. The riskiest work
sits at the TOP so it can be dropped without losing the rungs beneath it. Each phase is ONE PR, one
squash-merge, independently revertible, and each MUST leave note capture working on its merge commit.

- **P0 — Feasibility spike. TEST-ONLY, zero files under `lib/`.** A harness floating a rotated tape-framed card left and right in real text, asserting no glyph enters the exclusion box. Same shape Cluster H shipped. A red kills the float model for one PR and truncates the ladder at P2.
- **P1 — Wire photo capture into the note composer.** Picking affordance in `lib/features/capture/text/`, pass `photos:` on `TextCaptureRequest`, render through the EXISTING `InlinePhotoStrip`. No schema, no layout, no gestures. Makes photos reachable for the first time.
- **P2 — Inline anchoring via the U+FFFC sentinel.** Tape-framed cards at their place in the text, full-width block, decorative tilt only. Nth sentinel binds to Nth `entry_photos` row by `sortOrder`. The render path MUST strip unmatched sentinels so a revert degrades to P1, not to stray characters.
- **P3 — Float left/right, static.** Side assigned at insert or by a toggle; text wraps beside and continues below. Exclusion rect = AABB of (rotated card UNION both tape strips). P0's machinery enters product code here. The single biggest lift.
- **P4 — Arrange mode.** Handles appear on tapping out of the text: drag the anchor through the story, flip side, resize (aspect-locked, clamped), live throttled reflow. Write mode untouched.
- **P5 — User-controlled rotation.** Rotation handle plus rotation-aware exclusion, clamped to ~+/-15deg so the box cannot balloon. LAST because dropping it loses nothing else — P2 already shipped the tilt.

## Open Risks
- **P0 is a real gate.** If float proves unworkable, P3-P5 are abandoned and the feature ships at P2, which already delivers the narrative connection asked for. Say that out loud BEFORE starting P3.
- **flutter/flutter#159171 is OPEN** — caret/delete misbehaviour around widget spans in editable text. The one live technical risk in P2. Prove arrow-key, backspace and select-through on BOTH platforms first.
- **DO NOT MIGRATE THE DATABASE.** `schemaVersion` is 1 and `onUpgrade` unconditionally THROWS (`app_database.dart:20-37`, pinned by `app_database_test.dart:97-128`); no `drift_schemas/`, no harness, no successful-upgrade test — only the refusal is tested. This model needs none. If a phase wants one, STOP and re-plan.
- Live reflow while dragging is the main perf risk: `TextPainter.layout()` is shaping-dominated with NO incremental relayout API (flutter/flutter#92173, #132421). Throttle and cache per line.
- **Baseline is 944 on `main`.** MEASURE it on your own branch, never inherit it — stale three times historically. Predict from your own diff BEFORE running `fullValidationCmd`.
- Zero gesture-to-persisted-transform precedent in `lib/` (`StickerCard`'s tilt is static). P4 is fully greenfield.
- `gh pr merge` and `gh pr create` are BOTH denied globally — every merge is a human action, every PR goes through the pr-create tool. **CI is not evidence**; no GitHub check runs a Dart test.
- Serena has no Dart backend here (native grep/Read). **Never run `flutter test integration_test/` as a directory** — `capture_save_persist_test.dart` writes into the real journal container.

## Key Decisions
- decisions/2026-08-02-oq6-inline-anchored-photo-model.md — the model, the cap, and why the free canvas and the bottom grid were both rejected
- decisions/2026-07-28-c5-ships-as-is.md — the 6px caption this model DISSOLVES rather than implements
- decisions/2026-08-02-h1-splits-by-font-risk.md — the riskiest-at-the-top laddering precedent

## Out of Scope
- Editable text that wraps (structurally impossible in Flutter; write mode stays plain).
- Arbitrary pixel positioning. The anchor is a position in the text, never an (x, y).
- The markdown editor engine (its own spec); a WebView text layer; any `EntryPhoto.label` field; any schema migration.

## Pointers
- .claude/ledger/sessions/2026-08-02-03-prototype-design-alignment.md — the five findings, the audit citations and the spec-family corrections. READ THIS BEFORE PLANNING ANY PHASE
- docs/prototype/project/md-scrapbook.js — the prototype engine (502 lines), authoritative for the LOOK only: 210x168, white, 8px pad, square corners, two tape strips at -8deg/+7deg
- lib/features/capture/text/ — the composer P1 and P2 modify
- lib/data/database/tables.dart:36-47 — `entry_photos`, which carries this model UNCHANGED
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is 944

## Recent Sessions
- none — thread opened 2026-08-02 in sessions/2026-08-02-03-prototype-design-alignment.md
