# From our restricted platform to upstream basic-cli

## Question

Can we author an app against our restricted platform, then build and run it on upstream
basic-cli without changing the application or its package source?

**Yes for this fixture:** both sources declare the trimmed platform; a graph-wide
`--replace-dep` selects upstream basic-cli without editing them. The resulting native
program ran successfully with upstream's real Rust host in both dev and speed builds.

The intended compatibility direction is **restricted → upstream**, not that every upstream
app must run in the simulator. This corrects the orientation of the first version of this
experiment, which authored the fixture against upstream and replaced it with the subset.

## Run

From the thesis repository root:

```sh
python3 experiments/platform-compatibility/check.py
```

For native build/run verification on this NixOS x86_64 machine:

```sh
nix develop ./roc_sources/basic-cli -c python3 experiments/platform-compatibility/check.py --roc /run/current-system/sw/bin/roc --run-native
```

Needs Python 3.12+, Git, a basic-cli checkout containing `cbd8b47`, and a Roc compiler with
`--replace-dep`. The compiler may download the platform's pinned HTTP dependency on first
use. Override the checkout, revision or compiler with `--basic-cli`, `--rev` or `--roc`.
`--run-native` additionally requires the host's Rust/musl, Zig and stripping tools (provided
by the basic-cli development environment). It builds the committed upstream host using
upstream's `scripts/build.py --target x64musl`, without regenerating or modifying its glue.
The script creates temporary fixtures, prints diagnostics, verifies expected outcomes and
source hashes, and removes its temporary directory afterward. It never edits the checkout.

## Setup

- Extract basic-cli's committed `platform/` from Git, not from the working tree.
- Make a trimmed copy, then a byte-identical copy of that trimmed platform as a control.
- Trim exactly four lines: `Stdout.write_bytes!`'s annotation and implementation, its
  declaration in `Host.roc`, and its mapping in `main.roc`. No retained lines change.
  This is a minimal deletion probe, not the full proposed DST subset.
- A small package declares the **trimmed platform**. Its `Greeting` module calls
  `Stdout.line!` and returns a `Duration` constructed with `Duration.millis(7)`.
- The application also declares the **trimmed platform**. It calls the package, assigns its
  returned value to its own imported `Duration` type, calls `sleep!`, and prints the duration
  in nanoseconds. This tests effects and a nominal platform type crossing the package/app
  boundary.
- A second package fixture uses `Stdout.write_bytes!`, the operation removed from the copy.
- Run every case with `roc check --no-cache -j4`. Graph-wide replacement adds
  `--replace-dep /absolute/trimmed/platform/main.roc /absolute/upstream/platform/main.roc`.
- In native mode, build that same app with the replacement and upstream's real host for
  `--target=x64musl`, using both `--opt=dev` and `--opt=speed`. Check its exact output,
  empty stderr and exit status. The source files remain unchanged throughout.

## Results: 2026-11-05

- Roc: `nightly-2026-11-01-48d3369` (installed compiler).
- basic-cli: `cbd8b47c7ef180daa4f10138191ba7215a249e96` (the thesis's pinned revision).
- Native host build: Rust `1.97.1`, Zig `0.16.0` from basic-cli's Nix development environment.

| Case | Result |
|---|---|
| App and package both declare our trimmed platform | Pass, zero warnings |
| Replace our platform throughout the graph with a byte-identical copy | Pass, zero warnings |
| Only app points at byte-identical copy; package still declares ours | Fail: `platform dependency mismatch` |
| Only app points at upstream; package still declares ours | Fail: `platform dependency mismatch` |
| Unchanged app/package, replace our platform throughout graph with upstream | Pass, zero warnings |
| Package uses excluded operation, against our platform | Fail: `pf.Stdout.write_bytes! does not exist.` |
| Same package, replace our platform with upstream | Pass, zero warnings |
| Native dev build of unchanged app on upstream | Build passes, zero warnings; run exits 0, exact expected output |
| Native speed build of unchanged app on upstream | Build passes, zero warnings; run exits 0, exact expected output |

Both native runs produced the following output and no stderr:

```text
hello from a platform-dependent package
duration: 7000000ns
```

All seven front-end checks and both native build/run cases met their assertions. SHA-256
checks confirm that application and package sources do not change across checks and builds.

The byte-identical app-only control is important: for local dependencies, merely using a
different root-file path is enough to fail platform selection. The failure does not establish
that deletion changed a type's identity. With graph-wide replacement, both consumers resolve
the same replacement platform, so there is no pair of independently loaded platform types
whose equality needs to be assumed.

## Consequence for the thesis

Author the app against our restricted platform. Select upstream at build time using
`--replace-dep OUR_PLATFORM UPSTREAM_PLATFORM`; platform-dependent packages declaring our
platform are redirected as well. This fixture keeps byte-identical app/package source and
runs on upstream's real host. Excluded operations remain compile errors when using ours.

Document the build-time replacement as part of what "unchanged" means: unchanged source,
not an identical build command or an unchanged resolved dependency graph.

Limits:

- The restricted platform in this probe is only a trimmed Roc API, not a simulator host.
  The native runs use upstream's real host; simulation behavior has not been tested here.
- A successful native run covers the effects/types exercised by this fixture, not every
  hosted function or all possible ABI paths. It does not prove universal subset compatibility.
- The package is a purpose-built fixture, not an existing third-party package. This does
  not complete the exposé's third-party-package evaluation.
- Local dependency paths were tested, not release URLs/content hashes.
- Only the minimal trim above was tested, not the complete intended subset.
- The earlier `nightly-2026-10-20-7a8a800` compiler used for the baton experiment was not
  tested; these results require the recorded compiler's dependency-replacement support.
