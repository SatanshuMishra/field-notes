# surface-fixes: Surface fixes on macOS and the phone: build and ship through mitosis
Status: active
Updated: 2026-10-17T05:49:35.162Z
Next ids: c3 D1 R1 S1

## Goal

Apply the Claude Design surface redesign (one viewer per log type, camera-first join, big add-device code, phone settings pages, full-width macOS settings, two-pane macOS day panel) to the live app on macOS and Android, shipped as four draft pull requests built by mitosis from the spec at docs/specs/surface-fixes.md.

## Done when

- [ ] c1 Four draft pull requests are open (foundation, logs and day detail, sync flows, settings), each with every acceptance property gated pass and the full suite passing at its head.
- [ ] c2 The owner checks the new surfaces on the S24 Ultra, Note 10+ and Mac (spec 16.47 to 16.49).

## Where things stand

Converted from the old ledger.

## Next step

Owner reviews and merges PR #295, then types into Delete journal and Change server address and the onboarding note step on the S24 Ultra and Note 10+. Open decisions for the owner: dark-theme phone theme-step drawing loses its outline and the dark Other ways film block nearly matches the page; the phone sheet in landscape with the keyboard can still partly cover its lowest button (would need whole-sheet scrolling).

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- spec: docs/specs/surface-fixes.md
- decisions: docs/specs/surface-fixes.decisions.md
- interview record: docs/specs/surface-fixes.record.json
- mitosis items: docs/specs/surface-fixes.items.json
- mitosis run kit: U+007E/.mitosis/field-notes/surface-fixes/
- Claude Design project: https://claude.ai/design/p/eafe8d73-b380-44be-9b2e-6431c0f35f26
- Old ledger record: thread 01M4D2PTCVNX3R7YY2KEK7YHG0 in refs/logbook/archive/ledger
