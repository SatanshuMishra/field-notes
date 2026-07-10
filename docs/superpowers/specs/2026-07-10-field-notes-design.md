# Field Notes — Design Spec (v1)

Status: draft for review
Date: 2026-07-10
Thread: journal-app-design
Supersedes/extends: decisions/2026-07-09-*.md, decisions/2026-07-10-reconciliation-resolutions.md, decisions/2026-07-10-client-implementation-stack.md

---

## 1. Summary (BLUF)

Field Notes is a personal journaling app for macOS and Android with a cozy, hand-drawn cel-shaded aesthetic. Each day holds a set of entries (text, voice, or video) plus attached photo "memories," an optional single mood-flower, a streak, and a daily reminder.

**v1 is fully local, single-device, and offline** — no server, no networking, no cryptography. It ships the entire Field Notes prototype experience except cross-device sync. The sync/server/encryption settings are rendered as a visible but disabled UI shell. Real sync arrives in v2.

The app is one Flutter codebase (macOS + Android), state managed by Riverpod, persistence by drift over SQLite, media stored on the filesystem content-addressed by SHA-256. Light theme only.

---

## 2. Scope

### In scope (v1)

The complete prototype feature set, minus server sync:

- Capture: text notes, voice recordings, video recordings, photo "memories" attached to entries.
- Today (home): greeting, today's mood-flower banner, today's entry feed; desktop right rail (this-week garden, capture buttons, "on this day").
- Calendar: month grid with each journaled day's mood-flower in its cell.
- Garden: a separate ambient animated meadow of the year's blooms, with mood tally.
- Search ("Your days"): text-search bar over a reverse-chronological day list.
- Day-detail: modal overlay (both platforms) to view/edit a day's mood and entries.
- Moods: 10 flowers, one optional per day.
- Streak: consecutive journaled days.
- Reminders: one daily local notification at a user-set time, auto-suppressed once logged.
- Settings: full field catalog including the disabled sync shell, reminders/sound, text size, week-start, Export, Delete-all.
- Sound effects (toggleable), motion/animation, empty states.

### Out of scope (v1) — deferred to v2

- All networking: REST sync, server, Tailscale, Caddy, Docker Compose.
- End-to-end encryption, recovery passphrase, device pairing (QR).
- The sync/server/encryption settings are built as UI but **disabled and inert**; storage mode is fixed to "On this device."

### Out of scope (permanently, per prior decisions)

