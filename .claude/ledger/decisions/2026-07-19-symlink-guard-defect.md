Status: accepted
Date: 2026-07-19
Thread: journal-app-design

## Context
`~/.claude/lib` is a symlink into `.windful-ocean`, so Node sets `import.meta.url` to the realpath
while `process.argv[1]` keeps the literal path. The guard `import.meta.url ===
\`file://${process.argv[1]}\`` was therefore always false and `main()` never ran: all 7 CLIs under
`~/.claude/lib/superpowers-parallel/` exited 0 having written ZERO bytes. Commit 2ea2a0b (2026-07-18)
had just moved the manifest fold into one of them, so empty stdout -> `parseRunManifest("")` -> null
-> `isRelaunch` false -> silent fresh Decompose at mitosis.js:3647, with NO log line (the
"decomposing fresh" diagnostic is gated on `isRelaunch`). Full evidence:
sessions/2026-07-19-03-journal-app-design.md.

## Decision
Fix the guard in all 7 CLIs with the realpath idiom
`pathToFileURL(realpathSync(process.argv[1])).href`, rather than repointing mitosis.js's LIB_DIR
(mitosis.js:23) at the realpath.

## Consequences
- Standing rule: exit code 0 is NOT evidence a Node CLI ran. Pre-flight the fold CLI's stdout and
  assert the expected msp count before EVERY launch; engine logs cannot catch this class of failure.
- Verified: 829/829 lib tests pass; import-only consumers still do not execute main().
- The fix is UNCOMMITTED in the .windful-ocean working tree (user's global config repo, their call).
- Rejected: the one-line LIB_DIR realpath — it leaves the CLIs broken for every other caller
  (plan-to-task-graph/SKILL.md:40 invokes wave-planner via a hardcoded ~/.claude path, exercised by
  this very batch) and re-breaks if the symlink topology changes.
- 3 files still carry the defect (chip task_ecab775c), incl. hooks/block-inline-engine.mjs, a
  BLOCKING hook that consequently FAILS OPEN.
