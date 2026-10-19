# mac-keychain-single-item: Mac keychain prompts: store the six sync values in one keychain item
Status: active
Updated: 2026-10-19T00:04:56.899Z
Next ids: c6 D3 R2 S1

## Goal

On macOS the ad-hoc signed app asks for login-keychain access once per stored item per release (six items, each with its own ACL keyed by the build's cdhash). Store all KeyStore values in one keychain item, migrating the six existing items, so a release prompts at most once.

## Done when

- [ ] c1 KeyStore on macOS reads and writes all six values through one keychain item
- [ ] c2 Existing six items migrate into the single item on first run and are deleted
- [ ] c3 A denied keychain read still surfaces KeyAccessException and the existing Needs attention status
- [x] c4 docs/specs/e2e-device-sync.md item 28 describes the single item evidence: item 28 in the owner's checkout now describes field_notes.sync.bundle, the move and the one-prompt-per-release behaviour (file is git-ignored, so it ships in no pull request)
- [ ] c5 A pull request is open, ready for review, assigned to the owner

## Where things stand

MSP mac-keychain is built and committed on mitosis/mac-keychain at ea0ae420 (base fix/mac-keychain-single-item at 5e0a128a, worktree ~/.mitosis/runs/fireplace/mac-keychain-single-item/trees/mac-keychain); the gate passed 13 tests and found the 5.9 unchanged-behaviour guard inert, as designed. Review round 1: the full suite passed apart from one flaky tooling test (android_dump_rules_test) that passes alone at head and base and in a full test/tooling rerun; code-reviewer, security-reviewer and conformance-auditor are running.

## Next step

Run SHIP=1 ~/.mitosis/fireplace/mac-keychain-single-item/run.zsh --resume, then open the pull request with create_pull_request from mitosis's title and body and assign it to the owner.

Needs: D2.

## Decisions in force

- D1 Interphase hand-off: build the one-item spec with mitosis: Build it on fix/mac-keychain-single-item from the run home, then review.
- D2 Ship: push MSP mac-keychain and open its pull request: Ship: mitosis gates the new head, pushes mitosis/mac-keychain, and the pull request opens against fix/mac-keychain-single-item, assigned to the owner.

## Open risks

- R1 Criterion 5.10 (one prompt per release on a real Mac) is unproven: it needs two ad-hoc release builds and a person answering the prompt; the owner checks it by hand.

## Settled, do not reopen

## Where the details live

- Code: lib/data/crypto/key_store.dart, lib/state/sync_providers.dart
- Spec: docs/specs/mac-keychain-single-item.md (decisions, record, items and repro beside it)
- ADR: docs/adr/0004-keep-mac-sync-keys-in-one-keychain-item.md (uncommitted in the owner's checkout; ships with the pull request)
- Run home: ~/.mitosis/fireplace/mac-keychain-single-item/ (run.zsh, CHARTER.md, build-1.out); shared accept script and findings ledger in ~/.mitosis/field-notes/
- Evidence: login keychain service flutter_secure_storage_service, v1.3.0 cdhash 4f82d402 trusted on 2 of 6 items (2026-10-18)
