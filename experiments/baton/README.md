# baton

Can an ordinary, **blocking** Roc program (basic-cli style: `main!` loops and
blocks in `recv!` / `sleep!`) run as several nodes inside one deterministic
simulator, without changing the app?

This tests the two prerequisites for a "DST mode" fork of basic-cli:

1. Several instances of one Roc app in one process, each on its own thread.
2. Baton scheduling: only one thread runs at a time, every hosted call is a
   yield point, and the interleaving comes only from a seed.

## Layout

- `app/main.roc`: token ring with timeouts, 3 nodes. Uses `Net.send!`,
  `Net.recv!` (with timeout), `Clock.now!`, `Clock.sleep!`, `Stdout.line!`.
  Knows nothing about simulation.
- `app/spawn.roc`: the same ring with two fibers per node (see `spawn!` below).
- `platform/`: those effects as hosted functions (`hosted_send`, ...), the same
  shape basic-cli uses, plus `Fiber.spawn!`.
- `src/lib.rs`: the simulating host. One OS thread per node keeps that node's
  stack alive while it's paused inside a hosted call. The scheduler (main thread)
  passes the baton to one node at a time over channels, keeps a virtual clock
  and an event queue, and draws message delays (1-30ms), drops (1 in 10), and
  which ready node runs next from a seeded xoshiro256++.

## Run

```sh
nix develop -c ./build.sh      # Rust host -> platform/targets/x64musl/libhost.a
roc build app/main.roc         # -> ./main
./main 1 --trace               # one run, full trace
./check.sh 200                 # determinism check
roc build app/spawn.roc        # -> ./spawn (two fibers per node)
./check.sh 200 ./spawn
```

## Results (2026-10-23, roc nightly-2026-10-20-7a8a800)

- **1. Several instances: works.** Three `roc_main` calls on three threads in one
  process, sharing one allocator, ran without crashes or interference. Each node
  keeps its own state (its own `seen` count).
- **2. Baton determinism: works.**
  - Seed 1 run twice: byte-identical full traces.
  - Seeds 1-200, each run twice: 0 hash mismatches, 200 distinct traces.
  - Seeds 1-100 run sequentially vs 32 runs in parallel on 16 cores (noisy OS
    scheduling): identical hashes.
- **Long runs: constant stack.** With the node stack cut to 256 KB and the stop
  time raised to 10,000,000 virtual ms, each node made ~225k iterations of its
  recursive `run!` loop without overflowing.
- **Cost:** that long run took 58.5s wall (10.5s user, 19.1s sys) for 1.42M
  trace lines (748k sends). Most of it is OS thread handoffs. Stackful
  coroutines would avoid those if speed matters.

## `spawn!`: two fibers per node (2026-11-11, roc nightly-2026-11-06-34f137a)

Question: can the host give a node concurrency of its own, Go style, with no
async/await in Roc and no event loop in the app?

- **API:** `Fiber.spawn! : (() => {}) => {}`. The platform boxes the function and
  passes it to `hosted_spawn`; Roc's glue gives the host the box as an opaque
  `RocErasedCallable`. The host starts a fiber thread that hands the box back
  through a second platform entry point, `roc_run_fiber`, which unboxes and
  calls it. Fibers are now the scheduler's unit: one OS thread and one baton
  holder each. A node's messages go to whichever of its fibers has waited longest
  in `recv!`, and the node finishes when its last fiber returns.
- **App:** `app/spawn.roc` is `main.roc`'s relay loop plus a heartbeat fiber per
  node that sleeps 150ms and pings the next node. The relay code is unchanged
  apart from logging pings instead of forwarding them.
- **Results:**
  - Works: 3 nodes × 2 fibers. Seed 1 run twice gives identical traces; seeds
    1-200 each run twice: 0 mismatches, 200 distinct traces.
  - The heartbeat keeps its schedule while its node's relay is blocked in
    `recv!`: in all 200 seeds every ping k is sent at exactly 150·k ms.
  - Ownership: each fiber's box is freed exactly once, after it is handed
    back to Roc (checked with a temporary allocation tracker, since removed).
  - No regression: `main.roc` on the fiber scheduler gives the same 200 trace
    hashes as the old per-node host.
- **Toolchain:** the glue pin moved to the compiler's commit (34f137a). For the
  platform without `spawn!`, the regenerated glue was byte-identical.
- **Open:** fibers can't talk to each other yet (no channels or shared state),
  so a heartbeat can't learn that the relay just heard from the leader. That
  needs a host-side channel or `wait_any!`. Each fiber is still an OS thread.

## Not tested

- Whether the same app runs unchanged on a *real* network platform (only the
  sim host exists here).
- Running Roc code on several threads truly in parallel. The baton makes that
  unnecessary for DST.
- Panics/`crash` inside a node: `roc_crashed` exits the whole process.
