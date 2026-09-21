Status: superseded
Date: 2026-07-25

## Context
PR #38 squash-merged at 13:37 MDT while the remote branch tip `3a24ff6` was committed at 13:49 — twelve
minutes later. GitHub squashed the state it had at merge time, so `3a24ff6` never reached `main`. That
silently dropped `sessions/2026-07-25-02-video-card-playback-controls.md` and reverted a decision record to
its pre-cap form, leaving `main` with an over-cap record whose pointer target no longer existed. Neither
the GitHub UI nor `gh pr view` reports this.

## Decision
After any squash merge, run `git diff --stat origin/main <remote-branch-tip>` before deleting the branch,
and recover anything the squash left behind.

## Consequences
A squash merge captures a snapshot, not a branch ref, so any commit pushed between snapshot and merge is
lost with no warning anywhere in the merge UI. The window opens whenever work continues on a branch while
its PR sits open. Recovery is cheap while the branch ref survives and archaeological once it is deleted —
which is why the check belongs before deletion, not after a later reader notices a dangling pointer.
