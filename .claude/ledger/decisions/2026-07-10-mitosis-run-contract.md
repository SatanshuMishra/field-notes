# Decision: Mitosis run contract for Field Notes v1

Status: accepted
Date: 2026-07-10

Execute v1 via a FRESH mitosis run (new runId), NOT a resume of wf_6b26b84f-135 (its cached decompose predates the font-vendoring spec change). Exact inputs and the full Workflow call live in sessions/2026-07-10-02-journal-app-design.md.

Load-bearing details:
- `sourcePrefix` = `"msp"` with NO trailing slash. The engine appends `/` itself (mitosis.js:1293); `"msp/"` produced the invalid ref `msp//...` and failed run 1.
- `baseBranch` = `main`. Worktrees are cut from `origin/main`, so main must be pushed before launch (it is: 54a2c51).
- verify/build commands prefix `export PATH="/opt/homebrew/bin:$PATH"` (Flutter is Homebrew-installed) and run `flutter pub get && dart run build_runner build --delete-conflicting-outputs` before analyze/test (fresh worktrees have no `.dart_tool`/generated code).
- GitHub repo renamed `fireplace` -> `field-notes` (PRIVATE); local dir stays `fireplace`. The `origin` remote still points at the old `.../fireplace.git` URL — pushes redirect and succeed (proven this session). Repoint was denied by the auto-mode classifier; the user can run `git remote set-url origin https://github.com/SatanshuMishra/field-notes.git` themselves if `gh` ever complains about the moved repo.
