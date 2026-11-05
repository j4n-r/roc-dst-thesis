# Evaluation criteria (v0, 2026-11-05)

Drawn from two sources so far: Wilson's Strange Loop talk on FoundationDB's simulation (2014,
Zotero LPH6QMDT) and Luo et al., "An Empirical Analysis of Flaky Tests" (FSE 2014,
`luoEmpiricalAnalysisFlaky2014`). v1 adds the FoundationDB paper (Zhou 2021) and TigerBeetle
(VOPR docs, Kladov's talk).

What the criteria are for:

- **A. Sources of nondeterminism:** sub-question 2, which sources the platform boundary
  controls and where they can still leak.
- **B. Practices required of the app:** check 1 of the "unchanged" claim
  ([design.md](design.md), Build order). The Roc app must need none of them. Also the yardstick
  for sub-question 3, the restrictions on the app and its dependencies.
- **C. What the simulator must provide:** not about the app, but the evaluation needs it to say
  whether the sim is good enough for the other results to mean anything.

## A. Sources of nondeterminism

Luo et al. classify the root causes of 201 flaky-test fixes. The top three are Async Wait,
Concurrency and Test Order Dependency (p. 2); the rest are Resource Leak, Network, Time, IO,
Randomness, Floating Point and Unordered Collections (pp. 5–6). Wilson names the network as the
source of entropy you don't control and says the same applies to threads and disks.

| # | Source | Luo et al. | Wilson / FoundationDB | Question for Roc |
|---|---|---|---|---|
| A1 | **Network:** delay, loss, reorder, connection failures | Network: 60% remote connection failures, the rest local socket management (p. 5). Fix: mocks, or `waitFor` (p. 9) | The uncontrolled entropy source. Simulated network: latency on both sides, and on every read a chance the peer closes, you close, or the read just fails | Does every network effect go through basic-cli's `Tcp`? What about DNS, and the HTTP client that bypasses `Tcp`? |
| A2 | **Time:** wall clock, timeouts, precision | Time: midnight in UTC, precision differs between platforms (p. 5). Fix: avoid platform values like time (p. 9) | "Checked the time in an if statement? Your program just became non-deterministic." Time comes from the sim and can be sped up | `Utc.now!`, `Monotonic.now!` and `Sleep` are platform effects. Is there any other way to observe time (e.g. timing of allocation, compile-time evaluation)? |
| A3 | **Randomness** | Randomness: unaccounted values (p. 6). Fix: control the seed so a run reproduces, vary it across runs, test boundary values like zero (p. 9) | Every random number comes from a PRNG you seeded, and the seed is part of the program's input | `Random` seeds are platform effects. Any hidden randomness inside Roc? Richard: `Dict` storage is seeded from memory addresses but not observable |
| A4 | **Scheduling / concurrency:** thread interleaving, data races, deadlocks | Concurrency: 97% need no external resources, only memory (p. 7); reproducible with at most two threads (p. 7). 25% fixed by making execution deterministic (p. 8) | Needs something like concurrency but can't be concurrent: one process, one thread. FoundationDB's answer is Flow (actors, single-threaded callbacks) | Roc has no threads in the language. Concurrency only exists in the host: the sim scheduler (baton) and, on real basic-cli, tokio |
| A5 | **Ordering between components** (async wait) | Async Wait: test assumes another thread/process finished; 34% enforce order with `sleep` (p. 2), which breaks on slower machines (p. 8). Fix: wait for an explicit condition (p. 8) | Covered by A1 and A4: in the sim, message order is a seeded choice | Same as A4. Note: this is the app's ordering assumptions, which DST is meant to explore, not remove |
| A6 | **Disk and other I/O** | IO: close opened resources, synchronise access (p. 9) | Disk faults; "checked how much disk space is free" is nondeterministic | File system is outside the subset, so the compiler rejects it. Leaks only through the host |
| A7 | **Iteration order of unordered collections** | Unordered Collections: code assumes an order the API doesn't guarantee (p. 6) | (not covered) | Richard: `Dict` iterates in insertion order. To verify, e.g. with `Set` too |
| A8 | **Floating point** | Floating Point: non-associative addition, platform differences (p. 6) | (not covered) | Richard: floats behave the same across CPUs, and there is no `usize`. To verify for the targets used |
| A9 | **Resources and their limits:** leaks, exhaustion, OOM | Resource Leak: leaky clients found by shrinking the pool (p. 9) | Free disk space; machines failing gradually | Richard: only resource crashes (OOM, stack overflow) can differ between targets. Sim: per-node memory budget and leak check ([design.md](design.md)) |
| A10 | **State carried between runs** | Test Order Dependency: shared state not set up or cleaned (p. 5), 47% via external resources (p. 2), 74% fixed by cleaning state (p. 2) | Each simulation run starts from the seed | One process per seed. In-process: global state in the host shared between nodes or runs? |
| A11 | **Platform and system calls** | 96% of flaky tests don't depend on the platform (p. 6) | The only untested production code is the part that really talks to disk and network | The host is outside the boundary: anything it does that the sim doesn't model (A1–A9) is a leak. Compiler and dependencies too (sub-question 2) |

Notes from reading Luo et al.:

- **A10 is not DST ordering.** Test order dependency is about state left behind by other tests.
  DST explores the order of events within one run. Only the "fresh state per run" part carries
  over.
- **Cleaning state can hide bugs.** In distributed systems, many failures need a particular
  state to start from, so resetting state for each test may skip exactly those bugs. Argument
  for long simulated runs with crashes and restarts instead of many short clean ones.
- **A test that accepts only some valid behaviours is flaky** (p. 5); the fix is to accept all
  valid behaviours (p. 8). For DST this is the checker's job: linearizability accepts every
  valid history, not one expected output.
- **Most flaky tests are not about the platform** (p. 6). Luo et al. are looking at unit tests
  that rarely make system calls, so this doesn't carry over directly to a distributed system,
  where A1 and A2 dominate.

## B. Practices required of the app

What FoundationDB's approach requires of the application (Wilson), plus the fixes Luo et al.
recommend, which are the same practices by hand. The Roc app should need none of them; where it
needs one anyway, that's a restriction for sub-question 3.

| # | Practice | Source | Question for Roc |
|---|---|---|---|
| B1 | **Single-threaded concurrency model chosen for the sim:** FoundationDB wrote Flow, a C++ extension for actors in single-threaded callbacks, because threads and coroutines didn't work | Wilson | The app uses blocking basic-cli calls. The host hides the scheduling (baton) |
| B2 | **All contact with the outside world goes through an interface with a simulated implementation** | Wilson: "a simulated implementation of all the ways in which your processes can talk to the rest of the Universe"; Luo: mock the network (p. 9) | The platform *is* that interface, enforced by the language rather than by convention |
| B3 | **Seeded randomness, seed passed in as input** | Wilson; Luo (p. 9) | Seeds come from `Random`; the app doesn't need to thread a seed through |
| B4 | **Don't read time, disk space etc. directly** | Wilson: "programmers are trained to recognize this stuff and to try and avoid it, and we still screw it up all the time" | No direct reads exist: anything not in the platform API fails to compile |
| B5 | **Avoid or replace dependencies that aren't written for the sim** | Wilson: software not written in Flow can't be tested in simulation; FoundationDB ripped out a dependency and wrote its own | A third-party Roc package runs in the sim unchanged, unless it declares the platform (then it needs a `--replace-dep` flag, see design.md) |
| B6 | **Instrument the code to widen the behaviours exercised** (buggify: e.g. send packets out of order, suppress a timeout, within the interface's contract) | Wilson | Not required. Could the sim host do part of it from outside (reorder, delay), without touching the app? |
| B7 | **Replace `sleep`-based ordering with explicit conditions** | Luo (p. 8) | Not a DST requirement but good practice. In the sim, a `sleep`-based ordering bug shows up under some seed |

Wilson's "we still screw it up all the time" is the central motivation: in FoundationDB,
determinism (B2–B4) depends on discipline. In Roc, the compiler enforces it.

## C. What the simulator must provide

| # | Property | Source |
|---|---|---|
| C1 | **One process, one thread of execution at a time** | Wilson |
| C2 | **All entropy comes from one seed,** including fault decisions | Wilson; Luo (p. 9) |
| C3 | **Determinism self-check:** run the same seed twice and compare. FoundationDB does this for ~1% of runs and compares the next random number | Wilson |
| C4 | **Faults more often than in reality:** drops, closes, crashes, partitions; in FoundationDB disks fail every few minutes, not years | Wilson |
| C5 | **Correlated, cascading failures,** not independent random events | Wilson |
| C6 | **Virtual time that skips idle periods** | Wilson |
| C7 | **Workloads with invariants checked at the end** (FoundationDB's cycle test: a ring of keys that every transaction preserves) | Wilson |
| C8 | **Fidelity:** the sim can be wrong by not being brutal enough, or by misunderstanding the platform's contracts. FoundationDB checked against real hardware (power-cycling machines) and found nothing | Wilson. Here: the differential test ([design.md](design.md)) |
| C9 | **The sim must catch bugs:** inject bugs on purpose and see if they're found | Wilson. Here: the canary Raft bug |

## Open for v1

- Add FoundationDB (Zhou 2021) and TigerBeetle: per-practice evidence of what they required,
  and anything missing from A (e.g. memory addresses, hash seeds, thread-local state).
- Decide how to grade each criterion for Roc: controlled by the boundary / leaks via host /
  leaks via compiler / leaks via dependencies / not applicable.
- Wilson's drawbacks: debugging callback-heavy code in a simulation is hard, and long
  simulation runs slow down the edit cycle. Do these apply to the Roc approach?
