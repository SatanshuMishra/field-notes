---
Status: accepted
Date: 2026-08-03T19:34:37.456Z
Thread-Id: 01KZ33PK4E5RN3G6MD458S2N5D
---

# 0005. P1 ships first and P2 waits for the entire editor ladder, per the computed file-overlap matrix

## Context

The combined spec claimed "P1 may ship in parallel with E1-E5" and "P2 requires E2". Both were asserted, never computed. Crossing the E-fences (spec 3.2) with the sibling's fence table yields exactly three contended files: note_body.dart (E1 x P1,P2,P3), text_composer_sheet.dart (E2,E5,E6 x P1,P2,P4), and markdown_note_controller.dart (E2,E3,E4,E7 x P2,P4). A shared file is a HARD dependency edge on this project.

## Options

- P1 ships FIRST, E1 rebases onto it; P2 waits for the whole editor ladder (CHOSEN)
- Bury P1 behind E1-E5 as the naive serialization
- Run P2 after E2 and rebase it through E3-E7

## Outcome

Order is E0 -> {P0 parallel P1} -> E1 -> E2 -> E3 -> E4 -> E5 -> E6* -> E7* -> P2 -> P3 -> P4 -> P5. THE PARALLELISM CLAIM WAS FALSE ON TWO FILES, not the one suspected. Resolution is NOT to bury P1: P1 holds the SMALLER diff on both contended files (adds a stripPhotoAnchors call, mounts PhotoTray behind a nullable callback) while E1 rewrites NoteBody wholesale and E2 swaps the controller -- landing small-then-large is cheaper, and A3 already defines the composition (strip anchors, then parse). NEW OBLIGATION ON E1: it rewrites a NoteBody that already calls stripPhotoAnchors and MUST preserve that call; built against a pre-P1 NoteBody the stripper is silently dropped and every stored U+FFFC renders as tofu, exactly what R7 exists to prevent. "P2 requires E2" was necessary but INSUFFICIENT -- E3, E4 and E7 all edit the same controller class A4 has P2 grow, so P2 waits for the entire editor ladder. Rejected rebasing P2 through E3-E7: four rebases of the second-largest phase through a class still being rewritten under it, the shape 2026-07-28-stacked-msps-ship-sequentially forbids. P0 and P1 are the only genuinely parallel pair. KNOWN REFINEMENT, unapplied: P1 needs nothing from E0, so {E0 parallel P1} then P0 is also valid and slightly faster; the shipped order is over-constrained but safe.
