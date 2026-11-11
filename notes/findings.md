# Findings

Measured or read directly. Unless stated otherwise: Roc `nightly-2026-10-20-7a8a800`,
basic-cli `cbd8b47` (2026-10-13).

## Experiment: platform-dependent packages (2026-11-05)

See [`experiments/platform-compatibility`](../experiments/platform-compatibility) for the
reproducer, seven front-end checks and two native build/run cases. Tested with installed
Roc `nightly-2026-11-01-48d3369` and basic-cli `cbd8b47`, extracted from Git without changing
the local checkout. The compatibility direction is **our restricted platform → upstream**.

- App and fixture package both declare our trimmed platform: a deletion-only copy removing
  `Stdout.write_bytes!`, its hosted declaration and its native mapping. The package calls
  retained `Stdout.line!` and returns a nominal `Duration` that the app consumes and sleeps for.
- The fixture passes checking against our platform. `--replace-dep OUR_PLATFORM UPSTREAM`
  selects upstream for both app and package without changing their source, and checking
  still passes.
- Built the pinned upstream Rust host with Rust `1.97.1` and Zig `0.16.0` in basic-cli's Nix
  environment. The unchanged app builds and runs with that real host under both `--opt=dev`
  and `--opt=speed`: exit 0, empty stderr, exact output including `duration: 7000000ns`.
- Source hashes remain unchanged throughout. Pointing only the app at upstream fails with
  `platform dependency mismatch` because the package still declares ours. An app-only switch
  to a byte-identical copy of ours fails too; local root-file identity matters.
- A package using the excluded operation fails against ours with
  `pf.Stdout.write_bytes! does not exist.` and passes checking when replaced with upstream.

Consequence: this app can be authored against our restricted API and run on upstream without
source edits, using a graph-wide build-time replacement. This does not require accepting all
upstream apps on our platform. The restricted side has no simulator host yet: only its Roc
API is tested. This is a minimal subset and fixture, not proof for every accepted app, a real
third-party package, URL dependencies, the full DST subset or the older compiler used for
baton. The first version tested the opposite replacement direction; the current reproducer
and native evidence test the intended direction explicitly.

## Experiment: full subset and subset-only host (2026-11-05)

See [`experiments/subset-link`](../experiments/subset-link) for the separate reproducer.
Roc `nightly-2026-11-01-48d3369`, basic-cli `cbd8b47`, Rust `1.97.1`, x64musl only.

- The intended API trim leaves 11 public modules, four private modules and 25 hosted
  functions. It retains TCP, time/sleep, output, read-only environment, arguments and seeds;
  removes filesystem, HTTP (including the package dependency), commands, SQLite and terminal
  APIs. Every retained Roc file is checked to contain only deletions from the pinned source.
- Whole-module deletion is insufficient: `Env` also needs its filesystem operations deleted,
  and the startup wrapper's error path must stop calling excluded `Tty.disable_raw_mode!`.
- A dependency-free Rust probe host uses freshly generated glue for this subset. Its archive
  exports exactly the 25 retained `hosted_*` symbols, audited with `nm`, plus runtime support.
  No upstream host archive or replacement flag is used.
- Two apps check and link with zero warnings in both dev and speed builds. Startup receives
  the correct arguments (including an allocated long string), excludes argv[0], and converts
  `Ok({})` to exit 0 and `Err(Exit(23))` to exit 23.
- The effects fixture references all 25 hosted operations, but execution deliberately exits
  86 at its first effect. These are fail-closed linking placeholders, not simulated effects.
- Negative checks reject all nine removed exposed modules and `Env.cwd!`. Removing the
  retained `hosted_tcp_read_until` implementation makes both backend links fail naming it.

Conclusion: these fixtures need neither the deleted HTTP dependency nor excluded host
exports to check and link against the full trim. This settles API/link feasibility, not
simulation or host equivalence. Resource destruction, scheduling, interrupts, non-Unicode
arguments and real-vs-sim differential behavior remain untested here. No simulator was added.

