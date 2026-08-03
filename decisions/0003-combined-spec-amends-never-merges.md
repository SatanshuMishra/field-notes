---
Status: accepted
Date: 2026-08-03T06:37:23.093Z
Thread-Id: 01KZ33PK4E5RN3G6MD458S2N5D
---

# 0003. The combined spec amends the 1228-line sibling by resolution number, never absorbs it

## Context

The user directed ONE spec covering the rich markdown editor and OQ-6, editor first. A 1228-line P0-P5 spec already existed carrying 28 primitive resolutions and twelve derived hull points -- a full session of work. The literal reading of "one spec" is to merge both documents into a single file.

## Options

- Merge both documents into one file, copying the 1228 lines forward
- Write a new spec that AMENDS the sibling by resolution number (CHOSEN)
- Leave two independent specs with no stated relationship

## Outcome

AMEND, never absorb. docs/specs/2026-08-03-rich-editor-and-inline-photos.md is the entry point and section 5 amends the sibling as A1-A12, each naming a resolution R0-R28; every resolution not named stands unchanged. Copying 1228 lines forward creates TWO AUTHORITIES for one subsystem and guarantees the drift this spec family has already suffered five times -- and the copied text would be no more verified than the original, which was never critic-hardened. The amendment list is also auditable in a way a merged rewrite is not: a reviewer can check twelve deltas but not a 1700-line rewrite. Consequence: an implementer MUST read both documents, and the new spec says so in its first section. Also consequential: the sibling's absolute test totals are void (A7) while its per-phase deltas stand.
