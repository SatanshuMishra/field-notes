# Audit — the prototype's note editor (real vs cosmetic)

Date: 2026-08-02. Read-only audit. Feeds the combined rich-editor + OQ-6 spec.

## Verdict

The **editor is substantially REAL** — markedly more so than the photo layer, which a prior audit found
hollow. It is a genuine `contenteditable` block editor (`md-scrapbook.js:67-74`) with a working
transform-on-type markdown parser, a toolbar wired to real DOM mutation, and working list continuation.
Rich formatting DOES round-trip on re-edit because raw HTML is persisted and reseeded into
`editor.innerHTML`.

Two things must NOT be copied as reference behavior:

1. **The read-only view never renders the persisted HTML.** It shows flattened plain text, so all
   structure is invisible outside edit mode.
2. **Reopening a note with photos silently drops them**, and a subsequent save overwrites the entry's
   `photos` with `undefined` — permanent data loss. A code-provable bug, not a demo simplification.

## Host element

`div.ms-editor`, built imperatively by `MarkdownScrapbook._build()`, `contentEditable='true'`,
`spellcheck=false` — `md-scrapbook.js:67-74`. Mounts into an empty template placeholder: desktop
`Field Notes.dc.html:469`, phone `:770`, wired via `_engRef`/`_mountNote` at `:1360-1369`.

CSS: `.ms-editor{position:relative;z-index:2;outline:none;font-size:19px;line-height:38px;min-height:60px;}`
— `md-scrapbook.js:110-111`. Font and ink set inline at `:71-72` (`'Newsreader', Georgia, serif`).

## Toolbar — all five controls are REAL

Defined `md-scrapbook.js:88-93`, wired `:158-161`, dispatched by `_cmd` `:296-304`.

| Control | data-cmd | Action | Verdict |
|---|---|---|---|
| B | `bold` | `document.execCommand('bold')` | REAL |
| I | `italic` | `document.execCommand('italic')` | REAL |
| U | `under` | `document.execCommand('underline')` | REAL |
| `<>` | `code` | `_wrapSel('code')` wraps selection in `<code>` | REAL |
| ◆ (U+25C6) | `hilite` | `_wrapSel('mark')` wraps selection in `<mark>` | REAL |

`_wrapSel` (`:306-320`) toggles off when the parent already matches the tag. The toolbar appears only on
a non-collapsed selection via `selectionchange` -> `_selChange()` (`:157`, `:285-294`); dark styling `:130`.

## Markdown shortcuts — all REAL, transform-on-type

`_transform()` at `md-scrapbook.js:196-221`, invoked from the editor's `input` listener at `:154`.
These mutate live DOM blocks; nothing re-parses raw markdown on load.

| Token | Result |
|---|---|
| `# ` / `## ` / `### ` | `data-type=h1/h2/h3` |
| `- ` / `* ` / `+ ` | `data-type=bullet` |
| `1. ` (any `\d+.`) | `data-type=number`, renumbered every input via `_renumber()` (`:265-271`) |
| `> ` | `data-type=quote` |
| `[]` / `[ ]` | `data-type=todo`, clickable checkbox via `_edClick` (`:273-282`) |
| `---` / `***` | `data-type=divider` — undocumented bonus, not in the hint bar |

Hint-bar text is exactly the five documented tokens — `Field Notes.dc.html:473`.

## There is NO separate title field

One `contenteditable` region only. The large serif "title" is just a block the user turned into
`data-type="h1"` by typing `# ` (34px bold serif, `md-scrapbook.js:114`). No `composerTitle`/`noteTitle`
content field exists in either JS file. The `{{ composerTitle }}` at `Field Notes.dc.html:465` is the
modal's chrome label ("New note" / "Edit note", set at `:1694`), not note content.

## Save path

`saveText(dev)` — `Field Notes.dc.html:1381-1393`. Reads `getText()` (`md-scrapbook.js:455`,
`editor.innerText` trimmed), `getHTML()` (`:456`, `editor.innerHTML`), `photoCount()` (`:457`).
New note stores `{type:'note', text:t, html}` (`:1389`). Edit routes through a confirm dialog to
`doSaveEdit(dev, ref, t, html, pc)` (`:1353`), merging `{...e, text:t, html}`.

**Both HTML and plain text are stored**, in parallel.

## Round-trip — three different answers

| Surface | Status | Evidence |
|---|---|---|
| Text formatting on re-edit | REAL | `beginEditNote` seeds `{html: entry.html}` (`Field Notes.dc.html:1351`); `_seed()` sets `editor.innerHTML = s.html` (`md-scrapbook.js:460-468`) |
| Read-only display | NEVER RENDERS RICH | day detail renders `{{ e.text }}` only (`Field Notes.dc.html:410`, `white-space:pre-wrap`); `e.html` is spread through `mapEntry` (`:1569-1584`) but referenced by no template |
| Photos on re-edit | BROKEN, DATA LOSS | `_pendSeed[dev]` never includes `photos` (`:1351`); `_seed()` only re-adds when `s.photos` is truthy (`md-scrapbook.js:466`, `:479-482`); re-save then sets `n.photos = pc>0 ? [...] : undefined` (`:1353`), destroying the record |

## Absent entirely

- Nested lists / indent — no `Tab` handling anywhere
- Custom undo/redo — only the browser's native contenteditable stack
- Links — no `<a>` creation, no URL detection
- Backtick-triggered inline code — toolbar only

Present but easy to miss: list continuation on Enter (`md-scrapbook.js:230-241`, `_splitBlock` `:250-263`,
including exit-on-empty-item), backspace demoting a list/heading back to `p` (`:242-247`), and
⌘B/⌘I/⌘U keyboard shortcuts (`:224-229`).

## What would mislead a Flutter implementer

- **Treating `entry.html` as the canonical displayed representation.** It is write-only, for the edit
  round-trip. Building a Flutter reader that renders rich text is MORE correct than the prototype, not a
  faithful port of it.
- **Assuming photos survive an edit.** They are destroyed on reopen-and-resave. Do not replicate.
- **Assuming a title/body split.** There isn't one.
- **Assuming ◆ is a placeholder.** It is a real highlight-wrap (`<mark>`).
- **Assuming markdown is parsed at load.** It is transform-on-type against DOM blocks; seeding is
  HTML-based, never markdown-based.
- **Assuming undo/redo, nested lists, or links exist to reference.** None do.

## Target feature set this bounds

h1/h2/h3, bullet, numbered with auto-renumber, quote, clickable to-do, divider, bold, italic, underline,
inline code, highlight, list continuation on Enter, backspace demotion, ⌘B/⌘I/⌘U. Nothing more.
