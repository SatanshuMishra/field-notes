---
Status: accepted
Date: 2026-08-03T06:48:04.845Z
Thread-Id: 01KZ33PK4E5RN3G6MD458S2N5D
---

# 0004. Underline is dropped; E5 ships four toolbar buttons, not the prototype's five

## Context

Enumerating the grammar for E0's acceptance criteria surfaced a hole no audit or reviewer reached: standard markdown has NO underline syntax. The prototype's U button is document.execCommand('underline') producing a <u> tag. In a markdown-source-of-truth buffer that button has nothing to write, so E5 could not be specified.

## Options

- Drop underline; four toolbar buttons (CHOSEN)
- Invent __text__ as underline syntax
- Allow raw inline HTML <u> in the grammar

## Outcome

DROPPED by the user 2026-08-03. E5 ships B, I, <> (inline code) and the highlight diamond -- four controls, diverging from the prototype by exactly one, and the divergence is intended. Rejected __text__ because CommonMark assigns it to strong, so every other reader renders it BOLD -- silent corruption, the worst of the three outcomes. Rejected raw inline <u> because it widens the grammar to arbitrary HTML for one control. Both break the portability that is the whole reason this substrate beat three editor packages: the export round-trips textContent verbatim, and a note must stay readable markdown outside this app. Follows the project's standing rule -- adopt the prototype's FORM, never its PROMISES -- since a U button that cannot persist what it claims is a promise the storage cannot keep. ASYMMETRY, deliberate: ==highlight== STAYS even though it is also not CommonMark, because it has a real syntax that DEGRADES GRACEFULLY (another reader shows ==text== as literal visible characters, so content survives and only emphasis is lost). Underline has no representation at all. Different failure modes, different calls.
