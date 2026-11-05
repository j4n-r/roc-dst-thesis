# Full subset and subset-only host link probe

## Question and result

Can the intended restricted basic-cli API be made by deletion, and can applications
using it link with a host that exports only its retained hosted functions?

**Yes for these fixtures on x64musl**, with both `--opt=dev` and `--opt=speed`.
No `--replace-dep` and no upstream `libhost.a` are used in these builds.
This is an API/link feasibility experiment, **not a simulator**. Hosted effects
are deliberately fatal placeholders, not successful fake implementations.

## Reproduce

From the thesis repository root on this NixOS x86_64 machine:

```sh
nix develop ./roc_sources/basic-cli -c python3 experiments/subset-link/check.py --roc /run/current-system/sw/bin/roc
```

Recorded run: 2026-11-05, Roc `nightly-2026-11-01-48d3369`, Rust `1.97.1`.
The script requires Python 3.12+, Git, `nm`, and Rust with the
`x86_64-unknown-linux-musl` target (available in that Nix environment).
It reads basic-cli revision `cbd8b47c7ef180daa4f10138191ba7215a249e96`
from `roc_sources/basic-cli/`, and the matching compiler glue specification at `48d3369`
from `roc_sources/roc/`. Override paths with `--basic-cli`, `--roc-source`, or `--roc`;
revision overrides are `--rev` and `--glue-rev`.

Everything generated lives in an automatically removed temporary directory.
Neither source checkout is modified. The script archives committed sources,
not the current working trees, and compiles a dependency-free Rust static
library directly with `rustc`. It reuses the pinned platform's native linker
support files, but replaces its `libhost.a` with the probe host.

## The trim

Public modules retained:

`Duration Env IOErr Monotonic OsStr Random Sleep Stderr Stdout Tcp Utc`

Private modules retained:

`Host Resource InternalDateTime InternalUtf16`

- Retain TCP, sleep, UTC and monotonic time, stdout/stderr, read-only environment
  access, program name, startup arguments, and random seeds.
- Remove the exposed modules `Cmd File Http Locale Path Sqlite Stdin Tty Url`
  and their unsupported private dependencies and hosted declarations.
- Remove the platform's `http` package dependency and HTTP type declarations.
- `Env` cannot be kept wholesale: delete its filesystem operations (working
  directory, executable path and temporary directories), retaining `var!`,
  `var_str!`, `dict!`, `program_name!`, and `platform!`.
- `Resource` retains the opaque handle and TCP connection/listener types only.
- The pinned startup wrapper references `Tty.disable_raw_mode!` when reporting
  an application error. Delete that call and its associated comment too. Error
  dispatch otherwise remains; the excluded terminal API is not secretly retained.

The script verifies every resulting Roc file is a character subsequence of the
original: only deletions, with no inserted characters or reordered retained text.
Shortening the one-line `exposes` list therefore appears as a replacement line
in a unified diff; this is token/character deletion, not strictly line deletion.
Retained API implementations and signatures are not rewritten.

The resulting `hosted` table has **25 functions**:

| Family | Retained native symbols, with `hosted_` prefix |
|---|---|
| Environment | `env_var`, `env_dict`, `env_platform`, `env_program_name` |
| Random | `random_seed_u32`, `random_seed_u64` |
| Time | `sleep_nanos`, `monotonic_now`, `utc_now` |
| Output | `stdout_line`, `stdout_write`, `stdout_write_bytes`, `stderr_line`, `stderr_write`, `stderr_write_bytes` |
| TCP | `tcp_listen`, `tcp_local_port`, `tcp_accept`, `tcp_listener_close`, `tcp_connect`, `tcp_read_up_to`, `tcp_read_exactly`, `tcp_read_until`, `tcp_read_line`, `tcp_write` |

## Host and fixtures

`check.py` runs `roc glue` against the trimmed platform and generates the 25
placeholder exports using the resulting Rust ABI declarations. Every hosted
function prints `LINK-ONLY HOST: <symbol>` and exits with code 86. No placeholder
returns a fake socket, timestamp, random seed, or success value.

`host.rs` supplies real startup and the generated default allocation/debug/crash
support. Its C `main` converts the test's UTF-8 arguments to Roc `OsStr` values,
omits argv[0], and invokes the platform's exported `roc_main` wrapper.

- `smoke.roc` verifies two argument values, including a long string requiring
  allocation. It exits 0 with the expected arguments and 23 without them.
- `effects.roc` references every retained hosted effect through public Roc APIs.
  It builds, but intentionally exits 86 at its first effect, `Env.platform!`.
  Later effects are **linked, not executed**.

## Observed checks

| Check | Result |
|---|---|
| Both fixtures against the full trim | Check passes, zero warnings |
| Import each of the nine removed exposed modules | Checking fails |
| Call removed `Env.cwd!` | Checking fails |
| Audit archive's defined `hosted_*` exports with `nm` | Exactly the 25 retained symbols, no excluded ones |
| Build both fixtures with the subset-only host, dev and speed | All four links pass, zero warnings |
| Smoke startup, argument handling and exit conversion, both backends | Exit 0 with correct arguments; exit 23 without arguments |
| Invoke effects fixture, both backends | Exit 86 with exactly `LINK-ONLY HOST: hosted_env_platform` |
| Remove `hosted_tcp_read_until` from the host and rebuild effects fixture | Both backends fail linking and name the missing symbol |

The missing-symbol control checks that a later TCP operation really survives
compilation; the successful link is not just an empty app with unused imports.

## What this settles, and what it does not

The full API trim does not need the HTTP package or excluded hosted exports to
check and link these programs. There is no hidden requirement to implement all
of basic-cli just to build against this restricted platform.

This does **not** establish simulation behavior, TCP resource destruction,
non-Unicode argument handling, scheduling, interrupt delivery, leak freedom, or
semantic equivalence with upstream. The startup host is single-instance only.
The sentinel host is experimental and must not become the production promise
that every app checking against our platform runs in the simulator.

Only x64musl and the recorded compiler were tested. The complete trimmed API
was not run on the real host here; the separate
[`platform-compatibility`](../platform-compatibility) experiment covers unchanged
source running on upstream with a smaller trim. A later differential workload
needs an actual simulation host and must compare observable output/error tags
against the real host, rather than merely checking links.
