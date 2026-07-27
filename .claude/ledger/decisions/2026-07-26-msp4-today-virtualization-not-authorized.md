Status: accepted
Date: 2026-07-26
Thread: video-card-playback-controls

## Context
The spec plans four MSPs; three shipped (#41, #44, #47), MSP 4 / Phase 3 (Today-feed virtualization) did
not. It was written while the decoder-exhaustion theory was live: feeds are non-lazy Columns, so eager
per-card decoder init exhausts the device pool and renders the red placeholder.

## Decision
MSP 4 is NOT authorized and the thread closes without it. Phase 3 stays conditional on both spec gates
(`:128-131`): a post-Phase-1 hardware profile, then spec-owner review. Never execute on prediction.

## Consequences
- Phase 1 (poster-first) was the root fix and retired the motivation: at-rest decoders 6 -> 0.
- `cacheExtent` keeps ~3-4 cards alive anyway (spec `:135`), so virtualization never made "only visible cards decode" true — it is scroll optimization on top of the real fix, never a substitute for it.
- Option B does NOT transfer: the Today feed has no bounded ancestor (`today_screen.dart:39`/`:44`, verified at main), so `shrinkWrap` cannot virtualize there and Phase 3 needs a real sliver rewrite of TWO structurally different trees.
- Pagination may beat virtualization and stays unpicked: no `.limit(` anywhere in `entries_dao.dart` (main).
- Precondition 1 became takeable only once Phase 1 shipped and was hardware-confirmed; nobody took it.
- MSP 4 was never one of the thread's nine criteria, so it never blocked closure.
