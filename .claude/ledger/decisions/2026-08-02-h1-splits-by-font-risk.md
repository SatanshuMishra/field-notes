Status: accepted
Date: 2026-08-02
Thread: prototype-design-alignment

## Context
The parent spec declares Cluster H as ONE MSP. The user directed it to ship as a stack, and the
families differ in risk: text-bearing captures depend on the font-weight verdict; painters do not.

## Decision
H1 decomposes into four stacked MSPs ordered by FONT RISK, not convenience: H1 harness plus the
three text-free cross-hatch goldens, H2 the blooms, H3 sticker cards plus nav icons, H4 the three
text-bearing sticker buttons at the TOP of the stack.

## Consequences
- The text-bearing family can be dropped or re-captured without losing the harness beneath it, and a
  red in H1 is a harness failure and nothing else.
- Each MSP is additive and independently green, so the invariant holds at every layer and the stack
  merges top-down. Stack 127 (#122, #123-#126); every MSP predicted exactly — 922, 934, 941, 944.
- The bloom set covers TWELVE kinds, not the spec's ten: FlowerKind declares twelve of which two are
  `ambientOnly`, and covering all twelve costs nothing.
