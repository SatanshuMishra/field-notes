# Mitosis Round Plan — Batch 2 (2026-07-19)

Turnkey execution plan for the next round. A fresh session executes this file top-to-bottom.
The ONLY interactive gates are user consents: (1) merge consent per PR, (2) consent for the
destructive worktree/branch cleanup in Stage F.

## Ground-truth snapshot (verified 2026-07-19)

| Fact | Value |
|---|---|
| origin/main | 6ce4189 (16/31 MSPs merged, PRs #1-#16) |
| Open PR #17 | data-management, branch msp/data-management-integration @8cc274d (local == remote), CI green on stale base, DIRTY on pubspec.yaml vs main |
| Open PR #18 | streak-service, branch msp/streak-service-integration @211fb5c, MERGEABLE, CI green (receipts SUCCESS 2026-07-19T18:44:44Z + pr-title-lint SUCCESS) |
| Local main | b35ee7a — 9 ledger-only commits ahead of origin/main, 2 behind |
| run.json | still batch-1 trim (18 msps); MUST be re-derived from pristine for batch 2 |
| Pristine manifest | .mitosis/run.json.pristine-backup — 31 msps + ONE trailing park delta (entry-cards, stage execute) |
| main pubspec deps beyond skeleton | audioplayers ^6.8.1 (from #16) |
| #17 branch pubspec adds | archive ^4.0.9, file_picker ^11.0.2, share_plus ^12.0.2 (lacks audioplayers -> the conflict) |

Re-verify before starting (all from /Users/satanshumishra/Documents/DevLabs/fireplace):

```bash
git fetch origin
gh pr list --state open --json number,headRefName,mergeable
git log --oneline origin/main -3
git rev-list --left-right --count main...origin/main
```

---

## Stage A — Finish the batch-1 tail (16/31 -> 18/31)

### A1. Merge #18 streak-service FIRST (it is clean; no pubspec overlap)

streak-service fileScope has NO pubspec.yaml, so it cannot re-dirty #17. Merging it first means
the #17 conflict is resolved exactly once against final main.

```bash
gh pr checks 18
```

If receipts + pr-title-lint both pass (they did at 18:44Z): obtain user consent, then

```bash
gh pr merge 18 --squash
```

If CI is red: delegate a fix subagent scoped to branch msp/streak-service-integration (worktree
/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/streak-service/integration),
re-run CI, then merge under consent.

### A2. Fix + merge #17 data-management (the pubspec.yaml union)

Delegate to a subagent (exact brief):

1. `cd /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/data-management/integration`
2. `git fetch origin` then confirm `git rev-parse HEAD` == `git rev-parse origin/msp/data-management-integration` (8cc274d). If not, `git reset --hard origin/msp/data-management-integration` (leftover worktree aligning to the published tip).
3. `git merge origin/main` — expect conflict in pubspec.yaml (pubspec.lock may also conflict; it gets regenerated in step 5, so resolve it any way that lets the merge continue).
4. Resolve pubspec.yaml as the UNION: final `dependencies:` block must contain BOTH sides — keep everything already there plus `audioplayers: ^6.8.1` (main side) AND `archive: ^4.0.9`, `file_picker: ^11.0.2`, `share_plus: ^12.0.2` (branch side). Keep main's side for any assets/fonts hunks (sound-effects added `assets/sounds/`). Do not change any version.
5. `export PATH="/opt/homebrew/bin:$PATH" && flutter pub get` (regenerates pubspec.lock with the union).
6. `export PATH="/opt/homebrew/bin:$PATH" && flutter test` — full suite must pass locally.
7. `git add pubspec.yaml pubspec.lock && git commit` (conclude the merge commit; a merge, NOT a rebase — no force-push needed).
8. `git push origin msp/data-management-integration`

Then main thread: wait for CI (background poll), confirm `gh pr view 17 --json mergeable` says MERGEABLE, obtain user consent, and

```bash
gh pr checks 17
gh pr merge 17 --squash
```

### A3. Confirm the tail is done

```bash
git fetch origin
gh pr list --state open        # must be EMPTY
git log --oneline origin/main -3   # two new squash commits on top of 6ce4189
```

State is now 18/31 merged.

---

## Stage B — Reconcile local main onto origin/main (MANDATORY pre-relaunch)

Per decisions/2026-07-16-pre-relaunch-main-reconciliation.md: the engine cuts worktrees from the
bare LOCAL main ref (mitosis.js:946/:1114). Local main carries ledger-only commits — rebase them.

```bash
cd /Users/satanshumishra/Documents/DevLabs/fireplace
git status --porcelain          # must be clean
git fetch origin
git rebase origin/main main
git merge-base --is-ancestor "$(git rev-parse origin/main)" "$(git rev-parse main)" && echo RECONCILED
```

`RECONCILED` must print. The rebase replays the ledger commits; it is non-destructive (unpushed
local commits only, no force-push).

---

## Stage C — Batch 2 derivation (from the pristine 31-MSP graph, at 18/31 merged)

Merged-18 set: design-tokens, mood-catalog, platform-permissions, drift-database,
sticker-widget-kit, flower-svg-set, domain-models, settings-fields-kit, feedback-motion-kit,
app-shell, media-store, journal-repository, settings-repository, core-providers, mood-picker,
sound-effects, streak-service, data-management.

Unmerged MSPs and dispatchability (deps computed from run.json.pristine-backup):

| MSP | dependsOn | Dispatchable at 18/31 | Adds pub deps | Batch 2? |
|---|---|---|---|---|
| capture-core | core-providers, journal-repository, media-store, domain-models, sticker-widget-kit, feedback-motion-kit | YES | no (no pubspec.yaml in fileScope) | YES |
| entry-cards | domain-models, media-store, sticker-widget-kit, design-tokens, feedback-motion-kit | YES | yes: just_audio, video_player | YES (after Stage D fix) |
| reminders | settings-repository, journal-repository, core-providers, domain-models, platform-permissions | YES | yes: flutter_local_notifications, timezone | YES |
| garden-screen | core-providers, journal-repository, flower-svg-set, mood-catalog, design-tokens, feedback-motion-kit | YES | no | DEFER to batch 3 |
| capture-photo | capture-core, ... | no (capture-core) | yes | batch 3 |
| capture-voice | capture-core, ... | no (capture-core) | yes | batch 3 |
| capture-video | capture-core, ... | no (capture-core) | yes | batch 3 |
| today-screen | entry-cards, capture-core, ... | no | no | batch 3+ |
| day-detail | entry-cards, capture-core, ... | no | no | batch 3+ |
| calendar-screen | day-detail, ... | no | no | batch 4 |
| search-screen | day-detail, ... | no | no | batch 4 |
| settings-screen | reminders, ... | no | no | batch 3+ |
| shell-nav-integration | 12 deps incl. all screens | no | no | final |

**Batch 2 = capture-core, entry-cards, reminders (3 MSPs).**

Rationale:
- All three are on the critical path: capture-core + entry-cards gate today-screen and day-detail
  (and capture-core gates all three recorders); reminders gates settings-screen. garden-screen
  gates ONLY the terminal shell-nav-integration, so deferring it delays nothing.
- Conservative window sizing: entry-cards is the largest unit (8-task graph) and capture-core is
  comparable; three units (two heavy + one light) is the prudent load for one ~2h window given
  batch 1 (4 lighter units) filled its window. entry-cards resumes at stage execute (Plan +
  plan-review skipped), which claws back some budget.
- garden-screen's Jul-15 artifacts are unverified (reviewed while the safety classifier was down,
  per sessions/2026-07-16-02); deferring it gets a clean fresh plan in batch 3.

---

## Stage D — entry-cards: fix the structural defect (DECISION: fix now, include in batch 2)

### Root cause (verified against the artifacts)

- The task graph (.mitosis/entry-cards.plan.graph.json) is correct on ownership: fileScope for
  `test/features/entry_cards/support/entry_cards_harness.dart` belongs ONLY to task
  media-resolver-harness; note-body's fileScope is just note_body.dart + note_body_test.dart with
  deps=[] (wave 1).
- BUT note-body's task fullText embeds the plan's Task 4 test code, which contains
  `import '../support/entry_cards_harness.dart';`. The wave-1 note-body worker's worktree lacked
  the harness, so the worker authored its own out-of-scope 14-line copy (commit 81173a9) while
  media-resolver-harness authored the real 137-line version (commit 78474d2, merged as de79f13)
  -> deterministic add/add at integration merge -> engine halt + park.

### The fix (edit .mitosis/entry-cards.plan.md — two edits)

**Edit 1 — make Task 4's test self-contained (removes the hidden cross-task file dependency).**
In "Task 4: NoteBody (text card body)", Step 1, replace the ENTIRE code block for
`test/features/entry_cards/cards/note_body_test.dart` with:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';

Widget noteBodyHarness(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
}

void main() {
  group('NoteBody', () {
    testWidgets('renders the note text in the serif body style',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        noteBodyHarness(const NoteBody(text: 'a quiet morning')),
      );

      final Text text = tester.widget<Text>(find.text('a quiet morning'));
      expect(text.style!.fontFamily, TypographyTokens.serif);
    });

    testWidgets('shows an empty-note affordance for blank text',
        (WidgetTester tester) async {
      await tester.pumpWidget(noteBodyHarness(const NoteBody(text: '   ')));

      expect(find.text('Empty note'), findsOneWidget);
    });
  });
}
```

(The only changes: the `import '../support/entry_cards_harness.dart';` line is GONE, a local
`noteBodyHarness` replaces `cardHarness`. Nothing else in Task 4 changes.)

**Edit 2 — add a guard bullet to "Global Constraints" (defense in depth):**

> - `test/features/entry_cards/support/entry_cards_harness.dart` is created by Task 2 and ONLY
>   Task 2. No other task may create or modify it. Never create any file outside your task's
>   declared Files list: if a support file your test imports is absent from your worktree, that is
>   a wave-sequencing dependency — report BLOCKED instead of authoring your own copy.

All other harness importers (photo-strip, voice, video, dispatcher) already carry a graph edge to
media-resolver-harness, run in later waves, and get the harness via the integration branch — they
were never the problem.

### Why this unblocks it (resume mechanics, verified in mitosis.js)

The pristine backup's trailing park delta (`unitId: entry-cards`, `resumePoint.stage: "execute"`)
is RETAINED by trim_manifest.py because entry-cards is in KEEP. On fold, `park()` marks the unit
parked; `selectResumeUnits` feeds `resumeMap`; runUnit then:
- SKIPS Plan (`skipPlan`, stage execute > plan) — it only probes that
  `.mitosis/entry-cards.plan.md` exists (mitosis.js:3359-3373). **So the edited plan survives.**
- SKIPS plan-review (stage execute > plan-review).
- RE-RUNS Parallelize unconditionally (mitosis.js:3446) — the task graph is REGENERATED from the
  edited plan. The stale defective graph gets overwritten.
- Branch stage force-moves msp/entry-cards-integration fresh onto origin/main; execute rebuilds
  all tasks in clean worktrees (after the Stage F cleanup).

Consequently: KEEP the park delta (do NOT strip it), KEEP the edited entry-cards.plan.md (deleting
it would park the unit at the plan-probe, mitosis.js:3373), and DELETE the stale derived graph
artifacts (Stage F) so nothing can shortcut the re-derivation.

### Rejected alternative

Keep excluding entry-cards: rejected. It gates 5 of the remaining MSPs (today-screen, day-detail,
calendar-screen, search-screen, and via those shell-nav-integration); every deferred round delays
the whole tail. The fix is a two-edit, deterministic removal of the conflict trigger, and the
resume path (skipping Plan/plan-review) makes the retry cheaper than any fresh unit.

---

## Stage E — Re-derive run.json for batch 2 (from pristine, NEVER trim-on-trim)

### E1. Edit .mitosis/batch-tooling/trim_manifest.py — replace the two lists:

```python
MERGED = [
    "design-tokens", "mood-catalog", "platform-permissions", "drift-database",
    "sticker-widget-kit", "flower-svg-set", "domain-models", "settings-fields-kit",
    "feedback-motion-kit", "app-shell", "media-store", "journal-repository",
    "settings-repository", "core-providers", "mood-picker", "sound-effects",
    "streak-service", "data-management",
]
BATCH = ["capture-core", "entry-cards", "reminders"]
```

### E2. Edit .mitosis/batch-tooling/verify_manifest.js — update the hardcoded MERGED set (line ~88) to the same 18 ids (it still holds the batch-1 14; the schedule preview is wrong otherwise).

### E3. Run trim, then verify:

```bash
cd /Users/satanshumishra/Documents/DevLabs/fireplace
python3 .mitosis/batch-tooling/trim_manifest.py
node .mitosis/batch-tooling/verify_manifest.js
```

Expected trim output: `kept 21 msps = 18 merged + 3 batch`; removed 10;
`retained deltas: [('entry-cards', 'park')]`; base serialized to ONE line.

Expected verify output: fold PASS with 21 msps; spec hash match
(ecebde3c5beaab171cbb5aa17cbc9a230374bbb27cc1f999d1a560918ce96f10); reuse gate PASS; schedule
preview = 18 fast-skip, BUILD capture-core, entry-cards, reminders, blocked (none); final line `GO`.

NOTE: verify will print `fell back to line-split` for the whole-file parse — that is EXPECTED and
CORRECT for batch 2, because run.json is now base-line + one park-delta line (2 lines total). The
engine's real fold applies the delta; the batch-1 "must be one line" rule applies to the BASE
object only. `wc -l .mitosis/run.json` should print 2.

If verify prints anything but GO: STOP. Re-derive from pristine; do not launch.

---

## Stage F — Pre-launch cleanup + launch

### F1. Destructive cleanup (REQUIRES explicit user consent — one gate for the whole block)

The engine REUSES any worktree/branch it finds (mitosis.js:981 implementer prompt: reuse-if-exists),
so every leftover for a batch-2 MSP must go. All leftovers predate the current main.

```bash
cd /Users/satanshumishra/Documents/DevLabs/fireplace
git worktree remove --force /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/entry-cards/integration
git worktree remove --force /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/entry-cards/task-duration-format
git worktree remove --force /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/entry-cards/task-media-resolver-harness
git worktree remove --force /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/entry-cards/task-note-body
git worktree remove --force /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/capture-core/task-capture-date
git worktree remove --force /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/capture-core/task-capture-kinds
git worktree remove --force /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/msp/capture-core/task-capture-service
git worktree prune
git branch -D msp/entry-cards-integration msp/entry-cards/task-duration-format msp/entry-cards/task-media-resolver-harness msp/entry-cards/task-note-body
git branch -D msp/capture-core-integration msp/capture-core/task-capture-date msp/capture-core/task-capture-kinds msp/capture-core/task-capture-service
rm -f .mitosis/entry-cards.plan.graph.json .mitosis/entry-cards.plan.discovered-edges.json .mitosis/entry-cards.plan.edges-audit.json
rm -f .mitosis/capture-core.plan.md .mitosis/capture-core.plan.graph.json .mitosis/capture-core.plan.discovered-edges.json .mitosis/capture-core.plan.edges-audit.json
```

DO NOT touch `.mitosis/entry-cards.plan.md` (the edited plan — the resume path requires it).
reminders has no leftovers. No remote branches exist for entry-cards/capture-core (verified).
Optional hygiene (safe any time after #17/#18 merge): remove the data-management, streak-service,
and other merged-MSP worktrees/branches the same way — they fast-skip regardless.

### F2. Pre-launch assertion block

```bash
cd /Users/satanshumishra/Documents/DevLabs/fireplace
gh pr list --state open                                  # empty
git rev-list --left-right --count main...origin/main     # "N 0" (ahead only)
git worktree list | grep -E 'entry-cards|capture-core|reminders' ; echo "(want no output above)"
git branch --list 'msp/entry-cards*' 'msp/capture-core*' 'msp/reminders*'   # empty
test -s .mitosis/entry-cards.plan.md && echo PLAN-PRESENT
head -c 60 .mitosis/run.json                             # {"logicalRunId":"5385f00d",...
wc -l .mitosis/run.json                                  # 2
git status --porcelain                                   # clean
```

### F3. Launch — FRESH context only

Launch as the first major action of a fresh session (runs die when launched near-full; proven).
Verbatim contract (sessions/2026-07-11-03 block with mergePolicy human-gated):

```
Workflow({
  scriptPath: "/Users/satanshumishra/.claude/workflows/mitosis.js",
  args: {
    spec: "/Users/satanshumishra/Documents/DevLabs/fireplace/docs/superpowers/specs/2026-07-10-field-notes-design.md",
    repoRoot: "/Users/satanshumishra/Documents/DevLabs/fireplace",
    baseBranch: "main",
    sourcePrefix: "msp",
    mergePolicy: "human-gated",
    verify: {
      scopedCheckCmd: "export PATH=\"/opt/homebrew/bin:$PATH\" && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze",
      fullValidationCmd: "export PATH=\"/opt/homebrew/bin:$PATH\" && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test"
    },
    build: {
      test_command: "export PATH=\"/opt/homebrew/bin:$PATH\" && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter test",
      suite_command: "export PATH=\"/opt/homebrew/bin:$PATH\" && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter test",
      integration_branch: "main",
      sha_source: "git rev-parse HEAD"
    },
    models: {},
    worktreeRoot: "/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees",
    fixLoopMax: 2
  }
})
```

Do NOT resume any prior run id.

---

## Stage G — Monitor, publish, merge (human-gated flow)

### G1. Early log assertions (abort-worthy if violated)

| Log expectation | Meaning if absent |
|---|---|
| `mergePolicy=human-gated` | wrong args — kill and relaunch |
| Manifest REUSE fires; NO fresh Decompose of 31 MSPs | run.json format broke — kill, re-run Stage E |
| 18x "skipping <id> — reconciled as already merged" | done-oracle working |
| `mitosis[entry-cards]: resuming at execute (skipping Plan) — plan artifact verified present` | park-delta resume working; if entry-cards enters a fresh Plan stage instead, kill the run (it would overwrite the fixed plan) and re-check Stage E's retained delta |

### G2. End-of-run truth

`result.shipped` is MISLEADING (it lists fast-skips). Real state:

```bash
gh pr list --state open --json number,headRefName,title
git ls-remote origin 'refs/heads/msp/capture-core-integration' 'refs/heads/msp/entry-cards-integration' 'refs/heads/msp/reminders-integration'
```

The classifier blocks delegated agents from `gh pr create` AND `gh pr merge` (proven: #18 parked at
create; #15/#16 merged from the main thread). Expect pushed integration branches WITHOUT PRs. For
each pushed branch missing a PR, the MAIN THREAD creates it (titles must pass pr-title-lint —
conventional-commit shaped):

```bash
gh pr create --base main --head msp/capture-core-integration --title "feat: capture core (capture service + chooser + text composer)" --body "MSP capture-core: durable CaptureService + chooser sheet + text composer. Built by mitosis batch 2."
gh pr create --base main --head msp/entry-cards-integration --title "feat: entry cards (shared display cards + media playback)" --body "MSP entry-cards: note/voice/video cards, photo strip, corrupt-media placeholders. Built by mitosis batch 2."
gh pr create --base main --head msp/reminders-integration --title "feat: reminders (daily local notification)" --body "MSP reminders: daily local reminder via flutter_local_notifications + timezone, auto-suppressed when today has an entry. Built by mitosis batch 2."
```

### G3. Merge order + per-PR pubspec.yaml resolution (SYSTEMIC, expected — not a surprise)

pubspec.yaml union-conflicts are guaranteed between any two merged PRs that both add pub deps.
This batch: entry-cards adds just_audio + video_player; reminders adds flutter_local_notifications
+ timezone; capture-core adds nothing.

Merge ONE AT A TIME, in this order, each under explicit user consent, CI green first
(`gh pr checks <n>`):

1. **capture-core** — no pubspec change; merges clean.
2. **entry-cards** — merges clean against pre-reminders main (only main's audioplayers line is
   present; entry-cards' branch was cut from a main that already had it — no conflict expected;
   if DIRTY anyway, apply the union procedure below).
3. **reminders** — WILL go DIRTY after entry-cards merges. Delegate the union procedure:
   fetch + `git merge origin/main` in the branch worktree, resolve pubspec.yaml keeping BOTH sides'
   dependency additions, `flutter pub get`, `flutter test`, commit merge, push, wait CI green,
   then main-thread `gh pr merge <n> --squash` under consent.

(Same procedure as Stage A2 — it is the standing playbook for every future batch.)

### G4. If the run parks or the window dies

- Park diagnoses append as JSONL delta lines to .mitosis/run.json — read `tail -c 2000 .mitosis/run.json`.
- Relaunch-to-resume uses the SAME run.json (do NOT re-trim mid-batch); merged units fast-skip,
  parked units resume from their recorded stage. Before relaunching: re-run Stage B (reconcile) if
  any PR merged in between, and launch from fresh context again.

---

## Stage H — Post-batch verification + wrap-up

```bash
git fetch origin
gh pr list --state open          # empty
git log --oneline origin/main -4 # three new squash commits
```

State: 21/31. Then:
1. Write the session handoff + refresh the thread spine (.claude/ledger/threads/journal-app-design.md).
2. Record a decision file for the entry-cards fix disposition (plan edited, one-owner harness,
   resume-not-replan) if not already captured.
3. Update PROJECT.md snapshot (21/31; batch 3 candidates).
4. Batch 3 preview (re-derive at execution time from pristine + fresh `gh pr list --state merged`):
   dispatchable at 21/31 = capture-photo, capture-voice, capture-video, today-screen, day-detail,
   garden-screen, settings-screen (7 — MUST be split; suggest 3-4 max per window; note ALL THREE
   capture recorders add pub deps -> triple union-merge if batched together).

---

## Known caveats (carry into every future round)

| Caveat | Consequence | Mitigation |
|---|---|---|
| pubspec.yaml systemic conflict | any 2 dep-adding PRs collide at merge | merge serially; per-PR union procedure (G3) |
| run.json base must be ONE compact line | pretty-print -> fold null -> silent full re-decompose burns the window | always re-derive via trim_manifest.py from pristine; verify GO |
| trailing JSONL deltas after the base line are NORMAL | verify_manifest prints "fell back to line-split" | expected for batch 2 (park delta); wc -l == 2 |
| result.shipped lists only fast-skips | false "shipped" impression | truth = gh pr list + git ls-remote |
| classifier blocks delegated gh pr create/merge | agents publish branches then stop/park | main thread creates + merges under per-batch consent |
| ~2h session window; near-full-context launches die | dead runs | launch fresh; relaunch-to-resume on the same run.json |
| engine reuses leftover worktrees/branches (mitosis.js:981) | stale bases poison builds | Stage F cleanup before every launch |
| worktrees cut from LOCAL main (mitosis.js:946/:1114) | builds miss merged deps | Stage B reconcile before every launch |
| entry-cards resume needs .mitosis/entry-cards.plan.md present | missing -> parks at plan-probe (mitosis.js:3373) | never delete it; .mitosis/ is gitignored + local-only |
| park delta must stay for entry-cards | dropping it -> fresh Plan stage OVERWRITES the fixed plan | trim retains it automatically (entry-cards in KEEP) |
