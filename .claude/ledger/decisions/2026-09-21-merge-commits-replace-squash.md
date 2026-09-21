Status: accepted
Date: 2026-09-21
Thread: inline-photo-notes
Supersedes: decisions/2026-07-25-verify-squash-against-remote-tip.md, decisions/2026-07-28-stacked-msps-ship-sequentially.md

## Context
On 2026-09-20 the owner changed the repository's merge settings mid-way through the note editor rollout:
squash merging off, merge commits on, and the head branch deleted automatically on merge. Rebase merging
was left enabled because it was not mentioned. PRs #129 and #130 squash-merged; every PR from #131 onward
merged with a merge commit.

Two standing decisions derived their rules from squash merging, and that mechanism no longer exists.

## Decision
Both are superseded. What each got right survives in a narrower form.

**verify-squash-against-remote-tip.** Its mechanism was that a squash captures a snapshot, so a commit
pushed between the snapshot and the merge never reaches `main` and the branch looks merged anyway. A merge
commit makes the merged branch's commits ancestors of `main`, so that silent loss cannot happen through the
merge itself. What survives: a commit pushed after a PR merges still never reaches `main`, and with
automatic branch deletion it is now also gone from the remote. Check with
`git merge-base --is-ancestor <branch-tip> origin/main` before treating work as landed. That check replaces
the diff-against-remote-tip procedure, which existed only because a squash breaks ancestry.

**stacked-msps-ship-sequentially.** Its whole reason was that squash puts a predecessor's content on
`main` under a SHA absent from the next branch's history, so a stacked PR would diff that content twice.
With merge commits the predecessor's commits are in the successor's history, and a stacked PR diffs only
its own changes. Stacked MSPs may be opened together and merged bottom-up. What survives is not from this
decision: validation still has to run on the base the change actually merges onto whenever `main` has moved
underneath it, because other work may have landed there.

## Consequences
- The wave rollout of the note editor stopped needing a rebase-and-revalidate step between waves from #131
  onward. Each wave branched from `main` and `main` genuinely contained the previous wave's commits.
- `main` can now be protected against deletion only by the default-branch rule. It is not a protected
  branch, and no `development` branch exists. If a hard guarantee is wanted, branch protection is the
  mechanism, and it also changes who can push directly, so it is a separate decision.
- Rebase merging remains available. A rebase merge rewrites SHAs and reintroduces the ancestry break that
  the first superseded decision was written around. If it is used, that decision's diff check applies again.
