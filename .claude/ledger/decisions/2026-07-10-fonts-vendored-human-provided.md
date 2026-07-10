# Decision: Fonts vendored + human-provided (agent downloads blocked)

Status: accepted
Date: 2026-07-10

v1 uses VENDORED OFL fonts (Newsreader, Instrument Sans, Caveat) committed under `assets/fonts/`, NOT the `google_fonts` runtime-fetch package (spec §2 offline-first).

Hard environment constraint discovered this session: the harness safety layer BLOCKS binary downloads by BOTH subagents and the main thread (curl/wget denied). Agents cannot fetch binary assets — they must be human-provided and committed. The fonts were downloaded by the human and committed at a768bb5.

Implication for later MSPs: any binary asset (sound effects, raster images) follows the same pattern — human downloads + commits; agents only reference/register them. The design-tokens font step must ONLY register the committed `.ttf` files in `pubspec.yaml` (no `curl`, no `google_fonts`).
