# today-calendar-day-modal-parity: Today, Calendar and day modal design parity
Status: done
Updated: 2026-10-17T05:49:35.162Z
Next ids: c4 D8 R3 S1

## Goal

Bring the live Today page, Calendar, day modal and note view/edit modal to parity with the Claude Design mock-up: compact log cards with an in-place Edit/Delete pill, a view-only log modal unified with the editor, a contained day modal without yellow underlines, and pager navigation on the calendar. Specified through the interphase prototype pathway, then built through mitosis.

## Done when

- [x] c1 The owner approves the written spec docs/specs/today-calendar-day-modal-parity.md evidence: The owner answered Approve to the phase 8 question 'Do you approve the written spec at docs/specs/today-calendar-day-modal-parity.md, including the 16 assumptions in section 17?', after the spec-reviewer's findings were applied and summarised. check_spec.py exits 0 with four vague-word warnings, all inside the verbatim request in section 1.
- [x] c2 Every Step in the items file ships with a pass gate verdict and the local gate is green on the merged result evidence: All five PRs (164 to 168) are merged into main at 9567b61, and every branch head (180de9e, c21071e, 3de08fa, 52b170f, 36b7cce) is an ancestor of it. The full local gate on that merged main, run on a branch cut from origin/main: flutter analyze reports no issues, 1980 tests pass, 39 goldens pass. 12 Steps carry a pass gate verdict from mitosis (73 of 73 acceptance tests, 0 inert). The thirteenth, remove-entry-card, has no mitosis verdict: its worker refused on a missing write-set file, it was built by hand, and by design it has no acceptance test; its proof is the gate staying green without the removed code.
- [x] c3 The owner has seen Today, Calendar, the day modal and the unified note modal running on macOS and compared them with the design evidence: The owner ran the app from main at 9567b61 on macOS and reported: "The changes work as expected." They raised one mismatch, that the edit icon does not match the design, which is handled as a follow-up change.

## Where things stand

PRs 164 (compact log cards, manage pill, confirm dialog), 165 (view mode unified with the editor, composer header, Save changes confirmation), 166 (calendar pager: month picker, This week, arrow, T and Esc keys, today opens Today, restyled grid, Settings week start), 167 (Today and the day modal on compact cards, underlines and overflow fixed, view mode replaces the day modal), 168 (full-length entry card removed) and 169 (edit glyph drawn as the design's edit icon), all merged; main at 042c164. Verified: full local gate on merged main 9567b61 was analyze clean, 1980 tests, 39 goldens; the fix/edit-icon branch was analyze clean, 1982 tests, 41 goldens. The owner confirmed on macOS: "The changes work as expected." and then "All changes complete." All three completion criteria are done. Not verified: benchmark 5 has not been re-run on the compact cards, and nothing was run on an Android device.

## Next step

Close this thread as done with close_thread (thread 01M36DG8N4H4G3PCDQM812CR3J): all three completion criteria are met and the owner said "All changes complete."

## Decisions in force

- D1 Calendar ships the pager navigation model only: Pager only, chosen by the owner. A month grid with previous and next month, a month-and-year picker opened from the title, a "This week" jump shown when away from the current month, and the arrow-key, T and Esc shortcuts. No week view and no scroll model.
- D2 Touch layouts reveal the Edit/Delete pill on long-press: Long-press reveals the same dark pill, chosen by the owner, so touch and pointer share one menu.
- D3 Confirm before a delete and before saving an edit: Both, chosen by the owner: "Delete this entry?" before a delete, "Save changes?" before saving an edit to a note.
- D4 Calendar: today opens Today, past days open the day modal, future days do not respond: Past days and today, chosen by the owner. Today's cell opens the Today page, any past day opens the day modal, an empty past day offers "Add a note", and future days are dimmed and inert.
- D5 Where the design is silent, keep live core logic and match the design's look: The owner: "the Claude Design just built a crude HTML mock-up of the Live Application. Where NOT specified, keep the established and well architected CORE logic of the live version because that is what is actually working. Do your best to match the aesthetic." The viewer therefore uses the live reader with placed photos. The owner did not object to two other defaults raised in the same pre-mortem: edit mode takes the design's header, and the month grid takes the design's cell styling.
- D6 Remove the full-length entry card once nothing uses it: Remove, on the owner's word: "If these have been completely removed from usage (which was the goal for consistency), then you have the permission to clean up this too." Tests that pin only the removed card's own chrome are deleted with it. Tests that pin a behaviour that survives elsewhere, such as note photo rendering or voice and video dispatch, are moved to the widget that now owns that behaviour, never dropped.
- D7 Build plan: 13 Steps, 5 held MSPs, export file owned by the cleanup Step: entry_cards.dart belongs to remove-entry-card alone, which also adds the compact exports there. The replan gave 13 Steps in 12 Lanes across 5 MSPs (cards, modal, screens, calendar, cleanup), parallelism 6, no cycles. The screens MSP has two producers, so its pull request targets the base branch rather than stacking; accepted because the owner reviews cards and modal first, after which its diff is clean. The run holds every MSP locally with --no-push on base/parity (cut from origin/main 128e0b4, since local main is stale at 79ad901), tiers top=claude-opus-5-5 and cheap=claude-sonnet-5, timeout 5400, concurrency 4, run directory scratchpad/mitosis/parity.

## Open risks

- R1 The compact card sizes a short note to 13.5pt by scaling the text scaler around NoteBody, because NoteBody takes no style parameter. It composes with the user's text scale, but it replaces a non-linear system scaler with a linear one inside that card.
- R2 The local gate (validate.sh) runs analyze, the unit suite and the goldens but never runs integration_test/, so a runtime break there stays invisible. Benchmark number 5 asserted Today showed the old entry card for the whole screens branch and nothing caught it; analyze only proves integration tests compile.

## Settled, do not reopen

## Where the details live

- Binding decisions for the parity spec, local only and gitignored: docs/specs/today-calendar-day-modal-parity.decisions.md
- Tree guard snapshot, deleted at hand-off: docs/specs/today-calendar-day-modal-parity.guard.json
- Claude Design project, Field Notes file: https://claude.ai/design/p/eafe8d73-b380-44be-9b2e-6431c0f35f26?file=Field+Notes.dc.html
- The parity spec, local only and gitignored: docs/specs/today-calendar-day-modal-parity.md
- mitosis charter for this wave, local only: docs/specs/today-calendar-day-modal-parity.charter.md
- mitosis items file, 13 Steps: docs/specs/today-calendar-day-modal-parity.items.json
- PR 164 compact log cards: https://github.com/SatanshuMishra/field-notes/pull/164
- PR 165 unified note modal, stacked on 164: https://github.com/SatanshuMishra/field-notes/pull/165
- PR 166 calendar pager, base main: https://github.com/SatanshuMishra/field-notes/pull/166
- PR 167 Today and day modal, stacked on 165: https://github.com/SatanshuMishra/field-notes/pull/167
- PR 168 remove the full-length entry card, stacked on 167: https://github.com/SatanshuMishra/field-notes/pull/168
- PR 169 edit glyph drawn as the design's edit icon: https://github.com/SatanshuMishra/field-notes/pull/169
- Old ledger record: thread 01M36DG8N4H4G3PCDQM812CR3J in refs/logbook/archive/ledger