## Experiment: baton ([`experiments/baton`](../experiments/baton), see its README)

A 3-node token ring written as an ordinary blocking Roc app (`Net.send!`, `Net.recv!` with
a timeout, `Clock.now!`, `Clock.sleep!`, `Stdout.line!`). A Rust host runs one thread per
node under a seeded scheduler and virtual time.

- 3 app instances in one process, sharing one allocator: work, no interference.
- Seed 1 run twice: byte-identical traces. Seeds 1–200, each run twice: 0 mismatches, 200
  distinct traces.
- 100 seeds sequentially vs 32-way parallel on 16 cores: identical hashes, so OS scheduling
  doesn't leak in.
- Recursive app loop: ~225k iterations per node on a 256 KB stack, i.e. constant stack.
- Cost: 10M virtual ms took 58.5 s wall (10.5 s user, 19.1 s sys) for 748k sends, mostly
  thread handoffs.
- **`Fiber.spawn!` (2026-11-11):** Go-style concurrency inside a node with no async/await. The
  app boxes a `() => {}` and the host runs it on its own fiber (thread + baton) by passing the box
  back through a second platform entry point, `roc_run_fiber`. With 3 nodes × 2 fibers (relay +
  heartbeat), seeds 1–200 each run twice gave 0 mismatches. Every heartbeat went out on schedule
  while the relay was blocked in `recv!`. Each box was freed once, and the old app's 200 trace
  hashes were unchanged. Fibers can't communicate yet (no channels).

## Probe: assertions

| | `--opt=speed` (default) | `--opt=dev` |
|---|---|---|
| inline `expect` | stripped | `[ROC EXPECT] expect failed`, keeps running |
| `crash "msg"` | `[ROC CRASHED] msg`, exit 1 | same |

`crash` ends the whole process, so a sim needs one process per seed or a custom `roc_crashed`.

## basic-cli

- 94 hosted functions (`platform/main.roc`), implemented as `#[no_mangle] extern "C"` in Rust
  (tokio inside). The crate is `staticlib` only, with exports spread over modules, so the sim
  can't depend on it and copies helpers instead.
- **TCP:** 10 functions, both server and client. Timeouts are in ns. There is no explicit
  connection close: the socket closes when Roc releases the last reference. No select or poll.
- **HTTP:** client only (`send_request`, `send_streaming`, `read_body`). It's implemented with
  hyper and doesn't go through `Tcp`. No WebSocket, no RPC.
- Build: `scripts/build.py` writes `platform/targets/<t>/libhost.a`.

## Prior art in Roc (Luke Boswell)

- **roc-signals:** one platform and two Zig hosts chosen by build target. `wasm32` is the real
  browser, native is a simulated-DOM test host. The same `roc_http_send` is real in
  `src/wasm_host.zig:2216` (calls JS) and stubbed in `src/native_host.zig:2115` (answered
  from spec stubs). The shared engine is 67k lines, native-only code 18k, wasm host 2.5k.
  Specs are S-expression scripts; timers move via `tick-interval`, tasks via `resolve-task`.
- **roc-gui** (Rust): one binary, and `--host-run-spec` picks a headless runner
  (`crates/host/src/lib.rs:7474`). Each hosted function exists once; effects branch on a grant
  set at startup (e.g. clipboard `System`/`Fixture`). HTTP and timers stay real. Rule from its
  AGENTS.md: "Test what we fly".
- **roc-ray:** full boundary record/replay, dropped because captures got too big. In DST the
  seed replaces the capture.
- **Difference to this thesis:** these are scripted, single-instance tests. The thesis uses
  seeded exploration with many instances, injected faults and virtual time.

## Prior art: SimTigerBeetle fault injection (read 2026-11-09)

