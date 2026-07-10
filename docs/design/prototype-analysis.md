# Field Notes — Prototype Analysis

Source: Claude Design project `eafe8d73-b380-44be-9b2e-6431c0f35f26`.
Primary prototype: `Field Notes.dc.html` (a self-contained React-in-HTML prototype, ~183 KB).
Design intent board: `Journal Directions.dc.html` (an exploration board of many variants — 1a/1b/1c, 4a, 5a, 6a/6b, 7a/7b/7c, etc. — that converged into the final prototype).
Support files: `support.js`, `md-scrapbook.js` (runtime scaffolding; not needed for design intent).
Binary references (not read as content): `uploads/*.png` — 7 pasted reference images.

The app brands itself **"field notes — a journal of days."** It renders TWO device frames side by side: a macOS desktop window (traffic-light chrome, left sidebar rail) and a phone (bottom tab bar). Both share one data model and skin.

---

## 1. Screen / flow inventory

Views (both desktop + phone): `today`, `calendar`, `garden`, `search`, `settings`. Plus a Day-detail modal, a mood-picker modal, a capture composer/recorder, and a chooser sheet.

| Screen | What it does |
|---|---|
| **Today** (home) | Capture-first. Greeting + long date; today's mood-flower banner (or "How are you feeling today?" prompt if unset); a feed of today's entries (note/voice/video cards with attached photos). Desktop adds a right rail: "this week's garden" (7-day mini bloom grid), "capture a moment" buttons, and an "on this day" past-year memory card. |
| **Calendar** | Month grid; each journaled day renders its mood-flower in the cell. Prev/next month chevrons. "Tap a day to open it." Titled under the eyebrow "explore." |
| **Garden** | A SEPARATE ambient animated meadow: all of the year's blooms planted in soil, with sun, haze, drifting butterflies + a bee, and a mood-tally chip row (count per mood). "Every day, a bloom." Not a grid — a decorative scene. |
| **Search** | Titled "Your days" with a "Search your days…" text bar and a scrollable LIST of past days (flower + entry count + one-line preview per day). No mood/media filter chips. This is the closest thing to "Explore." |
| **Settings** | Scrollable card sections: Sync & storage, Reminders & sound, Journal, Data. (Full field catalog in §3.) |
| **Day detail** (modal overlay) | Opened from Calendar/Search/week grid. Header with day title + subtitle; mood banner with "Change mood"; entry count + "Add a note"; per-entry cards with Edit/Delete; inline photos. Not a full nav destination. |
| **Mood picker** (modal) | Grid of the 10 mood-flowers to pick the day's single bloom. |
| **Composer / recorder** (overlay) | Text composer (writing surface + "Add memory" to attach photos), and voice/video recorders that ARM idle then record (blinking dot, waveform). |
| **Chooser** (sheet) | "Capture a moment" — Write a note / Record voice / Record video. On phone this is the center "+" tab. |

---

## 2. Design tokens

### Typography
- **Newsreader** (serif) — journal/body text, dates, entry prose (weights 400/500/600, italic used).
- **Instrument Sans** (sans) — all UI chrome, labels, buttons (400/500/600).
- **Caveat** (handwritten cursive) — accent labels, section eyebrows, streak count, brand wordmark (500/600/700).

### Color palette
| Role | Hex |
|---|---|
| Page background | `#d9cbb2` with radial gradient `#e6d8bf` → `#cdbd9f` |
| App panel bg | linear `#efe2ce` → `#e9dcc4`; warm radial coral tint `rgba(199,106,84,.07)` |
| Card surfaces | `#f8efe0`, `#fff5ea`, `#fffaf1`, `#f6efe0` |
| Ink / outline / dark text | `#4a3b2e` (signature dark-brown outline everywhere) |
| Primary accent (terracotta/coral) | `#c76a54`; hover `#9a4832`; link `#b45c44` |
| Sage green (section headers) | `#7d8450` |
| Muted text | `#a08a70`, `#8a7358`, placeholder `#b3a58c` |
| Danger | text/border `#c0392b` on bg `#fbecea` |
| Title bar | `#e4d6bf`; traffic lights `#ff5f57` / `#febc2e` / `#28c840` |
| Status dot (amber, "not connected") | `#c9821f` |
| Garden greens (sky→soil) | `#d6dbac` `#c4ce95` `#b1bd80` `#a0b371` `#96aa69`; soil `#8a6c44` `#775a37`; sun glow `rgba(244,201,96,.55)` |

### Cel-shaded / hand-drawn treatment
Everything is a **sticker cutout**: surfaces carry a `1.5px solid #4a3b2e` outline plus a **hard offset drop-shadow** (`box-shadow: 3px 3px 0 rgba(74,59,46,.2)` on cards, `1.5px 1.5px 0 #4a3b2e` on buttons) — no blur, giving the flat 2D cel look. **Dashed** `#4a3b2e` borders (varying alpha) are used for dividers, the nav rail edge, empty states, and mood prompts. Photo/video placeholders use **cross-hatch** `repeating-linear-gradient(45deg, …)` textures. Radii ~11–20px. Mood **flowers are hand-drawn inline SVG blooms** with dark strokes (cel-shaded petals). Paper/grain is faked with radial gradients; handwritten Caveat labels reinforce the crafted feel.

