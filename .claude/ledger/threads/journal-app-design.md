---
thread: journal-app-design
status: paused
updated: 2026-07-22
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: On the running app, exercise a real voice Save and read the `flutter run` console — confirm it now bounds-with-error instead of hanging, and determine whether the native recorder.stop() ever returns. If it never returns, root-cause the real macOS voice recorder. Then push branch fix/capture-save-hang + open a PR. Always run via `flutter run -d macos` (never the standalone binary).
branch: fix/capture-save-hang
---

## Status
App is code-complete and runs on macOS via `flutter run`. DB round-trip PROVEN end-to-end this
session. A real-mic voice save hung on "Saving..."; root cause found (the PR #32 save timeout was a
no-op) and fixed across voice/text/video on branch fix/capture-save-hang (0a9902c, unpushed).

## Active Goal
Bug-fix / debugging: make real capture (voice first) actually save on the running macOS app, and
land the save-hang fix (push + PR).

## Next Step
Exercise a real voice Save on the running app; read the `flutter run` console to see if it now
error-bounds and whether native stop() ever returns. If it hangs, debug the real voice recorder.
Then push fix/capture-save-hang + open the PR.

## Open Risks
- Real-mic voice may still not PERSIST — the fix only converts an infinite hang into a bounded
  error; a never-returning native recorder.stop() (ad-hoc signing / mic TCC) is not yet resolved.
- Branch fix/capture-save-hang is unpushed; no PR yet.
- PR #32 decision doc still asserts a "bounded timeout" (its file text stands; corrected by the new decision).

## Key Decisions
- decisions/2026-07-22-save-hang-timeout-noop-root-cause.md — real save-hang cause + fix (voice/text/video)
- decisions/2026-07-22-black-window-standalone-binary.md — black window = binary launch; use `flutter run`
- decisions/2026-07-21-capture-flow-root-cause-and-fix.md — PR #32 capture fixes (timeout claim corrected)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user;
  pooled Memories gallery. All sync/server work is v2. Reminders day-2 pre-arm is post-31.

## Pointers
- lib/features/capture/{voice,text,video}/*_composer.dart — the save-hang fix (bounded timeout fail-back)
- lib/features/capture/voice/record_voice_recorder.dart — real macOS recorder (stop() = the suspect)
- lib/data/database/connection.dart — on-disk DB path (getApplicationDocumentsDirectory/field_notes.sqlite)
- integration_test/capture_save_persist_test.dart — real on-disk store receipt (-d macos)
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-22-01-journal-app-design.md — DB round-trip proven; black-window + voice save-hang root-caused & fixed
- sessions/2026-07-21-07-journal-app-design.md — 4 touch-ups + real-UI app test (3/3 macOS); PR #32 merged
- sessions/2026-07-21-06-journal-app-design.md — capture flows debugged + fixed; complete app test owed
- sessions/2026-07-21-05-journal-app-design.md — first macOS build+run; home screen visually confirmed
