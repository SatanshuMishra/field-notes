Status: accepted
Date: 2026-07-19
Thread: journal-app-design

## Context
`~/.claude/lib` is a symlink into `.windful-ocean`, so Node sets `import.meta.url` to the realpath
while `process.argv[1]` stays literal; the guard comparing them was always false and `main()` never
ran — all 7 CLIs in `~/.claude/lib/superpowers-parallel/` exited 0 writing ZERO bytes. Commit 2ea2a0b
(2026-07-18) had just moved the manifest fold into one, so empty stdout became a silent fresh
Decompose (mitosis.js:3647) with NO log line. Evidence: sessions/2026-07-19-03-journal-app-design.md.

## Decision
Fix the guard in all 7 with `pathToFileURL(realpathSync(process.argv[1])).href`, not by repointing
mitosis.js:23 LIB_DIR at the realpath.

## Consequences
- Standing rule: exit 0 is NOT evidence a Node CLI ran — pre-flight the fold CLI's stdout and assert
  the msp count before EVERY launch; engine logs cannot catch this. 829/829 lib tests pass.
- The fix is UNCOMMITTED in .windful-ocean (user's global config repo, their call).
- Rejected LIB_DIR one-liner: leaves CLIs broken for hardcoded ~/.claude callers
  (plan-to-task-graph/SKILL.md:40 -> wave-planner), exercised by this very batch.
- 3 files still carry it (chip task_ecab775c), incl. the blocking hook block-inline-engine.mjs, which
  therefore FAILS OPEN.
