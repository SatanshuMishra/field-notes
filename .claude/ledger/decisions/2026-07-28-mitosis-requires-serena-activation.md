Status: accepted
Date: 2026-07-28
Thread: prototype-design-alignment

## Context
Mitosis run 2 halted at `execute` with task-1 reporting `BLOCKED: needed=serena-activate_project (LSP call hierarchy unavailable — Serena reports 'No active project' and no activation tool is exposed) task=semantic discovery`. Serena had never been activated for this repo; `tool-routing.md` requires `activate_project` once per project before its language servers index the code, and the task subagent is not given that tool.

## Decision
Serena activation is a hard precondition for any mitosis dispatch on this repo, performed in the main thread before dispatch. Activated 2026-07-28 (project auto-named `fireplace` from the legacy directory path).

## Consequences
- The fix is PARTIAL and UNVERIFIED: `activate_project` returned `Programming languages: .` — empty, no language backend detected for Dart/Flutter. It clears the literal "No active project" error; it does not prove Dart semantic discovery works.
- If a task blocks this way again, the correct fix is to stop requiring Serena semantic discovery on this repo (native grep/Read is the fallback per tool-routing.md's street-view layer), NOT to re-activate.
- The subagent was RIGHT to report BLOCKED rather than guess. Do not treat a capability-blocked report as agent failure.
