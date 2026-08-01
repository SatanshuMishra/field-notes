Status: accepted
Date: 2026-07-29
Thread: prototype-design-alignment

## Context
Pre-dispatch recon on Cluster D found TWO MSPs carrying the exact defect shape that cost C5 its caption and C7 three rows: a target value whose anchor is unreachable inside the MSP's declared fence. Unlike C5 and C7, both were caught BEFORE a slice was cut, so both are resolved in the slice rather than discovered by an implementer and deferred. D4's target row specifies a serif title, but `OnThisDayMemory` (`lib/features/today/today_memory.dart:10-29`) carries only `day` and `yearsAgo` — the prototype's "The garden last summer" is hardcoded mockup filler at `Field Notes.dc.html:176`, bound to no data. D3's target label is `captureLabelSans` (12px), but `StickerButton` hardcodes `TypographyTokens.buttonSans` (15px) at `sticker_button.dart:62-66` with no override param, and that file is outside D3's declared fence and shared with the nav footer, mood banner and delete-all dialog.

## Decision
D4 REPURPOSES the existing preview snippet as the serif title rather than deleting it — same data, prototype form, no domain change. D3 gains an OPTIONAL `labelStyle` param on `StickerButton`, default unchanged, declared in the slice as a one-file fence widening.

## Consequences
- D4's spec row "removes the 2-line preview" is re-read as a RESTYLE, not a deletion. Without this the card would carry only a hatch band and a date — a net information loss against what ships today. The domain model is untouched, so OQ-6 is not answered as a side effect (the mistake C5's caption was blocked to avoid).
- D3's additive-param shape mirrors C6's optional `headline` slot. Every other `StickerButton` consumer is untouched and their existing tests MUST pass unmodified — which the C slice itself calls a stronger receipt than a new test. Rejected: editing the hardcoded style in place (silently restyles four unscoped consumers), and duplicating the geometry into a rail-only widget (the primitive-forking move already rejected for C7's transport).
- Both resolutions are receipted, not reasoned. This is the rule C's §0 resolution 6 broke: it mandated dropping `NeutralMediaPlaceholder` on reasoning alone and reddened an N24 file the moment an implementer tried it. Every §0 resolution in the D slice names the test that would red if it is wrong.
- D4 still needs a short-date formatter (`'Jul 5, 2024'`); `today_date.dart:53-55` has only `longDateLabel`. That is additive and inside D4's declared fence.