### Motion
CSS keyframes: `fn-blink` (recording dot), `fn-pulse` (glow), `fn-bob` (waveform bars), `fn-rise`/`fn-pop`/`fn-sheet` (toast / modal / bottom sheet entrances), `fn-gsway`/`fn-gsway2` (garden stems swaying), `fn-wing` + `fn-fly1/2/3` (butterfly wing-flap and flight paths, bee), `fn-grow` (flowers sprouting), `fn-fade`. Optional sound effects (page turns, pencil, chimes) gated by a Sound toggle.

---

## 3. Settings page field-style catalog

The Settings screen is explicitly a **style reference for every settings control**. Each control sits in a card section (`#f8efe0`, `1.5px #4a3b2e`, radius 16, hard shadow `3px 3px 0`), rows separated by a **dashed top divider**, with a **label + muted description on the left, control on the right**.

- **Section header** — Caveat cursive sage-green (`#7d8450`) title + Instrument Sans muted subtitle.
- **Segmented control (radio)** — "Storage mode" (On this device / Sync to server): inset pill track `#efe2ce` with a raised selected segment.
- **Text input** — "Server URL" (`type=url`): `#fffaf1` fill, `1.5px` border, radius 11, coral focus border.
- **Secret / password input** — "Access token" (`type=password`) with dotted placeholder.
- **Dropdown / select** — "Sync frequency" and "Week starts on": native `<select>` styled like the text input.
- **Toggle / switch** — "Daily reminder" and "Sound effects": track + sliding knob.
- **Time input** — "Reminder time" (`type=time`, default 20:30).
- **Slider / range** — "Text size" (`range` 1–3, coral accent-color).
- **Status pill + primary button** — a status chip (colored dot + "Not connected") paired with a filled coral "Test connection" button (hard shadow).
- **Secondary button** — "Export…": light fill, dark outline, hard shadow.
- **Destructive / danger button** — "Delete all…": red text/border on `#fbecea`.
- **Conditional / dependent fields** — server fields (URL, token, frequency, status) appear only when "Sync to server" is selected; an on-device explanatory note appears when it is off.

---

## 4. Product model as depicted

- **Days** — a day has a long date, an optional single mood-flower, and a set of entries. Days are the unit browsed in Calendar (grid), Garden (meadow), and Search (list), and opened via the Day-detail modal.
- **Entries** — three capture kinds: **text** (note), **voice** (play button + waveform + duration), **video** (thumbnail placeholder + duration). Entries carry a timestamp, a type label, Edit/Delete actions in the day view, and optionally attached photos.
- **Memories / photos** — photos are attached to an entry via **"Add memory"** inside the composer (not a standalone entry type). They render inline under the entry. There is an **"On this day"** widget resurfacing a memory from a year ago. There is **no dedicated day-level pooled Memories gallery**.
- **Moods & flowers** — exactly ONE optional mood-flower per day. Mapping in the prototype matches the agreed palette 1:1: happy=Peony, love=Rose, warm=Sunflower, calm=Lavender, grateful=Chrysanthemum, hopeful=Daffodil, anxious=Aster, tired=Poppy, sad=Bleeding Heart, angry=Red Spider Lily. `MOOD_ORDER` = happy, love, warm, grateful, hopeful, calm, anxious, tired, sad, angry. (Extra non-selectable decorative blooms exist for the garden: "Wilting rose", "Thistle".)
- **Streak** — displayed as "12 days / longest streak yet" with a flame icon in the nav rail. Underlying rules (entry-or-photo keeps it, midnight boundary, miss resets) are not depicted, not contradicted.
- **Reminders** — Settings "Daily reminder" toggle + "Reminder time" (20:30). Auto-suppress-when-logged is backend, not shown.
- **Navigation** — Desktop: left sidebar rail (Today / Calendar / Garden / Search) + streak card + Settings/Sound buttons at the bottom + a "Synced to home · your server" status line. Phone: 5-slot bottom bar (Today, Calendar, **center "+" capture**, Garden, Search); Settings reached via a gear.

---

## 5. Sync / server settings UI (standalone mode)

Standalone mode **is** represented. The "Sync & storage" section leads with a segmented **Storage mode** control: **"On this device"** vs **"Sync to server."**
- When **On this device**: a note reads "Entries are stored only on this device. Nothing is uploaded and there is no syncing across devices." No server fields shown.
- When **Sync to server**: reveals **Server URL** (`https://journal.example.com`), **Access token** (password), **Sync frequency** dropdown (Real-time / Every 15 minutes / Hourly / Manual only), and a status pill ("Not connected") + **Test connection** button.

