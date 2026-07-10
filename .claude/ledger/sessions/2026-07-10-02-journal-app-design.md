# Session 2026-07-10-02 — journal-app-design

## Where it started
Resumed the paused thread and ran /mitosis to implement Field Notes v1 (spec approved).

## What shipped
- Installed Flutter SDK via Homebrew (3.44.6 / Dart 3.12.2). `analyze`+`test` functional; Android SDK + full Xcode/CocoaPods absent (only needed at Phase 8).
- Delegated + committed the minimal Phase 0 skeleton: buildable `field_notes` Flutter project, Riverpod 3.3.2 + drift 2.34.1 wired, flutter_lints, smoke test; `flutter analyze` clean, `flutter test` green.
- Made the initial commits on main (repo had ZERO commits): scaffold + design docs + ledger. Receipts CI enforcer installed and pushed.
- Vendored the 3 OFL fonts (Newsreader / Instrument Sans / Caveat, human-provided) under `assets/fonts/`, committed + pushed. Annotated spec §0: fonts are pre-vendored (no download).
- Final: main == origin/main == 54a2c51.

## Tried and failed (both root-caused and FIXED)
- mitosis run 1 (wf_6b26b84f-135) FAILED at the `branch` stage: `sourcePrefix: "msp/"` (trailing slash) produced the invalid double-slash ref `msp//design-tokens-integration` — the engine appends its own `/` at mitosis.js:1293. Fix: pass `sourcePrefix: "msp"`.
- mitosis run 2 (resumed) FAILED at `execute`: design-tokens task-3 tried to `curl` the font binaries; the harness safety classifier BLOCKED it 3x (agents AND main-thread downloads both denied). Fix: human-provided vendored fonts committed to main + spec annotated so the regenerated plan only REGISTERS them.

## Verification
- Skeleton: `flutter analyze` clean, `flutter test` green.
- Fonts verified real TrueType (194-495KB) + 3 OFL license files.
- Repo clean: main == origin/main == 54a2c51; only `main` branch; no worktrees; failed-run artifacts (worktree, `msp/*` branches, `.mitosis/`) removed.

## Running state
- None. No background tasks. Both mitosis runs completed (failed); nothing left running.

## Pick up here — launch a FRESH mitosis run (NOT a resume)
Do NOT resume wf_6b26b84f-135 (its cached decompose predates the font-vendoring spec change). Start fresh:

```
Workflow({
  scriptPath: "/Users/satanshumishra/.claude/workflows/mitosis.js",
  args: {
    spec: "/Users/satanshumishra/Documents/DevLabs/fireplace/docs/superpowers/specs/2026-07-10-field-notes-design.md",
    repoRoot: "/Users/satanshumishra/Documents/DevLabs/fireplace",
    baseBranch: "main",
    sourcePrefix: "msp",
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

Prereqs satisfied: fonts vendored + pushed (54a2c51 == origin/main), sourcePrefix fixed, artifacts cleaned. Expect a multi-hour run and ~31 PRs on the PRIVATE repo SatanshuMishra/field-notes. Watch `/workflows`.
