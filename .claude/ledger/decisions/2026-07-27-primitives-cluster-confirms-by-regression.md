Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
After Cluster A merged and validated, the Today screen looked unchanged against the prototype — old flower art, dashed mood prompt, shadowed rail cards. This read as "the merge did nothing." It did not. Cluster A is 5 of 39 MSPs and contains NO screen-composition MSP: A1/A2/A4/A5 ship tokens, typography metrics, sticker primitives and cross-hatch geometry; A3 fixes a dialog ancestor. Today is C1-C7, right rail D1-D4, nav rail B1-B4, flower art E1-E4, picker F1-F4, composers G1-G8.

## Decision
A primitives-only cluster is confirmed by REGRESSION, never by prototype match. Ask "did the primitives break the screens that consume them?", not "does this screen look like the prototype?" A prototype-match check is valid only for the cluster that owns that screen.

## Consequences
- Cluster A's real confirmation surface is A2's 33 `captionSans` and 9 `bodySerif` consumers plus A4's 20 secondary `StickerButton` sites across Calendar, Garden, Search, Day Detail and Settings — screens no later MSP revisits.
- Evidence the primitives DID land is visible without any screen changing: secondary buttons render flat while the primary coral button keeps its shadow (A4), and the date headline carries `displaySerif` w500/1.0 (A2).
- The flower DOMAIN MODEL is correct and always was (spec §1: it matches the prototype's `FLOWERS` map one-for-one). What is old is `FlowerPainter`, which draws a stem and leaf and squashes the bloom into the top ~55%; the prototype's glyphs are headless. That is E1-E3, undispatched.
- Applies to any future foundation cluster, not just A.
