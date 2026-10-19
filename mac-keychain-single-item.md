# mac-keychain-single-item: Mac keychain prompts: store the six sync values in one keychain item
Status: parked
Updated: 2026-10-19T03:09:35.427Z
Next ids: c6 D3 R2 S2

## Goal

On macOS the ad-hoc signed app asks for login-keychain access once per stored item per release (six items, each with its own ACL keyed by the build's cdhash). Store all KeyStore values in one keychain item, migrating the six existing items, so a release prompts at most once.

## Done when

- [x] c1 KeyStore on macOS reads and writes all six values through one keychain item evidence: test/state/key_store_provider_test.dart 'the Mac key store keeps every sync key in one keychain item' fails reverted, passes at 3da3bb99 (mitosis gate)
- [x] c2 Existing six items migrate into the single item on first run and are deleted evidence: bundled_secure_values_test.dart 'the six old items move into the bundle on first read' and 'a first write moves the old items before changing one' gated red then green
- [x] c3 A denied keychain read still surfaces KeyAccessException and the existing Needs attention status evidence: the four 5.4 refusal tests gated red then green; existing sync_resilience_test refusal tests pass in the round 1 suite
- [x] c4 docs/specs/e2e-device-sync.md item 28 describes the single item evidence: item 28 in the owner's checkout now describes field_notes.sync.bundle, the move and the one-prompt-per-release behaviour (file is git-ignored, so it ships in no pull request)
- [x] c5 A pull request is open, ready for review, assigned to the owner evidence: SatanshuMishra/field-notes#326, mitosis/mac-keychain into fix/mac-keychain-single-item, ready, assigned to SatanshuMishra

## Where things stand

Integration: lighthouse run 1 gave verdict unproven with no failures (suite passed on both builds apart from the flaky android_dump_rules_test, which also fails on main; the four keychain paths and the Device sync relay neighbour are unproven). The final run 2 (--final, --previous run-1) is running its suite; its profile publish committed ea48a097 to fix/mac-keychain-single-item.

## Next step

When run 2's suite lands, write run-2/findings.json with the five retest paths under their exact names (unproven), run lighthouse verdict, lighthouse pr --final, open the FEATURE pull request into main, then lighthouse release and park the thread for Clean-up.

Needs: D2, R1.

## Decisions in force

- D2 Ship: push MSP mac-keychain and open its pull request: Ship: mitosis gates the new head, pushes mitosis/mac-keychain, and the pull request opens against fix/mac-keychain-single-item, assigned to the owner.

## Open risks

- R1 Criterion 5.10 (one prompt per release on a real Mac) is unproven: it needs two ad-hoc release builds and a person answering the prompt; the owner checks it by hand.

## Settled, do not reopen

- S1 Review round 1 rejected C1, S1 to S4 (no way back after the move, a planted bundle item, the plugin's delete-then-add write, cross-instance lost updates) as contradicting the spec's decisions; C2 and C3 were fixed.

## Where the details live

- Code: lib/data/crypto/key_store.dart, lib/state/sync_providers.dart
- Spec: docs/specs/mac-keychain-single-item.md (decisions, record, items and repro beside it)
- ADR: docs/adr/0004-keep-mac-sync-keys-in-one-keychain-item.md (on the branch; also untracked in the owner's checkout)
- Run home: ~/.mitosis/fireplace/mac-keychain-single-item/ (run.zsh, CHARTER.md, rounds.md, review/, ship.json); shared accept script and findings ledger in ~/.mitosis/field-notes/
- Evidence: login keychain service flutter_secure_storage_service, v1.3.0 cdhash 4f82d402 trusted on 2 of 6 items (2026-10-18)
