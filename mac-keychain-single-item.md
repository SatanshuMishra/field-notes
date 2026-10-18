# mac-keychain-single-item: Mac keychain prompts: store the six sync values in one keychain item
Status: active
Updated: 2026-10-18T23:24:01.291Z
Next ids: c6 D1 R1 S1

## Goal

On macOS the ad-hoc signed app asks for login-keychain access once per stored item per release (six items, each with its own ACL keyed by the build's cdhash). Store all KeyStore values in one keychain item, migrating the six existing items, so a release prompts at most once.

## Done when

- [ ] c1 KeyStore on macOS reads and writes all six values through one keychain item
- [ ] c2 Existing six items migrate into the single item on first run and are deleted
- [ ] c3 A denied keychain read still surfaces KeyAccessException and the existing Needs attention status
- [ ] c4 docs/specs/e2e-device-sync.md item 28 describes the single item
- [ ] c5 A pull request is open, ready for review, assigned to the owner

## Where things stand

Interphase handed off a full bug spec (unattended; the stored-data change ruled out the brief lane) with two Steps in one MSP; the spec reviewer approved it.

## Next step

Record the interphase hand-off boundary, cut the FEATURE branch, write the run home and run mitosis --plan-only.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Code: lib/data/crypto/key_store.dart
- Spec: docs/specs/mac-keychain-single-item.md (decisions, record, items and repro beside it)
- ADR: docs/adr/0004-keep-mac-sync-keys-in-one-keychain-item.md
- Spec to update: docs/specs/e2e-device-sync.md item 28
- Run home: ~/.mitosis/field-notes/mac-keychain-single-item/
- Evidence: login keychain service flutter_secure_storage_service, v1.3.0 cdhash 4f82d402 trusted on 2 of 6 items (2026-10-18)
