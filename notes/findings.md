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
