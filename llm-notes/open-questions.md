# Open questions

## For the Roc community
- Is running several app instances in one process (each `roc_main` on its own thread, never
  concurrently) supported, or does it just happen to work?
- Can `roc_crashed` stop only the crashing instance?
- Could effect-stack switching (as in the roc-signals wasm host) replace thread-per-node on native?
- Why S-expressions for the roc-signals/roc-gui specs? (Luke)
- Does a *package* accept effectful functions as arguments the same way a local module does
  (verified for local modules)?

## Design
- Exact fault model: delay, loss, partitions, partial reads, resets; clock skew optional?
- Trace format details (JSON lines; which fields).
- Do the KV clients run as extra sim nodes (workload app) or inside the host?
- Memory budget per node: how big, and how to measure Roc's baseline.
- Add a select-like function to basic-cli (e.g. `Tcp.wait_any!(listener, streams, timeout)`)?
  It would allow request/response instead of one-way messages. Conditions: generic (not
  DST-specific), offered upstream, minimal. Leaning: start without it, add only if one-way
  messages turn out painful.
- Can sim and real host share code (error mapping, line reading) instead of copying it?
  Matters because the semantics must match (Richard, Zulip).

## Thesis
- Deadline: four months after registration (about mid-March 2027), settled 2026-10-27.
- Confirm the "unchanged" definition and the basic-cli-dst direction with the professor.
