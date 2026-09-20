# Research — Flutter rich markdown editor packages

Date: 2026-08-02. External research. Feeds the combined rich-editor + OQ-6 spec.

## BLUF

**No candidate cleanly fits both hard constraints.** This is a real trade-off, not a one-sided pick.

All three genuine WYSIWYG editors (super_editor, flutter_quill, appflowy_editor) internally store a
**structured document model, not markdown**. None is markdown-source-of-truth. For the no-migration
constraint, every one requires the same mitigation: persist plain markdown, use the library's markdown
codec as a **transient in-memory transcoder** on load/save. That puts a lossy-transcode risk on every
single save of a journal entry.

Least-bad package: **super_editor**, pinned to a specific dev prerelease and vendor-tested — the only one
whose inline-embed mechanism is a foundational primitive rather than a bolt-on. Confidence: `[Medium]`,
contingent on a round-trip spike not yet run.

Equal-weight alternative: **hand-roll on Flutter's own `TextField`/`EditableText` + `TextSpan`/`WidgetSpan`**
with a small regex markdown parser. Only option that trivially satisfies no-migration (markdown IS the
storage, zero codec risk) and gives full first-party control of `WidgetSpan` placement for the photo anchor.

## Comparison

| Criterion | super_editor | flutter_quill | appflowy_editor | re_editor | flutter_markdown(_plus) |
|---|---|---|---|---|---|
| Version | 0.2.7 stable / **0.3.0-dev.52** | 11.5.1 | 6.2.0 | 0.10.0 | 1.0.12 (`_plus` fork) |
| Last release | dev.52 ~52d; **stable is years old** | v11.5.1, 2026-05-20 | v6.1.0, 2025-12-08 | 32d | 23d |
| Repo health 2026 | push 2026-07-01; 1,927 stars; **319 open issues** | push 2026-06-29; 2,917 stars; **359 open issues** | push 2026-07-27; 671 stars; 151 open | small, active | active fork |
| Maintained | Yes, but **no stable cut in years** | Yes, real semver releases | Yes | Yes | Yes |
| Flutter 3.44.8 compat | `[unverified]` | `[unverified]` | repo merged **Flutter 3.27.4** as of Jul 2026 — behind pin `[Medium]` | `[unverified]` | `[unverified]` |
| macOS/iOS bugs | JP IME caret jump (#2993), IME serialization gaps (#3016), IME logging (#3036) | wrong caret (#2743), macOS selection (#2593), macOS keyboard (#2606), JP IME dup (#2178) | IME char reorder (#696), caret misalign (#1140), macOS NSInvalidArgumentException crash (#1106) | n/a | n/a |
| **Storage model** | structured `Document`/`DocumentNode` tree; markdown is a first-party codec | **Delta JSON** — maintainers recommend Delta *over* markdown | structured Node tree; first-party markdown codec | plain text | n/a (render-only) |
| MD round-trip tested | first-party codec, no dedicated suite found `[unverified]` | via **third-party `markdown_quill`, "unverified uploader"** | first-party decoder unit tests; no lossless claim `[Medium]` | n/a | n/a |
| **Inline embed at text position** | **Yes, primitive-level** — `AttributedText` inline placeholder attributions `[Med-High]` | block embeds only in official docs `[Medium, needs spike]` | **Not confirmed** — block/node-oriented `[Low — highest disqualification risk]` | no | no |
| MD typing shortcuts | reactions pipeline present `[Medium]` | **None** — `characterShortcutEvents: []`, hand-roll all | built-in heading/bullet/ordered/quote/todo `[Med-High]` | n/a | n/a |
| License | MIT | MIT | **dual MPL-2.0 / AGPL-3.0** | MIT | BSD-3 |
| Deps / native | 13, first-party FBH, no platform channel | 13, incl. `quill_native_bridge` (**native channel**) | 18, incl. `pdf`, `file_picker` | 3 (lightest) | minimal |
| Disqualified? | No | No | **At risk** — license + inline embed | **YES** | **YES** |

Sources: [pub.dev/super_editor versions](https://pub.dev/packages/super_editor/versions),
[pub.dev/flutter_quill](https://pub.dev/packages/flutter_quill),
[pub.dev/appflowy_editor](https://pub.dev/packages/appflowy_editor),
[pub.dev/re_editor](https://pub.dev/packages/re_editor),
[pub.dev/markdown_quill](https://pub.dev/packages/markdown_quill),
[quill customizing_shortcuts](https://github.com/singerdmx/flutter-quill/blob/master/doc/customizing_shortcuts.md),
[quill custom_embed_blocks](https://github.com/singerdmx/flutter-quill/blob/master/doc/custom_embed_blocks.md),
[super_editor markdown export guide](https://supereditor.dev/super-editor/guides/markdown/export/).

## Disqualified outright

| Option | Disqualified by | Confidence |
|---|---|---|
| `flutter_markdown` / `flutter_markdown_plus` | Render-only. No text input, no caret, no editing. Not an editor. | High, primary-sourced |
| `re_editor` | Plain-text/code editor with syntax highlighting. Headings don't get bigger, bullets aren't indented widgets, checkboxes aren't controls. Fails "displays in RICH FORMAT". | High |
| `appflowy_editor` | AT RISK, not confirmed: (a) AGPL-3.0 needs legal clearance; (b) inline-embed-at-text-position unconfirmed against the stated hard rule. | Medium — open question |

## Against, per candidate

**super_editor** — No stable release since 0.2.7 (years old). Shipping means pinning a `0.3.0-dev.NN`
with no semver contract; that is the opposite of robust. Three open desktop IME bugs. Markdown
round-trip losslessness never independently verified.

**flutter_quill** — Storage mismatch is maintainer-stated, not inferred: they recommend Delta JSON over
markdown. Round-trip depends on an unofficial "unverified uploader" package. **Zero** built-in markdown
typing shortcuts — all six required must be hand-written and hand-tested anyway, which erases much of the
reason to take the dependency. Highest open-issue count and a recurring macOS caret/selection pattern.

**appflowy_editor** — AGPL-3.0 is a likely blocker pending the distribution answer. Inline embed is the
least confirmed of the three and touches the stated disqualifying criterion directly. Heaviest dependency
footprint (18, including `pdf` and `file_picker`) for a text-editing need, cutting against SIMPLE.

## The hand-rolled alternative, stated honestly

Only option where markdown stays the literal storage format — zero codec, zero transcode, zero round-trip
corruption risk — and `WidgetSpan` is a first-party Flutter API rather than a third-party abstraction.

Counter-argument, from the researcher verbatim in substance: rolling your own rich-text editing surface is
a famously hard problem. Caret math across live re-formatting, IME composition edge cases, undo/redo, and
floating-toolbar positioning are exactly what Quill/Slate/ProseMirror/Lexical exist to absorb after years
of hardening. It is not automatically "simple" for avoiding a dependency — it trades dependency risk for
in-house maintenance risk. `[Low-Medium confidence as a recommendation — worth a timeboxed spike, not a default]`

The bounded feature set (see the prototype audit: 12 features, no nested lists, no links, no undo/redo)
is what makes this viable at all. The companion substrate research decides it.

## Pre-mortem — super_editor adopted, fails in six months

1. **A pinned `0.3.0-dev.NN` breaks on upgrade.** No semver contract; an API rename lands with no
   deprecation window. Team either freezes on a stale dev build accumulating the already-open IME/caret
   bugs, or absorbs a breaking upgrade under pressure. `[High likelihood]` — the single biggest risk found,
   and it directly contradicts "robust".
2. **Markdown round-trip proves lossy for this feature set** — todo checked-state, or the future U+FFFC
   photo anchor, fails a decode/encode cycle and **silently corrupts notes on save**. Never verified.
   `[Med-High if unspiked]`
3. **A macOS/iOS IME or caret edge case** surfaces for an input method outside the team's test matrix.
   `[Medium]` — empirically real for every editor evaluated, not unique to super_editor.
4. **The inline-embed mechanism wasn't built for a floated, rotated, text-wrapping card** — discovered only
   when OQ-6 is built. `[Medium]` — mitigate by spiking the photo embed BEFORE committing to the editor.

**What would change the recommendation:** a hands-on round-trip spike (markdown -> Document -> markdown
across every required syntax element) with zero loss, plus a working inline-embed prototype for a floated
image, raises it to High. If either fails, the hand-rolled path becomes primary.

## Not researched, do not treat as ruled out

`markdown_editor_live`, `textf` (lightweight inline-placeholder text renderer, not a full editor).
Flagged `[unverified, deprioritized]` for context budget.

## Open question for the product owner

The AGPL-3.0 assessment assumes closed-source commercial distribution. If field-notes is not distributed,
or is distributed under a compatible license, appflowy_editor's licence objection weakens and its
first-party tested codec and built-in shortcuts become more attractive — though its unconfirmed inline
embed remains the harder blocker.
