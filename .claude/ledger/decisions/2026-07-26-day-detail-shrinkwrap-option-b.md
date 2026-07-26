# 2026-07-26 — Day-detail virtualization ships Option B: shrinkWrap shrink-to-fit

Status: accepted

MSP 3's blocking Step 0 ruling, granted by the spec owner pre-dispatch (verbatim choice:
"Option B: shrink-to-fit"). The replacement `ListView.separated` carries `shrinkWrap: true`,
preserving the modal's shrink-to-fit sizing (a one-entry day stays a small card). Verified
against the Flutter source before the ruling was requested: in this bounded position
(`Flexible` under `ConstrainedBox(maxHeight: 520)`) a shrink-wrapping viewport still
virtualizes — `RenderShrinkWrappingViewport` builds everything only on its
infinite-main-axis branch (`viewport.dart:2153-2158`) — and has NO scroll-time height
wobble: `constraints.constrainHeight(_shrinkWrapExtent)` (`:2116-2119`) clamps both
content-size cases to a stable height. The prior plan draft's wobble claim was false and
biased the brief toward Option A, which carried the measured visual regression
(480x105 -> 480x244 for a one-entry day). The spec's blanket shrinkWrap rejection
(spec `:123`, `:157`) is SCOPED by amendment to unbounded positions — it remains in
force for the Phase 3 Today feed. Ruling obtained pre-dispatch precisely because a
mitosis worker cannot reach a human mid-run (the MSP 2 park lesson).
