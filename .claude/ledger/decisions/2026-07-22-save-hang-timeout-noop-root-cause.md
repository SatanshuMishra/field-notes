Status: accepted
Date: 2026-07-22
Thread: journal-app-design

## Context
Real macOS voice save hung forever on "Saving...". PR #32 (decisions/2026-07-21-capture-flow-root-cause-and-fix.md)
claimed a "bounded save timeout", but every proving test used FAKED recorders whose stop() returns instantly.

## Decision
Root cause: the save `.timeout()` was a NO-OP — on TimeoutException the handler re-awaited the SAME
still-running `_persist()` future unbounded, so a never-completing native `RecordVoiceRecorder.stop()`
(MethodChannel that never replies) hung indefinitely. Fix (branch fix/capture-save-hang, 0a9902c):
drop the re-await; on timeout surface a bounded message + clear saving state, detach the stray future
via `unawaited()`. Applied to voice/text/video (identical defect) with save-hang receipts (RED->GREEN).

## Consequences
- CORRECTS the "bounded timeout" claim in 2026-07-21-capture-flow-root-cause-and-fix.md; that record's
  other content (video deadlock, TCC) stands.
- Stops the HANG only, NOT a never-returning stop(). Whether real voice actually persists is OPEN;
  if stop() never returns, the real macOS voice recorder is the next bug. Branch unpushed; no PR.
