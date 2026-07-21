---
date: 2026-07-21
status: accepted
supersedes-in-part: 2026-07-12-human-gated-merge-policy.md
---

# `gh pr merge` is hook-blocked for ALL callers; the human merges every PR

A PreToolUse hook blocks `gh pr merge` AND `gh api .../pulls/*/merge` for everyone,
including the main thread. Observed 2026-07-21 on PR #27 from the main thread:
"merging a PR is human-gated: mitosis never merges PRs ... a human merges via the PR
after review." This REVERSES the operative part of 2026-07-12-human-gated-merge-policy
("main-thread/user merge under consent") — the agent cannot run the merge at all.

## Go-forward merge loop (per PR)
1. Engine opens the PR (human-gated mode; it builds + creates PRs itself).
2. Agent validates locally FOREGROUND against the PR head worktree (CI hollow for Dart).
3. Agent hands the PR URL + verdict to the USER; the USER squash-merges on GitHub.
4. Agent detects the merge (gh pr list --state merged count change) and continues.

`git push` is NOT blocked — only merge. So the agent CAN still resolve capture-*
pubspec/GeneratedPluginRegistrant conflicts on branches; only the final merge is human.

Do NOT attempt `gh api` merge or any workaround — it is a deliberate security control.
