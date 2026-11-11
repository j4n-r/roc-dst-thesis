# DST prior art: TigerBeetle and FoundationDB

Both simulators, pinned as git submodules, so you can run them yourself.

| Submodule | Pinned at | Simulator |
| --- | --- | --- |
| `tigerbeetle/` | release `0.17.10` | the VOPR (`src/vopr.zig`) |
| `foundationdb/` | tag `7.3.68` (`7aa6328`) | `fdbserver -r simulation` with a test file from `tests/` |

All commands below run from this directory (`dst_sources/`).

## TigerBeetle: the VOPR

TigerBeetle pins its own Zig (0.14.1, statically linked, so it runs on NixOS as is). Download it once:

```sh
cd tigerbeetle
./zig/download.sh
```

Then run the VOPR. The first build takes about a minute.

```sh
./zig/zig build vopr -- 123          # seed 123
./zig/zig build vopr                 # random seed (printed at the top as SEED=...)
./zig/zig build vopr -- --lite 123   # small cluster, only looks for crashes
./zig/zig build vopr -Dvopr-log=full -- 123   # log everything, not only state transitions
```

The header shows the fault parameters drawn from the seed (packet loss, delays, clogging, crash
rates, ...). Each line after it is one replica's state change. `docs/internals/testing.md` explains
the columns. A run ends with `PASSED (<ticks> ticks)`. A failure is an assertion or checker panic,
reproducible with the same seed at the same commit.
Overrides are listed in `CLIArgs` in `src/vopr.zig`, for example
`./zig/zig build vopr -- --requests-max=20 --packet-loss-ratio=50/100 42`.

Checked on 2026-11-10: seed 123 passes in 653,173 ticks. Two runs gave byte-identical output.

## FoundationDB: simulation tests

Building FoundationDB takes hours, so the flake here gives you nixpkgs' prebuilt `fdbserver`
7.3.68. That's the same tag as the submodule, so the test files match the binary. The flake checks
the version when you enter the shell. `fdb-sim.sh` runs one test in its own directory under `runs/`
(gitignored), because `fdbserver` writes trace files and a `simfdb/` directory into its working
directory.

```sh
nix develop -c ./fdb-sim.sh foundationdb/tests/fast/CycleTest.toml 123        # buggify on
nix develop -c ./fdb-sim.sh foundationdb/tests/fast/CycleTest.toml 123 off    # buggify off
```

Output:

```
seed=123 buggify=on exit=0 sev_errors=0 | 1 tests passed; 1 tests failed. | Unseed: 89672
logs: .../dst_sources/runs/123-XXXX (out.txt, trace.*.xml)
PASS
```

- **Determinism:** `Unseed` is the next random number after the run. The same seed and binary give
  the same unseed (89672 for seed 123 above), which is how FoundationDB checks itself for
  nondeterminism.
- **Verdict:** `PASS`/`FAIL` follows upstream's ctest runner (`tests/TestRunner/TestRunner.py`):
  a run fails only on a non-zero exit or a SevError (`Severity="40"`) trace event that isn't an
  injected fault. Apple's nightly harness (`contrib/TestHarness2`) is stricter: every `[[test]]` in
  the file must also pass, which the "tests passed" summary shows.
- **CycleTest:** the `Unclogged` phase often reports `Rate below desired rate` (Severity 30) on
  this tag, also with Apple's own release binary. It's a throughput expectation, not the cycle
  invariant, which held on every seed tried.
- **Other tests:** the files under `foundationdb/tests/` (`fast/`, `slow/`, `rare/`, ...). The
  workloads they name are compiled into `fdbserver`, with sources in `fdbserver/workloads/`.
  `tests/CMakeLists.txt` lists what upstream runs and what it ignores.
- **Plain command,** without the wrapper: `fdbserver -r simulation -f <test> -s <seed> -b on --crash`.

The nixpkgs binary carries a few build patches (toml11, Boost and include fixes) and isn't built
from the submodule. To run the simulator on modified FoundationDB code, you'd have to build
`fdbserver` from `foundationdb/` yourself, and that isn't set up here.
