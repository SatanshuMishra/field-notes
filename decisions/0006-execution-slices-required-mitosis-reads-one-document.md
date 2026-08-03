---
Status: accepted
Date: 2026-08-03T19:44:13.985Z
Thread-Id: 01KZ33PK4E5RN3G6MD458S2N5D
---

# 0006. Mitosis reads exactly one document, so execution slices must be cut; the combined spec stays the authority

## Context

The combined spec deliberately AMENDS the 1228-line sibling by resolution number (A1-A12, D1-D8) rather than restating it -- section 0 argues copying it would create two authorities and guarantee drift. Sound as a documentation argument. The convergence pass proved it incompatible with execution: mitosis's decompose prompt is literally "Read the approved spec/batch document at: ${spec}" (mitosis.js:4172), the per-MSP plan seed names the same single path, and run identity is content-keyed on shasum of that ONE file (:3965). An edit to the sibling changes nothing the engine can detect.

## Options

- Cut execution slices per existing precedent; combined spec stays the authority (CHOSEN)
- Inline all 1228 sibling lines into the combined spec
- Rely on the decomposer following the prose cross-reference

## Outcome

CUT EXECUTION SLICES. This is not a new decision -- it APPLIES 2026-07-27-cluster-a-scoped-spec.md, which already states it generalises to every cluster: a slice is a document containing the target MSPs VERBATIM, plus every constraint and verification rule binding them, plus a hard scope fence, committed to base before dispatch. The slice for this ladder must inline P0-P5 with the A/D amendments ALREADY APPLIED, not referenced. Rejected relying on the decomposer to follow the cross-reference: it would have to apply twenty diffs across a document boundary, several of which DELETE sibling content (A4 deletes a file from the fence, A7 voids section 5.3 totals, A11 voids R20's receipt and two 5.6 rows); nothing in the run contract compels it and nothing verifies it. Rejected inlining 1228 lines into the combined spec: that recreates the two-authorities problem section 0 rejects, and the slice mechanism already exists to solve it. CONSEQUENCE: the combined spec is the standing AUTHORITY and citation source (the role the parent prototype-alignment spec plays for Clusters A-F); slices are cut FROM it per wave. Also forced by sourcePrefix being a SCALAR -- editor/ and inline-photo/ cannot both be per-run prefixes in one run.
