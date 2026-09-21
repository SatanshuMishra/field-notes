Status: superseded
Date: 2026-07-28
Thread: prototype-design-alignment

## Context
Cluster B's B2, B3 and B4 all edit `lib/app/shell/sidebar_shell.dart` and were recovered as one stacked lineage. Opening all three PRs at once against `main` was the obvious move and is wrong: the repo squash-merges, so after B2 lands, `main` holds B2's content under a new SHA that is not in B3's history. B3's PR would then diff B2's changes a second time and risk a conflict at merge.

## Decision
Ship stacked MSPs strictly one at a time. Open only the frontmost PR; when it merges, `git rebase --onto main <previous-MSP-tip>` the next branch, re-run `fullValidationCmd` on the new base, then open its PR. Never carry a green result from one base to another, and never open the second PR before the first merges.

## Consequences
Costs one human merge round-trip per MSP; buys a per-MSP diff that is genuinely that MSP's, and a validation result that matches the tree being merged. Verified in practice: after #63 and #64 merged, `git diff main 54fd9ef` was empty, proving the squash merges reproduced the checkpoint content exactly and the replays had nothing to reconcile. Rejected alternative: stacking PRs with `--base <previous-branch>` and relying on GitHub's auto-retarget — it produces a clean review diff but leaves the post-squash merge conflict unresolved. Pairs with decisions/2026-07-27-shared-file-cluster-serializes.md, which is why the chain exists at all.
