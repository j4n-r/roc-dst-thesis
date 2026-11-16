# Open questions

Last reviewed 2026-11-16.

## For the Roc community
- Is running several app instances in one process (each `roc_main` on its own thread, never
  concurrently) supported, or does it just happen to work? Baton shows it works in practice:
  3 instances, one shared allocator, no interference ([findings.md](findings.md), baton).
- Does a *package* accept effectful functions as arguments the same way a local module does?
  Verified only for a local module (2026-10-25, [design.md](design.md)); check with the KV
  app's third-party package.

## Design
- **Contract list:** for each hosted function in the subset, the results, errors, timing and side
  effects it can have, taken from basic-cli's docs and host source. This is the sim's spec. The
  type gives the set of possible tags; the contract says which ones occur when, plus what the type
  doesn't show (short reads, delays, partial writes). An error such as `ConnectionReset` must allow
  both "delivered" and "not delivered".
- **Fault model:** delay, loss, partitions, partial reads, resets; clock skew optional? Inputs so
  far: a crashed node keeps every write the OS accepted, since basic-cli never fsyncs; power loss
  is out of scope ([findings.md](findings.md), disk writes). Out of memory exits the process, so
  it is one more cause of a crash.
- **Disk in the subset?** Raft must persist the term, the vote and the log, so `File` or `Path`
  is probably in. Then the sim needs a file system per node and a rule for what survives a crash.
- **DNS:** do nodes connect by IP address, or does the sim have to model name resolution in
  `Tcp.connect!`?
- **Trace format:** JSON lines of every effect and stdout line ([design.md](design.md),
  Checking). Which fields is still open.
- Do the KV clients run as extra sim nodes (workload app) or inside the host?
- **Memory budget per node:** how big, and how to measure Roc's baseline. Exceeding it counts as
  a crash.
- Can sim and real host share code (error mapping, line reading) instead of copying it?
  Matters because the semantics must match (Richard, Zulip).

## Thesis
- **Grading scale for sub-question 2:** for each source of nondeterminism, e.g. controlled by the
  boundary / assumption / not relevant to the case study. The grade is argued from the boundary
  and backed by same-seed runs, which show determinism but can't prove it.
- **Formal requirements and AI use:** asked Prof. Eck and Prof. Schaal in the exposé email of
  early November (own formal requirements, or the template document? what must be marked as
  AI-assisted?). No answer recorded yet.

## Settled
- **Select-like function in basic-cli (`Tcp.wait_any!`):** no. New primitives in basic-cli-dst
  would break deletions-only, so the app couldn't build against upstream basic-cli
  ([design.md](design.md), Concurrency, 2026-11-11). The app uses one-way messages and
  `accept!` with a timeout instead.
- **`roc_crashed` stopping only one instance:** not needed. One process per seed, and
  `roc_crashed` records node, message and seed, then exits ([design.md](design.md), Sim host).
- **Effect-stack switching instead of thread per node:** Roc's own plan is host-owned stackful
  coroutines for 0.2.0 ([findings.md](findings.md), Roc's concurrency plan). Outlook, not this
  thesis.
- **"Unchanged" definition with the professor:** settled by Prof. Eck's feedback (2026-11-11/13):
  sub-question 1 measures how much code runs unchanged.
- **Deadline:** four months after registration (settled 2026-10-27).
