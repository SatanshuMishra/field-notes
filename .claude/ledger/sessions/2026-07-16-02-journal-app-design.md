# Session 2026-07-16-02 — journal-app-design

## Where it started
Resumed the paused thread at 14/31 merged (origin/main 66a12a46). User asked to conservatively scope mitosis to only MSPs it can finish in ONE session, with follow-up batches possibly in the same context. No code shipped this session — it was diagnosis + staging for the next relaunch.

## What shipped
- **ROOT CAUSE FOUND (bigger than batch sizing).** `.mitosis/run.json` was PRETTY-PRINTED (656-line base + 1 trailing JSONL delta). The engine's fold contract requires the base object on ONE compact line (`mitosis.js:3025` writes `JSON.stringify`; write prompt :3032 = "ONE line, verbatim"). Replaying `foldRunManifest` (:574-592) against the real bytes returned **null** (whole-file `JSON.parse` throws on the delta; line-split fallback parses `lines[0]`==`"{"` and fails). Null fold -> `isRelaunch` falsy (:2918) -> `reuse={reusable:false}` -> full fresh Decompose (:2940-2967) -> wholesale overwrite gated `if(!reusable)` (:3023). So EVERY past relaunch silently re-decomposed all 31 MSPs before any MSP work, then died on the ~2h session limit. The prior ledger claim "reused 31 MSPs, skipped fresh Decompose" was FALSE (a fresh decompose reproduces the same 31 ids -> looked like reuse). run.json mtime Jul 15 19:42 sits inside wf_bfb12095-952's window, confirming that run rewrote it.
- **Engine audit (2-round subagent, agentId a52b60cfea4fe4c5b):** NO MSP-filtering input exists (`input.*` has no only/mspIds/include/exclude/targets/maxMsps; complete field list in the agent report), and no concurrency cap — wave width is emergent from the dep graph. The ONLY scoping lever is editing run.json's `msps[]` out-of-band. Full GO/NO-GO safety analysis captured in decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md.
- **run.json fixed + trimmed to 18 MSPs, in place**, serialized to ONE compact line (13393 bytes): 14 merged (fast-skip via done-oracle) + batch 1 = mood-picker, streak-service, sound-effects, data-management. Removed 13 (incl. entry-cards + its orphan park delta). VERIFIED with the engine's real `foldRunManifest`+`evaluateManifestReuse`: folds, specContentHash matches live spec (ecebde3c…), reuse gate passes, 14 fast-skip, exactly 4 build, 0 blocked.
- **Durable backups + tooling** (all in gitignored `.mitosis/`, persist locally, NOT committed): `.mitosis/run.json.pristine-backup` = untouched 657-line 31-MSP original (source of truth for future batches). `.mitosis/batch-tooling/trim_manifest.py` (SRC repointed at the pristine backup; edit only the BATCH list per batch) + `verify_manifest.js` (replays engine logic).
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md written.

## Tried and failed
- Did NOT launch mitosis. Context reached 72% by the time staging was done; the ledger's proven rule is that runs die when launched near-full (wf_1245a178-eaf died at ~83% last session). Launching from here would repeat a known-failed experiment. Deliberately deferred to a fresh session.

## Verification
- `node verify_manifest.js` on the edited run.json — foldRunManifest -> 18-msp object; whole-file parse OK (single line); specContentHash == live shasum of spec (ecebde3c5beaab171cbb5aa17cbc9a230374bbb27cc1f999d1a560918ce96f10); reuse gate reusable=true; schedule preview = 14 fast-skip, build [mood-picker, streak-service, sound-effects, data-management], 0 blocked.
- `wc -l .mitosis/run.json` — 1 line (was 657). `git rev-parse origin/main` — 66a12a4; local HEAD 3f40f8f (contains origin/main, 8 ledger commits ahead, 0 behind — reconciliation invariant already holds, no rebase needed).
- Pre-flight worktrees: 24 total; 6 belong to 3 batch MSPs (data-management x2 @6339c6f pre-core-providers base; sound-effects x2 @66a12a4; streak-service x2 @476a525/a16c60e). NOT removed (destructive; needs consent).

## Running state
- None. Subagent a52b60cfea4fe4c5b idle (resumable via SendMessage if the engine needs re-inspection). No background tasks/shells.

## Deferred + open
- **LAUNCH batch 1 from a FRESH, clean context** — run.json is already fixed+trimmed; use the verbatim contract in sessions/2026-07-11-03 with `mergePolicy: "human-gated"` (do NOT use its `mergePolicy:"autonomous"` line). Expect 4 PRs (mood-picker, streak-service, sound-effects, data-management); verify via `gh pr list --state open`, merge under per-batch consent.
- Batch 2 (after batch-1 PRs merge): re-derive FROM `.mitosis/run.json.pristine-backup` (never trim-on-trim) via `.mitosis/batch-tooling/trim_manifest.py` — edit BATCH to the next dispatchable set (once core-providers deps are satisfied: capture-core unblocks 8; plus reminders, settings-screen path). Then `node .mitosis/batch-tooling/verify_manifest.js` before launch.
- entry-cards STRUCTURAL defect still unfixed (add/add on test/features/entry_cards/support/entry_cards_harness.dart, two owners) — excluded from batches until the plan gives that file one owner; blocks 5 screen MSPs.
- 6 leftover batch-MSP worktrees not cleaned (destructive; ledger says branch-prep converges them, but streak-service work was reviewed while the safety classifier was DOWN — re-review if reused).
- streak-service + garden-screen artifacts from wf_bfb12095-952 are unverified (classifier unavailable during their review).

## Pick up here
Fresh session: verify `gh pr list --state open` (empty) + `git rev-parse origin/main` (66a12a4) + `head -c60 .mitosis/run.json` (one line, starts `{"logicalRunId":"5385f00d"`). Then launch batch 1 human-gated per the sessions/2026-07-11-03 contract. Confirm reuse actually fires this time (engine log should say it skipped Decompose). Do NOT resume any prior run id.
