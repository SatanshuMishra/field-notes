Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
The mitosis ship stage prescribes a CI wait of the form `timeout 1800 gh run watch ...`. macOS ships no `timeout` binary and no `gtimeout` here, so the command exits 127 immediately with an empty conclusion. Three ship-stage agents have now hit it: a3 in session 05, a2 and a5 in session 06. All three detected it from the exit code and re-ran an iteration-bounded poll to reach the real terminal conclusion.

## Decision
Ship-stage (and any agent-authored) CI waits on this project use an iteration-bounded `until` loop with an explicit cap, never `timeout`. An agent that runs a wait MUST check the exit code before treating the wait as completed, and MUST NOT read a CI conclusion obtained from a 127.

## Consequences
- A 127 that goes unchecked reads as a completed wait over a still-running job, so the agent reports a non-terminal conclusion as terminal — a wrong-answer path, not merely a slow one.
- Detection is cheap and load-bearing: the exit code is the only signal, since the empty conclusion is indistinguishable from a genuinely empty result.
- Applies to every darwin host in this project; it is an environment fact, not a task-specific workaround.