[sim.tigerbeetle.com](https://sim.tigerbeetle.com/) runs real TigerBeetle replicas and clients
inside the VOPR simulator, compiled to WASM, with a game front end (Fabio Arnold, art Joy Machs;
launched 2023-07-11, [blog post](https://tigerbeetle.com/blog/2023-07-11-we-put-a-distributed-database-in-the-browser)).
The front-end source is not public. Values below were read from the rendered side panel
(headless Chromium, `?scenario=N&skip_intro`) and from UI strings in `zig-out/lib/main.wasm`.

Faults come from the seeded RNG and are grouped as in the UI:

- **Network:** one-way delay (latency range per message), packet loss ("message will be
  dropped"), replay ("duplicated and received more than once") and partition ("replica or client
  will be temporarily disconnected").
- **Storage:** read and write latency (ranges), read corruption ("a read I/O will read corrupted
  data") and write corruption ("a write I/O will write corrupted data").
- **Process:** crash ("a replica process will crash, and then later restart").

| Scenario (`?scenario=`) | Seed | Replicas / clients | Delay | Loss | Replay | Partition | Read lat. | Write lat. | Read corr. | Write corr. | Crash |
|---|---|---|---|---|---|---|---|---|---|---|---|
| City Breeze (0) | `0x0000EA51` | 5 / 3 | 1–5 ms | 0% | 0% | 0% | 1–9 ms | 1–11 ms | 0% | 0% | 0.00% |
| Red Desert (1) | `0x00DE5E87` | 6 / 4 | 2–10 ms | 13% | 2% | 1% | 0–14 ms | 1–19 ms | 0% | 0% | 0.10% |
| Radioactive (2) | `0xCC063418` | 5 / 5 | 0–6 ms | 26% | 1% | 0% | 0–14 ms | 1–67 ms | 8% | 9% | 0.01% |

City Breeze is VSR with no faults, Red Desert adds "process crashes and network partitions, but no
storage faults", and Radioactive adds per-replica storage corruption that the UI says Raft or
MultiPaxos cannot survive without protocol-aware recovery. The panel does not say what time unit
the crash percentage applies to; in the VOPR it is a per-tick probability. Adding `seed=` to the
URL (decimal or hex) did not change the shown seed, so each scenario showed one fixed
configuration.

The player can also inject faults by hand into a selected replica; the toolbar is there in all
three scenarios. Mapping icons to tooltips is inferred from the icons and strings, not clicked:

- **Hammer:** crash the replica ("Crash a replica with a hammer"). A "Duck Mode Engaged" string
  and "Crash a replica with a duck" suggest a hidden duck variant of the hammer.
- **Ice cube:** partition the replica's network.
- **Lightning:** corrupt the replica's disk.

The game shows only part of the VOPR's fault model. The VOPR also has a "liveness" mode that
stops faults and checks the cluster recovers ([Simulation Testing For Liveness](https://tigerbeetle.com/blog/2023-07-06-simulation-testing-for-liveness)),
asymmetric partitions, and (per Jepsen's [TigerBeetle 0.16.11](https://jepsen.io/analyses/tigerbeetle-0.16.11)
report) simulated clock skew and message reordering; misdirected writes and crash-time loss of
pending writes are in `src/testing/storage.zig`, not verified here. For this thesis: every row is
a probability or a latency range drawn from one seed, with a few hand-made faults on top. A Roc
simulator platform would need the same knobs at its effect boundary (network, disk, process
lifecycle).

## Concurrency model: TigerBeetle, Flow, Roc (read 2026-11-11)

Read in `dst_sources/tigerbeetle`, `dst_sources/foundationdb` and `roc_sources/basic-cli`
(`c8ce0b5`).

| | TigerBeetle | FoundationDB Flow | Roc + basic-cli (this thesis) |
|---|---|---|---|
| App code looks like | explicit callbacks | straight-line code with `wait()` | straight-line code with blocking `!` calls |
| What turns it into events | the programmer | the actor compiler (C++ → callback state machines) | the sim host, which parks the node's thread inside the hosted call |
| Threads | one; the kernel does the I/O (io_uring) | one | real: the app runs on one thread (the host has helpers, e.g. DNS workers); sim: one OS thread per node, never two running at once |
| Concurrency inside one node | many I/Os in flight | many actors; `choose`/`when` is a select | one call at a time, no select |
| How the sim is swapped in | comptime `IO`/`MessageBus`/`Storage` types | `g_network` is `Net2` (real) or `Sim2` (sim) | platform/host swap (`--replace-dep`) |
| Who decides the order in the sim | `Cluster.tick()` + PRNG | `Sim2::runLoop`: task queue by time and priority, plus `deterministicRandom()` | baton scheduler + PRNG |

- **TigerBeetle:** the main loop is `while (true) { replica.tick(); io.run_for_ns(tick_ms); }`
  (`src/tigerbeetle/main.zig:522`). I/O calls only queue an io_uring entry, and callbacks run
  one at a time on the main thread (`src/io/linux.zig:90`). The VOPR instantiates the same
  `ReplicaType` with simulated types (`src/testing/cluster.zig:68`).
- **Flow:** reads like blocking code, but the actor compiler rewrites it into callbacks.
  `Sim2::delay` adds random "buggified" delays (`fdbrpc/sim2.actor.cpp:1068`), and `runLoop`
  jumps virtual time to the next timer (`:1382`).
- **basic-cli really blocks:** TCP waits in `poll()` on one socket in 10 ms slices
  (`src/socket.rs:17`), and HTTP runs `block_on` on a current-thread tokio runtime
  (`src/http.rs:36`, `:278`).
- **Order is still nondeterministic in Roc.** Roc removes nondeterminism inside the language
  (see Zulip), but not message order, I/O completion order or timeouts. In all three systems one
  boundary decides the order, and in the sim the seed decides it. Roc's type system enforces that
  boundary; TigerBeetle and Flow rely on discipline. Because a basic-cli node has one call in
  flight, there is no completion-order race inside a node, only between nodes: which message
  lands first, whether `recv!` gets data or times out, what `now!` returns.

## Roc's concurrency plan (read 2026-11-11)

Sources: a Roc Zulip thread started by Raz asking about async I/O platforms (Richard Feldman,
souf, Luke Boswell, Romain Lepert; date: TODO, needed for citing) and Luke's summary
[gist](https://gist.github.com/lukewilliamboswell/304c57045fa0116c1a94a1baddcaf469) "Async,
Concurrency, and Coroutines in Roc", compiled with Claude from the Zulip threads "stackful
coroutines in hosts" (Sep 2024 – Feb 2025) and "async + coroutines" (Oct 2025). Luke: "I'm not
sure this is super accurate […] but it mostly looks ok to me." The "Effect Interpreters" section
of [roc-lang.org/plans](https://www.roc-lang.org/plans) (effects return a continuation closure,
like Rust's async state machines) is the older proposal and doesn't match this.

- **Roc stays synchronous** (gist): "Effects are just calls. Whatever concurrency exists is
  provided by the platform." The compiler has no `async`, `await`, `Task`, futures,
  continuations or coroutine scheduling.
- **Two mechanisms** (gist):
  1. *Host-driven coroutines:* the host runs Roc on stackful coroutines; a hosted call that hits
     I/O suspends the coroutine until the I/O is done. Roc never knows. Prototype:
     [roc-coro-webserver](https://github.com/bhansconnect/roc-coro-webserver) (Brendan
     Hansknecht).
  2. *Roc-requested concurrency:* the platform exposes hosted effects such as
     `Thread.spawn! : Box(({} -> {})) => ThreadId` and channels. Work crosses the boundary as a
     boxed callable (`RocErasedCallable` in glue); the exact API is platform design.
- **Richard: mechanism 1 is the direction**, for "a Go-style experience of 'I/O is automatically
  nonblocking without needing to write async or await'". He wants to work on it after 0.1.0
  ("on track to be later this year") and make concurrency "a major theme of the 0.2.0 release".
- **Compiler work is still needed** for "the equivalent of a type-safe Promise.all from JS",
  i.e. running several calls concurrently and getting each typed result back. No API is
  designed yet. souf proposed `run_async! : (() => a) => Future a` and
  `wait_any! : List (Future a) => (Future a, a)`, with `race`/`all` as pure Roc on top; a
  `List(Future a)` can't hold futures of different result types, which is presumably where the
  compiler work comes in (inferred, not stated).
- **Why stackful over state machines** (Richard): a real stack gives full stack traces for free.
  Rust-style async loses the call history at every I/O point unless every I/O defensively
  records the stack. In browser Wasm it stays slow until the stack-switching proposal lands
  (WASI 0.3's async ABI doesn't help the browser).
- **For the thesis:**
  - The sim host is a mechanism-1 host with a seeded scheduler and virtual time, so DST fits
    Roc's planned concurrency model instead of being bolted on. Use as motivation.
  - Baton's `Fiber.spawn!` (see the baton section) is mechanism 2 on today's compiler: the
    `Box(fn)` boundary, stored and called back later through a second entry point, freed
    exactly once. Its fibers are OS threads run one at a time, not real coroutines.
  - Cite the Zulip thread for the plan, the gist for the mechanisms, and the plans page only as
    the superseded proposal.

## Will Wilson on building your own simulator (source and date: TODO, needed for citing)

Question asked: build your own simulator (FoundationDB/TigerBeetle style) or use a
hypervisor-level platform like Antithesis from day one? His answer (verbatim; he says he works
at Antithesis):

> Pros of doing it yourself: Your own simulator will have superior startup latency, at least
> today. If you are willing to put in the work, you can achieve better bug detection/CPU cycle
> with a simulator customized for your program (though we hope to close the gap here soon). A
> simulator that works in-process can do clever tricks to avoid the "butterfly effect" for some
> small/local code modifications, which is useful for debugging.
>
> Pros of Antithesis: The architectural limitations and restrictions on dependencies imposed by
> your own simulator will be incredibly harsh and expensive. If you don't get your simulator
> right it won't find any bugs, and getting it right is harder than people realize. Antithesis
> has some fairly space-age debugging capabilities too. Antithesis can be set up in a day, and
> continues to improve without you having to be the one who improves it.

Use: the cost of in-process DST is the architecture and dependency restrictions, which is what
Roc's platform boundary should lower. His second point (a wrong simulator finds nothing) is a
caveat for this thesis too, and it is why the canary matters.

## Zulip feedback (2026-10-23/24)

Thread: "Deterministic simulation testing (DST) with Roc platforms" on the Roc Zulip.

- No known prior work on DST with Roc (Richard Feldman); feasibility: "absolutely".
- Anton: no direct matches in the group chat. The closest thing is planned simulation tests
  for effectful functions that supply simulated values, with no effect interpreter and no DST
  randomness.
- **Determinism inside Roc (Richard):** no known nondeterminism. `Dict` iterates in insertion
  order. Internally it randomizes storage, seeded from memory addresses (ASLR), against hash
  flooding, but that isn't observable from Roc. Floating point behaves the same across CPUs,
  and there is no `usize`. Only resource crashes can differ between targets (heap OOM, stack
  overflow, a `List` beyond 2^32 items on 32-bit). The reason is eager compile-time evaluation
  with cached artefacts, which has to give the same result on every machine.
- Richard: sans-IO isn't needed. Make a drop-in DST replacement for basic-cli (or a DST mode
  in it), so that running the program yields the simulation output. Two separate platforms
  would also work. The upside of one platform: an app can use DST without switching platforms
  and without hoping the drop-in's semantics match.
- Luke: Rust vs Zig hosts make little difference; pointed to roc-signals and roc-gui.