- iOS; server-side search/thumbnails (impossible under E2EE); CRDTs; Postgres/MinIO/Cloudflare Tunnel; multi-user.
- Day-level pooled Memories gallery (dropped per reconciliation #5 — photos attach to entries inline only).
- Standalone photo-only entry (photos always attach to an entry, per #6).

---

## 3. Architecture

One Flutter codebase for macOS + Android, light theme only, organized in layers with one clear responsibility each.

| Layer | Responsibility | Key pieces |
|---|---|---|
| Design system | The "sticker cutout" cel-shaded look | `StickerCard`, `StickerButton`, `DashedDivider`, hand-drawn SVG flower set, cross-hatch media placeholders, settings-field widgets |
| Screens | The destinations + overlays | Today, Calendar, Garden, Search, Settings, Day-detail (modal), Capture (composer/recorders/chooser) |
| State | Reactive glue between DB and UI | Riverpod 3.x providers (`@riverpod` codegen); `StreamProvider`/`AsyncNotifier` over drift streams |
| Domain | Models + repository interfaces + services | `Day`, `Entry`, `EntryPhoto`, `MediaBlob`, `Mood`; `JournalRepository`, `MediaStore`, `StreakService`, `ReminderService`, `SettingsRepository`, `ExportService` |
| Data | Persistence | drift over SQLite (typed queries, migrations, reactive `.watch()`); media blobs on filesystem, content-addressed |
| Platform | OS capabilities | `camera` + `camera_macos`, `record` (audio/video), `flutter_local_notifications`, `path_provider` |

**Why this stack** (validated by cited research — see §11):
- **Riverpod 3.x** — Flutter Favorite; native drift-stream integration via `AsyncNotifier`/`StreamProvider`; no `BuildContext` coupling; testable.
- **drift** — Flutter Favorite; typed queries + built-in migrations + reactive `.watch()`; one API across macOS + Android; no cloud lock-in; `drift_sqlite_async` is a no-rewrite escalation path.

### Adaptive shell

- **macOS (desktop):** window with traffic-light chrome; left **sidebar rail** (Today, Calendar, Garden, Search) + streak card + Settings/Sound buttons at the bottom; dynamic status line ("On this device only" in v1).
- **Android (phone):** bottom **tab bar** with 5 slots — Today, Calendar, center **"+" Capture**, Garden, Search; Settings reached via a gear.
- **Day-detail** is a modal overlay on both platforms; Android hardware/gesture back dismisses it.

---

## 4. Data model

drift/SQLite schema. All timestamps are integer epoch milliseconds. Primary keys are client-generated **ULID** text (time-sortable, globally unique, safe for future cross-device merge). `PRAGMA user_version` tracks schema version for migrations.

| Table | Columns | Notes |
|---|---|---|
| `days` | `id` PK (ULID), `date` (TEXT `YYYY-MM-DD`, local), `mood_id` (TEXT?, enum value), `created_at`, `updated_at`, `deleted_at?` | One row per calendar date, enforced by a **partial unique index on `date` where `deleted_at IS NULL`** (so a tombstoned day does not block re-creating that date). `mood_id` nullable (mood optional). |
| `entries` | `id` PK (ULID), `day_id` FK→days, `type` (`text`\|`voice`\|`video`), `text_content` (TEXT?), `media_id` (TEXT? FK→media_blobs), `thumbnail_media_id` (TEXT? FK→media_blobs), `duration_ms` (INT?), `created_at`, `updated_at`, `deleted_at?` | Text entries have `text_content`; voice/video have `media_id` + `duration_ms`; video entries also carry `thumbnail_media_id` (a generated `photo` blob). |
| `entry_photos` | `id` PK (ULID), `entry_id` FK→entries, `media_id` FK→media_blobs, `sort_order` (INT), `created_at`, `updated_at`, `deleted_at?` | The "memories." Always attached to an entry. |
| `media_blobs` | `id` PK (SHA-256 hex), `rel_path` (TEXT), `mime` (TEXT), `kind` (`photo`\|`audio`\|`video`), `bytes` (INT), `width?`/`height?`/`duration_ms?`, `created_at` | Content-addressed and immutable → no `updated_at`/`deleted_at`; reclaimed by GC (§8). |
| `settings` | `key` PK (TEXT), `value` (TEXT) | Key-value. Storage mode fixed to `on_device` in v1. |

**Moods** are static in code (enum + asset map), not a table. The 10 moods and flowers (locked): Peony=Happy, Rose=Loved, Sunflower=Warm, Lavender=Calm, Chrysanthemum=Grateful, Daffodil=Hopeful, Aster=Anxious, Poppy=Tired, Bleeding Heart=Sad, Red Spider Lily=Angry. `MOOD_ORDER` = happy, love, warm, grateful, hopeful, calm, anxious, tired, sad, angry. "Wilting rose" and "Thistle" are ambient-garden-only, not selectable.

**Forward-compat for v2 sync (carried now, irrecoverable if skipped):** ULID PKs, `created_at`, `updated_at`, `deleted_at` soft-delete tombstones, SHA-256 content-addressed media. **Deferred to the v2 migration (cheap lossless backfill):** per-record `version` counter, `device_id`, sync-cursor bookkeeping.

**Streak** is derived, not stored: the count of consecutive dates (ending today, local-midnight boundary) that have at least one non-deleted entry. Longest streak is computed the same way over all history. Because a photo always implies an entry (#6), the streak rule collapses to "any entry that day keeps it."

---

## 5. Screens and navigation

Nav destinations (locked, from the prototype): **Today, Calendar, Garden, Search**, plus **Capture** ("+") and **Settings** (gear). Calendar (month grid) and Garden (ambient meadow) are distinct screens — both kept, they serve different purposes.

| Screen | Contents |
|---|---|
| **Today** (home) | Greeting + long date; today's mood-flower banner (or "How are you feeling today?" prompt); feed of today's entries (note/voice/video cards with attached photos). Desktop adds a right rail: this-week 7-day mini bloom grid, capture buttons, "on this day" past-year memory card. |
| **Calendar** | Month grid; each journaled day renders its mood-flower; prev/next month chevrons; tap a day → Day-detail. |
| **Garden** | Ambient animated meadow: the year's blooms planted in soil with sun, drifting butterflies + a bee, and a mood-tally chip row. Decorative scene, not a grid. |
| **Search** ("Your days") | Text-search bar + reverse-chronological day list (flower + entry count + one-line preview per day). No mood/media filter chips (per #2). |
| **Settings** | Card sections: Sync & storage (disabled shell), Reminders & sound, Journal, Data. |
| **Day-detail** (modal) | Day title/subtitle; mood banner with "Change mood"; entry count + "Add a note"; per-entry cards with Edit/Delete + inline photos. |
| **Capture** (chooser + composer/recorders) | "Capture a moment" → Write a note / Record voice / Record video. Center "+" tab on phone. |

---

## 6. Feature specifications

### 6.1 Capture

- **Text:** composer surface → `entries(type=text, text_content)`. "Add memory" attaches photos.
- **Voice:** arm → record (blinking dot, waveform) → stop. Writes `media_blobs(kind=audio)` + `entries(type=voice, media_id, duration_ms)`.
- **Video:** record with a **30-minute hard cap** (recording auto-stops at 30:00). **Informative soft nudges** appear at 5, 10, and 20 minutes (subtle non-blocking pop-ups; they do not stop recording). On stop, generate a thumbnail (stored as a content-addressed `photo` blob) and write `media_blobs(kind=video)` + `entries(type=video, media_id, duration_ms)`.
- **Photos ("memories"):** attach to an entry → `media_blobs(kind=photo)` + `entry_photos` row. No standalone photo-only entry.
- **Durability:** persist the entry row and finalize the media atomically per capture; a captured entry is never lost on interruption.

### 6.2 Moods

One optional mood-flower per day, chosen from the 10 via the mood-picker modal. Setting a mood writes/updates `days.mood_id`. Flowers are hand-drawn inline SVG blooms in the cel-shaded style.

### 6.3 Streak

Derived (§4). Displayed in the desktop nav rail (flame + "N days / longest streak yet"). Day boundary at local midnight; a missed day resets the current streak; longest is preserved.

### 6.4 Reminders

One daily local notification at a user-set time (default 20:30) via `flutter_local_notifications`, on both platforms. **Auto-suppressed** when today already has an entry. Toggle + time live in Settings → Reminders & sound. No push server or developer account required.

### 6.5 Garden + this-week garden

The Garden screen is a decorative animated meadow (blooms sprout per journaled day, sun glow, swaying stems, butterflies + a bee, mood-tally chips). The Today right rail (desktop) shows a 7-day mini-garden of the current week. Animations use the prototype's CSS-keyframe equivalents in Flutter.

### 6.6 Settings

| Section | Fields |
|---|---|
| **Sync & storage** (DISABLED shell) | Storage mode segmented (locked "On this device"); Server URL; Access token; Sync frequency (**Automatic ↔ Manual**); recovery passphrase + device-pairing QR; Test connection; status pill. All inert + a "Syncing arrives in a future update" note. |
| **Reminders & sound** | Daily reminder toggle; Reminder time (default 20:30); Sound effects toggle. |
| **Journal** | Text size slider (1–3); Week starts on (select). |
| **Data** | Export… (secondary); Delete all… (danger). |

The Settings page is also the reusable **field-style catalog** for every control type (segmented, text, secret, select, toggle, time, slider, status-pill + primary, secondary, danger, conditional). The disabled sync section renders at full fidelity so the v2 enablement is a state flip, not a rebuild.

### 6.7 Export / Delete-all

- **Export:** writes all entries + media to a user-chosen location (serves as the v1 backup path, since there is no sync).
- **Delete-all:** destructive, confirmed; clears the local database and media store.

---

## 7. Design system

Baseline is the Field Notes prototype (decisions/2026-07-09-design-baseline.md; full extraction in docs/design/prototype-analysis.md).

- **Fonts:** Newsreader (serif — journal/body/dates), Instrument Sans (UI chrome/labels/buttons), Caveat (handwritten accents — eyebrows, streak, wordmark).
- **Palette (light only):** page `#d9cbb2` (radial `#e6d8bf`→`#cdbd9f`); panel `#efe2ce`→`#e9dcc4` with a coral radial tint; cards `#f8efe0`/`#fff5ea`/`#fffaf1`; ink/outline `#4a3b2e`; primary coral `#c76a54` (hover `#9a4832`); sage `#7d8450`; muted `#a08a70`/`#8a7358`; danger `#c0392b` on `#fbecea`; garden greens + soil + sun-glow per the extraction.
- **Treatment ("sticker cutout"):** every surface carries a `1.5px solid #4a3b2e` outline plus a **hard, non-blurred offset shadow** (`3px 3px 0` cards, `1.5px 1.5px 0` buttons). Dashed `#4a3b2e` borders for dividers/empty-states. Cross-hatch textures for photo/video placeholders. Radii ~11–20px. Hand-drawn SVG flowers with dark strokes. Faux paper grain via radial gradients.
- **Motion:** recording blink, glow pulse, waveform bob, toast/modal/sheet entrances, garden stem sway, butterfly wing-flap + flight, flower grow, fade. Sound effects gated by the Sound toggle.

---

## 8. Error handling

Local-first means storage/media are the dominant failure surfaces. Handle each explicitly with a user-friendly message; never silently swallow.

- **Camera/mic permission denied** → clear prompt + link to system settings; capture aborts cleanly, no partial entry.
- **Disk full / write failure** → surfaced before the entry is marked saved; captured media is not orphaned.
- **Corrupt/unreadable media** → placeholder + non-destructive error in the entry card.
- **Schema migration failure** → drift `MigrationStrategy`; fail safe (do not destroy data), surface a recovery message.
- **Media GC:** mark-and-sweep — reachable set = every `media_id`/thumbnail referenced by a non-deleted row; on-disk blobs not in the set are removed by a periodic local maintenance task. Content-addressing gives free dedup.

---

## 9. Testing strategy

Per the project's test admission gate (assert observable behavior through public surfaces; no change-detector or assertion-weak tests).

- **Unit:** streak keep/reset logic (incl. midnight boundary, gaps, longest); repository CRUD + soft-delete filtering; mood mapping/order; content-addressed media dedup; export contents.
- **Widget:** capture flows (text/voice/video incl. 30-min cap + 5/10/20-min nudge surfacing); mood picker; Day-detail edit/delete; Settings disabled-sync state (controls inert, storage mode locked); reminder toggle/time.
- **Golden (optional):** core design-system widgets and a representative screen per platform.
- Deterministic: no sleeps/real-network/shared-mutable-state.

---

## 10. Build order (v1)

Each phase leaves the app runnable, mapping cleanly onto later MSP decomposition.

| # | Phase | Delivers |
|---|---|---|
| 0 | Foundation | Flutter project named Field Notes (app id, pubspec), light theme + design tokens, sticker-cutout widget kit, three fonts, adaptive shell (sidebar/bottom bar), Riverpod + drift wiring |
| 1 | Data spine | drift schema + migrations (`PRAGMA user_version`), repositories, content-addressed media store, GC task |
| 2 | Capture | Text composer, voice + video recorders (30-min cap, 5/10/20 nudges, thumbnails), photo "add memory", `camera_macos` wiring |
| 3 | Today | Greeting, mood banner + picker, today's entry feed, desktop right rail (this-week garden, capture buttons, "on this day") |
| 4 | Browse | Calendar month grid, Day-detail modal, Search "Your days" list |
| 5 | Garden | Ambient animated meadow + mood tally + this-week mini-garden |
| 6 | Streaks + reminders | Streak service + display, daily local notification (auto-suppress), sound-effects toggle + assets |
| 7 | Settings + data | Full field catalog, disabled sync/server/E2EE shell, text-size, week-start, Export, Delete-all |
| 8 | Polish + verify | Motion, empty states, tests, macOS + Android manual verification, sideload packaging |

---

## 11. v2 preview (deferred, not built here)

v2 turns the disabled settings shell into a working sync layer, per the locked tech-stack and reconciliation decisions:

- Custom lightweight REST sync, per-record **last-writer-wins** (LWW) with `version` + `device_id`; continuous (Automatic) or Manual.
- Client-side **libsodium E2EE**; server stores ciphertext only; thumbnails/search stay on-device.
- Key = **recovery-passphrase-derived** (Argon2); **device 2 pairs via QR**.
- Transport over a **Tailscale** mesh; **Caddy** TLS; server as **Docker Compose** on the user's Arch box.
- First run remains standalone; the nav status becomes dynamic ("On this device only" ↔ "Synced to home").
- **Clock-skew guard:** because the server is self-hosted and controlled, the sync server stamps its own receipt time and resolves LWW by `(server_received_at, device_id)`, sidestepping device-clock skew (avoids the raw wall-clock LWW pitfall). HLC/CRDTs are overkill for single-user, 2-3 devices.

**Open v2 question:** when two independent standalone histories first merge, same-date `days` rows reconcile (mood by LWW; entries union cleanly via distinct ULIDs). The exact merge rule is finalized when v2 is specced.

---

## 12. Open risks

- **camera_macos plugin:** macOS camera relies on the community `camera_macos` plugin (official Flutter camera excludes macOS). Verify capture + thumbnail generation early (Phase 2) before depending on it.
- **Garden animation performance** on low-end Android — budget and profile; degrade gracefully.
- **Video thumbnail generation** on macOS — confirm a working path (plugin or ffmpeg) in Phase 2.
- **App/repo naming:** user-facing name is "Field Notes"; GitHub repo renamed; the local directory `fireplace` is stale (cosmetic).

---

## 13. References (tech-choice validation, cited)

State management + persistence (researcher-validated, 2025-2026):
- Flutter Favorite program — https://docs.flutter.dev/packages-and-plugins/favorites
- Riverpod — https://pub.dev/packages/riverpod ; what's new (v3 offline persistence + retry) — https://riverpod.dev/docs/whats_new
- drift — https://pub.dev/packages/drift ; migrations — https://drift.simonbinder.eu/migrations ; platforms — https://drift.simonbinder.eu/platforms/
- Isar abandonment — https://github.com/isar/isar/issues/1689 ; drift_sqlite_async escalation path — https://github.com/powersync-ja/drift_sqlite_async

Sync-ready schema conventions (researcher-validated):
- Local-first software (Ink & Switch) — https://www.inkandswitch.com/essay/local-first/
- UUIDv7/ULID — RFC 9562 https://www.rfc-editor.org/rfc/rfc9562.html ; ULID spec https://github.com/ulid/spec ; SQLite UUID PK perils https://andersmurphy.com/2026/06/05/the-perils-of-uuid-primary-keys-in-sqlite.html
- Soft-delete tombstones for sync — https://watermelondb.dev/docs/Sync/Backend ; Couchbase tombstones https://docs.couchbase.com/sync-gateway/current/manage/managing-tombstones.html
- Content-addressed blobs — Git objects https://git-scm.com/book/en/v2/Git-Internals-Git-Objects
- LWW clock-skew — https://oneuptime.com/blog/post/2026-01-30-last-write-wins/view
