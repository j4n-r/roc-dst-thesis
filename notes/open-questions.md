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

## Research question (draft, 2026-10-25: on the slides, not yet in the exposé)

Backups (hidden backup slide): "How can basic-cli be turned into a simulating platform for
distributed systems, and what are the limits?" and "Does Roc's enforced effect boundary keep
deterministic simulation intact across all of an application's dependencies, and where does that
guarantee end?"

> Can a distributed system written in Roc without DST-specific coding practices be tested
> deterministically by replacing its platform with a simulating one that implements the same
> interface for networking, time and randomness, and where are the limits?

1. Which coding practices do existing DST approaches require of the application? Checklist from
   FoundationDB, TigerBeetle, madsim/turmoil (maybe Coyote); document why these sources.
2. Does an app that follows none of them run unchanged and deterministically in the sim?
3. Limits: effects outside the subset, host code, fidelity of the simulated TCP.

Every architecture decision in the app must be justified without DST (transport parameter: users
choose the protocol; one-way messages: basic-cli has no select).

## Thesis
- Deadline.
- Confirm the "unchanged" definition and the basic-cli-dst direction with the professor.
