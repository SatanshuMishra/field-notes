Status: accepted
Date: 2026-07-28
Thread: prototype-design-alignment
Supersedes: 2026-07-28-agent-force-push-blocked-ship-via-new-ref.md

## Context
The superseded record established that `git push --force-with-lease` is refused by the harness auto-mode classifier for the MAIN THREAD, and worked around it by pushing each rebased MSP to a new `<branch>-rebased` ref. That workaround shipped C6 and C5 but leaves an orphan branch pair per MSP, with roughly 25 MSPs still to ship across clusters C through H.

## Decision
Add a `Bash(git push --force-with-lease:*)` permission rule so rebased MSPs push in place. `--force-with-lease` refuses to clobber upstream work the local ref has not seen, which is why it is the granted variant and bare `--force` is not.

## Consequences
- The `-rebased` ref workaround is retired for MSPs shipped after this rule lands. It remains the correct fallback if the classifier fires anyway — the block was a classifier, not a permission, so a permission rule is expected but not proven to clear it. Verify on the next rebase before relying on it.
- The orphan branches already accumulated (`msp-cluster-c/c6-feed-empty-state`, `msp-cluster-c/c5-card-surface-body-strip`) plus the superseded `feat/cluster-c-today-centre`, the `chore/ledger-handoff-session-16` through `-20` branches and three stale stashes are cleared in one separately-confirmed batch, not silently.
- Destructive git operations still require explicit confirmation. This rule covers `--force-with-lease` only; branch deletion and history rewrite remain gated.
