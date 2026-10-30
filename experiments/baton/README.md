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
- `platform/`: those effects as hosted functions (`hosted_send`, ...), the same
  shape basic-cli uses.
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

## Not tested

- Whether the same app runs unchanged on a *real* network platform (only the
  sim host exists here).
- Running Roc code on several threads truly in parallel. The baton makes that
  unnecessary for DST.
- Panics/`crash` inside a node: `roc_crashed` exits the whole process.
