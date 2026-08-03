---
Status: accepted
Date: 2026-08-03T06:37:15.390Z
Thread-Id: 01KZ33PK4E5RN3G6MD458S2N5D
---

# 0002. The P0-P5 photo ladder survives flutter#82595 intact; no phase is abandoned

## Context

The thread's standing open question and the reason the spec was blocked: flutter#82595 (open since 2021) means text cannot wrap around an inline object inside an EditableText. The thread's next_step required P3-P5 to be re-read against it, on the suspicion that the float model was dead.

## Options

- Abandon P3-P5 and ship the photo feature at P2 (full-width block only)
- Keep P3-P5 -- the limit is scoped to editable text and the float lives in the read view (CHOSEN)
- Re-architect the float onto a custom RenderBox or a WebView text layer

## Outcome

SURVIVES. No phase abandoned, no outcome changed. #82595 is scoped to a WidgetSpan inside a TextField/EditableText; the float in P3-P5 lives in NoteBody and arrange mode, neither editable, and OQ-6's decision plus R22/M3 already made write mode plain text. The reasoning was SHARPENED during hardening after a reviewer correctly found the first draft leaning on an unsupported inference (that a non-editable Text CAN wrap around an inline span -- #82595's text does not say that). The verdict does not need it: R15's float never puts the card in a span tree at any layer. It is LayoutBuilder + Stack + TWO SEPARATE Text widgets with the paragraph split manually at a TextPainter-computed offset, so nothing is ever asked to flow around an inline object and the issue's reach is irrelevant. Written into the spec as an implementer trap: do NOT simplify R15 by putting the photo in a WidgetSpan inside one Text.rich and expecting flow -- the obvious shortcut, and the one thing #82595 guarantees fails. What the editor DOES change is real: after E1 NoteBody is a span tree, so splitForFloat takes an InlineSpan and text.substring becomes splitSpanAt (A1), which is UNSPIKED.
