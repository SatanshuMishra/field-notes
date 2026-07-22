Status: accepted
Date: 2026-07-21
Thread: journal-app-design

## Context
Local macOS build: note + voice hung forever under "Saving…" (never persisted); video failed
before any permission prompt. 660 unit tests passed by mocking the DB + media providers.

## Decision
Note/voice: a platform `Exception` in the Riverpod capture chain held indefinitely by Riverpod
3.3.2 auto-retry (provider_container.dart:948 — only Error/ProviderException short-circuit),
with no timeout/finally on the modal. Fix = `retry:(_,_)=>null` on root ProviderScope + bounded
`.timeout`/`finally`/surfaced-error in both composers. Video: a `start()`/`_ready` deadlock
(fixed: mount preview before awaiting readiness + 12s backstop); "no prompt" is an
ad-hoc-signing/TCC env limit (no paid Apple account), now shown as guidance not silent fail.

## Consequences
- Trigger (b) drift `createInBackground` EXCLUDED; a clean rebuild self-heals plugin wiring, so
  the code fix (not the trigger) is the durable guarantee. App-wide retry-off is safe (all
  providers local). Rejected `permission_handler`. Review MEDIUMs + real-UI app test still owed.
