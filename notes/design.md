# Design decisions

State as of 2026-10-24. The reasons come from discussion and the experiments in
[findings.md](findings.md).

## Platform vs host

- **Platform:** the Roc side (`platform/*.roc`), i.e. the modules apps import, their types, and the
  `hosted` list of C symbols the host must provide.
- **Host:** native code (`libhost.a`) that exports those symbols, plus `main` and `roc_alloc`.
- `roc build` links whatever `libhost.a` sits in `platform/targets/<target>/`. Switching hosts
  means copying a different `libhost.a` there before building. The app and the `.roc` files stay
  the same.

## Shape

| | Platform `.roc` | Host |
|---|---|---|
| Real | upstream basic-cli, unmodified | upstream basic-cli |
| Sim | **basic-cli-dst**: copy of basic-cli with unsupported modules and functions *deleted* | own Rust crate |

- **Deletions only:** remaining functions keep exact signatures, error tags and hosted symbol
  names. `diff -r` against upstream must show deletions only (checked by a script).
- **Payoff:** "compiles against basic-cli-dst" means "runs in the sim". Anything unsupported is a
  compile error, not a runtime crash stub.
- **Not a mode inside basic-cli** (for the thesis): that would expose all 94 hosted functions,
  tie the work to basic-cli's releases, and lose the compile-time check. Upstreaming is future work.
- **Not a message-level `send!` API:** simulating at `Tcp.*` keeps apps on the standard API. The
  cost is that the platform can't choose the protocol, and that it's more work (about 10 TCP
  functions instead of 2). The message-level platform is the fallback.
- **The app's header uses a local platform path,** not a release URL, because release bundles
  ship a prebuilt host that can't be swapped. Pin one basic-cli revision for platform, real host
  and glue.

## Subset

TCP (listen, accept, connect, read_*, write; close happens on last release), sleep, Utc and
Monotonic time, stdout/stderr, args/env, random seed. Out: filesystem, HTTP (client-only in
basic-cli and goes through hyper rather than `Tcp`), Cmd, Sqlite, Tty, …

## Sim host

- **One OS thread per node,** used only to keep a node's stack alive while it's paused inside a
  hosted call (Roc has no coroutines).
- **Baton:** every hosted call sends a request to the scheduler and blocks. The scheduler resumes
  exactly one node, so execution is never parallel.
- **Virtual time:** an event queue of (time, seq). When no node can run, time jumps to the next
  event.
- **Seeded choices:** our own PRNG (xoshiro256++) picks which ready node runs, delays, losses and
  partitions.
- **Per node:** args (`--id`, ports, peers) and captured stdout.
- **Memory:** `roc_alloc`/`roc_dealloc` count live bytes per node (via the thread-local node id),
  and the seed fails if a node exceeds its budget. There's also a leak check at the end.
- **Failures:** `roc_crashed` records node, message and seed, then exits with a distinct code.
- **Possible later improvement:** stackful coroutines instead of threads. Luke switches effect
  stacks in the roc-signals wasm host.

Planned layout:

```
roc-dst/
├── flake.nix            # roc nightly, rust, basic-cli rev
├── build.sh             # ./build.sh real | sim  → platform/ + libhost.a → roc build
├── app/                 # main.roc, Raft.roc, Kv.roc, Wire.roc
├── basic-cli-dst/       # trimmed platform/*.roc + deletion-only check
├── sim-host/src/        # lib.rs (exports), scheduler, rng, tcp, clock, io, alloc, config
├── checker/             # KV linearizability, reads the trace
└── experiments/         # baton, messaging, counters
```

## Build order (decided 2026-10-25)

Literature review first. Then build the sim host and the KV store together, so the store is the
first app that drives the simulator. Then run the same app on upstream basic-cli and check that
it behaves as it should. Where Raft fits in is still open.

## Raft app

- **Requirement:** users of the Raft library choose how messages are delivered (TCP, HTTP, …).
  Sans-IO isn't required; the current way to meet the requirement is below.
- An ordinary basic-cli program. Raft lives in its own modules that import nothing from the
  platform and receive their effects as arguments, a record like `{ send!, recv!, now!, random! }`.
  The user of the Raft module chooses the transport. The thesis app passes `Tcp`-based functions,
  and another app could pass HTTP or anything else.
- **No sans-IO core and no ticks:** Raft owns its loop and performs effects itself (blocking
  `recv!` with a timeout, `now!`, `send!`). The effect record exists for reuse, not for
  determinism: whatever gets passed in still goes through the platform, so the sim controls it
  either way.
- Pure helpers (log matching, commit index, encode/decode) stay pure functions where that's
  natural.
- **Verified 2026-10-25** (scratch app on the baton platform): a module with no platform imports
  can take an effectful function (`Str => {}`) as an argument and call it, and it runs in the
  sim. This was tested with a local module. That a *package* works the same way is inferred.
- Later, the Raft modules become a general Raft package.
- **Transport:** one-way messages, one TCP connection per message, framed as newline-delimited
  JSON. basic-cli has no select, so request/response over blocking reads could deadlock.
  Responses are separate messages.
- **Main loop:** `accept!` with a timeout, so election and heartbeat timers fire while waiting for
  messages (basic-cli has no select). This shapes the app, not the sim. The KV store doesn't block Raft:
  client requests become log appends, and replies are sent once the entry commits.

## Checking

- **Generic, free for any app:** crash, hang or no progress, non-determinism (same seed, different
  trace), memory budget and leaks.
- **App-specific, plugged in from outside:** `kv-sim --seed N --trace | kv-checker`. The trace is
  JSON lines of every effect and stdout line. The KV checker checks linearizability of client
  histories; nodes print state lines (term, role) for invariants such as one leader per term.
- **Overnight:** one process per seed (isolates crashes), with only failing seeds recorded:
  `seq 1 N | parallel -j16 '... || echo {} >> failing-seeds.txt'`. A seed *is* the
  recording; replay with `--seed N --trace`.

## Code style (app)

- Assertion-heavy, following TigerStyle and NASA's Power of 10 where they apply to Roc.
- **Assertions use `crash`** (`assert = |ok, msg| if ok {} else crash msg`), not `expect`:
  inline `expect` is stripped in the default `--opt=speed` build.
- **Static allocation is impossible in Roc.** Instead: a named limit for every collection,
  asserted where it grows, plus the sim's per-node memory budget.
- Bounded loops (e.g. apply at most N entries per step), paired asserts (encode/decode,
  send/receive), units in names (`timeout_ms`), zero `roc check` warnings.
