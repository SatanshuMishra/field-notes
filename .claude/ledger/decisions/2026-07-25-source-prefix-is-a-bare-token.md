Status: accepted
Date: 2026-07-25
Thread: video-card-playback-controls

## Context
The session-04 handoff said to dispatch with `sourcePrefix: msp/`, echoing the human-readable form in
2026-07-25-msp-branch-prefix-not-per-type.md. That literal value fails the engine's input gate: the run died
in 12ms at stage `input` — zero agents spawned, nothing created.

## Decision
Pass `sourcePrefix: "msp"` — the BARE token, no trailing slash. The engine owns the separator.

## Consequences
`mitosis.js:422`/`:4131` compose the branch as `${sourcePrefix}/${msp.id}-integration`, and `branchToMspId`
(`:317-319`) rebuilds that same prefix to map a merged PR back to its MSP — a trailing slash yields
`msp//MSP-1-integration` and breaks reconciliation both ways. It never gets that far: `REF_TOKEN_PATTERN`
(`:2550`) requires every `/`-separated segment to start alphanumeric, so the empty final segment halts the
run. The composite is re-validated as ONE token at `:4139`, so MSP ids must stay conservative too. The prior
record stands; this fixes only the wire format. REJECTED: relaxing the pattern (it guards tokens
interpolated into git/gh command strings); putting the slash in the spec (only the handoff prose carried it).