The desktop nav rail currently hard-codes a "Synced to home · your server · just now" status (i.e., the prototype's default rendered state assumes a server is connected). No E2EE key / passphrase / recovery-phrase field, and no device-pairing / device-id UI is shown.

---

## 6. Conflicts, gaps & ambiguities vs agreed requirements

Numbered as answerable questions.

### Navigation & screens
1. **Calendar vs Garden split.** The agreed spec has ONE "Calendar Garden" (a month grid where each journaled day blooms its mood-flower). The prototype ships TWO separate destinations: **Calendar** (the month grid) AND **Garden** (a separate ambient animated meadow of all blooms). Do we keep both as distinct screens, merge them, or drop the ambient Garden?
2. **Explore vs Search.** Agreed "Explore" is a **reverse-chronological ENTRY feed with mood + media-type filters** plus on-device text search. The prototype's equivalent ("Search" / "Your days") is a **DAY list** with a text-search bar only — **no mood/media filter chips and no entry-level feed**. Which do we build, and is it named "Explore" or "Search"?
3. **Day view as modal.** Agreed lists "Day view" as a primary navigation destination. The prototype implements it as a **modal overlay**, not a full screen. Is a modal acceptable (esp. on Android), or should Day be a full pushed screen?
4. **Nav structure confirmation.** Confirm the intended structure: desktop left sidebar rail vs phone 5-slot bottom bar with a center "+" capture, and Garden as its own tab on both. Agreed named only 4 areas (Today, Calendar Garden, Day, Explore); the prototype has 5 (Today, Calendar, Garden, Search, Settings).

### Data model & memories
5. **Day-level Memories gallery is missing.** Agreed: each Day has a Memories gallery pooling that day's photos, browsable independently, tapping one jumps to its parent entry. The prototype only attaches photos to entries inline ("Add memory") plus an "On this day" resurfacing card — **no pooled day gallery**. Add the day Memories gallery as specified, or is inline-on-entry enough for v1?
6. **Photos are always attached to an entry.** In the prototype there is no standalone photo-only entry; photos are "memories" added to a note/voice/video entry. Confirm a bare photo (no entry) is still a valid capture that keeps the streak, per the agreed streak rule ("any Entry OR photo that day keeps it").

### Moods
7. **Mood count.** The prototype and the agreed list both use **10** moods with an identical flower mapping (good). But the Journal Directions board still says "your **seven** moods." Confirm 10 is final, and confirm the decorative non-mood blooms ("Wilting rose", "Thistle") are purely ambient garden filler, not selectable.

### Sync / server / encryption
8. **User-facing "Sync frequency" control.** The prototype exposes Real-time / 15 min / Hourly / Manual. The agreed design is continuous per-record last-writer-wins over a Tailscale mesh. Do we surface a sync-frequency setting at all, or is sync always automatic/continuous (drop the dropdown)?
9. **E2EE + device pairing UI is absent.** Agreed: client-side libsodium E2EE (server stores ciphertext only) with per-device version + device-id. The prototype's server settings show only Server URL + Access token — **no encryption passphrase / key / recovery-phrase field and no device-pairing/device-id UI**. What encryption-key and device-pairing controls belong on the settings page, and how is the key entered/recovered on a second device?
10. **Default first-run = standalone.** The Storage-mode control supports on-device-only, but the nav rail hard-codes "Synced to home · your server." Confirm the app **defaults to standalone/on-device** on first run with no server configured, and that the rail status is dynamic (hidden/"local only" when no server).

### Media
11. **Video length cap + thumbnails.** Agreed: video soft cap ~5 min (tunable) and an on-capture thumbnail. The prototype recorder shows **no duration cap and no thumbnail-generation cue**. Confirm the ~5 min soft cap, and whether the recorder needs any UI for it (countdown / limit indicator) or enforces it silently.

### Naming & vocabulary
12. **Product name & vocabulary.** The app is branded **"Field Notes — a journal of days"**; user-facing nouns are "entries," "memories" (for photos), "blooms/flowers" (for moods), and the browse surface is "Search"/"Your days." Confirm "Field Notes" is the final product name (vs generic "journal") and that this vocabulary is intended.

### Extra features (more than agreed) — scope for v1?
13. Confirm in/out for v1 for prototype additions beyond the agreed scope: (a) "this week's garden" 7-day mini-garden on Today; (b) the ambient animated Garden meadow (butterflies/bee); (c) **sound effects** + Sound toggle (page turns, pencil, chimes); (d) **Text-size** slider and **Week-starts-on** setting; (e) **Export entries** + **Delete-all-data**; (f) **"On this day"** past-year resurfacing.

### Theme
14. **Dark mode.** The Journal Directions board explored a "cozy evening dark mode," but the final prototype is **light-only** (warm paper). Is a dark mode in scope for v1, or light-only?
