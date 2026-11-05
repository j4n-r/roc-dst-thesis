# Design decisions

State as of 2026-11-05. The reasons come from discussion and the experiments in
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

## Selecting the platform (decided 2026-11-05)

The app and its packages declare **basic-cli-dst**. The plain build runs in the sim. The real
build replaces the platform for the whole dependency graph:
`roc build --replace-dep <basic-cli-dst> <upstream basic-cli>`. Evidence:
`experiments/platform-compatibility` and `experiments/subset-link` in [findings.md](findings.md).

Roc picks a platform's host by target (`targets/<target>/libhost.a`), not by mode. On one
target, "one platform with a real and a sim host" therefore means one of two things:

| | Real build | Compile-time subset | Cost |
|---|---|---|---|
| **A. Subset platform + `--replace-dep`** (chosen) | upstream basic-cli, its `.roc` and host | yes | one flag per distinct platform declaration in the graph |
| B1. Full basic-cli API, sim host beside the real one | upstream | no: unsupported effects fail at runtime | sim for all 94 hosted functions, or runtime errors |
| B2. Trimmed API, swap `libhost.a` | trimmed API on upstream's host | yes | host swapped outside the compiler (stale host risk); weaker "runs on basic-cli" claim |

- **Why A:** the platform API is the simulation boundary and the type checker enforces it, which
  is the thesis title. The real side is literally upstream basic-cli. The sim host needs only the
  25 retained hosted functions.
- **"Unchanged" means** byte-identical app and package source. Platform selection is a build
  input, and the resolved dependency graph differs between the builds.
- **Packages:** those without a platform dependency need nothing. Each distinct platform
  declaration needs its own flag, matched exactly (path or URL and hash). The Raft modules take
  effects as arguments, so they are unaffected.
- **Fallback B2:** the app source is the same as under A, so switching needs no app edits. Use it
  if `--replace-dep` becomes painful with real packages. In the review, the B2 and A speed builds
  of the fixture were byte-identical.
- **B1 is future work:** a DST mode inside basic-cli, i.e. one `libhost.a` whose `hosted_*`
  functions dispatch to tokio or the simulator by a startup switch (e.g. a seed variable). It
  avoids the flags and lets apps just name basic-cli, but needs a sim (or runtime error) for all
  94 functions, loses the compile-time boundary, and reworks basic-cli's tokio startup, which
  owns `main` and runs one `roc_main` per process. The subset sim host is most of what that mode
  needs.

## Differential test (sim host vs real host)

Answers Richard's concern that the semantics of the two hosts may not match: check it rather
than hope.

- Build one workload app twice, against basic-cli-dst (sim host) and with `--replace-dep`
  (upstream host), and run both.
- **Compare:** stdout, exit codes, and error tags (e.g. connecting to a port nobody listens on
  gives the same `Err` tag).
- **Exclude:** wall-clock times and anything shaped by injected faults. The sim run uses a
  no-fault scenario.
- **Needs a sim host first.** `subset-link`'s placeholders exit 86, and baton uses its own toy
  API. Start with args, env, stdout and exit codes, which are trivial to simulate, then add TCP
  and time as the sim host grows.

## Subset

**Not fixed yet.** The subset follows from what the Raft KV app and its third-party package
actually use, so it is set once that app exists. `experiments/subset-link` uses the list below
only to prove the mechanism (deletion-only trim, subset-only host), not to decide the subset.
Adding a function back later means restoring deleted lines and implementing it in the sim host.

Working assumption: TCP (listen, accept, connect, read_*, write; close happens on last release), sleep, Utc and
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
└── experiments/         # baton, platform-compatibility, subset-link
```

## Build order (decided 2026-10-25)

Literature review first. Then build the sim host and the KV store together, so the store is the
first app that drives the simulator. Then run the same app on upstream basic-cli and check that
it behaves as it should. Where Raft fits in is still open.

- **Build order is not evidence (2026-11-05).** Nobody can verify which was written first, so
  writing the app on basic-cli before the sim would prove nothing. The order is chosen for
  convenience: sim first or together, because failures reproduce from a seed and are easy to
  debug there, unlike on real TCP.
- **The "unchanged" claim rests on three checks anyone can repeat:**
  1. The app's source passes the criteria check: it uses none of the practices existing DST
     approaches require of the app (e.g. injected clocks, a sans-IO core, a custom runtime).
  2. Code not written for this thesis runs unchanged in the sim: basic-cli's examples and the
     third-party package.
  3. The same source works correctly on upstream basic-cli (built with `--replace-dep`): for the
     KV app, clients' puts and gets succeed and return correct results. That the build succeeds
     is only a sanity check: the platform deletes from upstream without changing signatures, so
     it should always build. A failure would point to an edge of the subset guarantee (e.g. an
     app module named like a deleted platform module, untested) or a wrong `--replace-dep`.
- **Compatibility is not fidelity.** Check 3 says the app is a real basic-cli program. The
  differential test (sim and upstream give the same stdout, exit codes and error tags) says the
  sim behaves like basic-cli and belongs to the evaluation of the simulated TCP. Both use the
  same builds, but either can fail without the other.
- **Safeguard while building: run on upstream from the first version.** Every version of the KV
  app is also built with `--replace-dep` and run on upstream basic-cli. This is discipline, not
  proof: it catches changes that only make sense because of the sim, i.e. the co-design that
  FoundationDB (Flow) and TigerBeetle (I/O interfaces, TigerStyle) rely on. Debugging stays in
  the sim: when upstream fails and the sim doesn't, make the sim reproduce it, then debug there.
- **CI (once the repo has a remote, the sim host and a first app exist):** on every push, build
  the app against basic-cli-dst and with `--replace-dep`, run the workload on both hosts, and
  compare. One job covers the build sanity check, check 3 and the differential test.

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
