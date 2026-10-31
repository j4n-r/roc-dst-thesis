# Reading list (2026-10-31)

Triage of the Zotero collection "Bachelor Thesis – Roc DST" (64 items) against the research
question in [expose.md](../expose.md). Keys are Zotero item keys.

- **Essential:** read closely. These answer a sub-question, are a comparison subject, or are a
  foundation the thesis must cite.
- **Cite only:** a reference or one sentence of context. Skim at most.
- **Skip:** not needed.

## Essential

| Key | Item | Why |
|---|---|---|
| JUC4SFL5 | FoundationDB (Zhou et al. 2021, SIGMOD) | Primary source for FoundationDB: simulation design, Flow |
| LPH6QMDT | Testing Distributed Systems w/ Deterministic Simulation (Wilson 2014) | The founding DST talk; what FoundationDB requires of its code |
| KN34U8YS | Deterministic Simulation Testing (VOPR), TigerBeetle docs | Primary TigerBeetle doc: VOPR, simulated IO and time |
| 4BKTU6Q4 | Simulation Testing For Liveness (TigerBeetle 2023) | TigerBeetle's simulator and fault model |
| 3GHHUP4P | madsim (repo) | Comparison subject; the code shows how it replaces tokio and std |
| 7JSNZKN5 | Deterministic Simulation: A New Era… (RisingWave, part 1) | The madsim authors' own design write-up |
| MS4E238Z | Deterministic simulation testing for async Rust (S2 2025) | Where turmoil leaks (time, entropy), and the libc-level fix |
| 2TJTAJC2 | In Search of an Understandable Consensus Algorithm (Ongaro & Ousterhout 2014) | Raft, the case study |
| HF7IXKRV | Consensus: Bridging Theory and Practice (Ongaro 2014) | Ch. 3 is the implementation reference for the Raft app |
| XKWN9NWN | Platforms (Roc reference) | Defines the platform/host boundary the thesis rests on |
| G4TRMESK | raft package (etcd-io/raft) docs | Main "by convention" contrast: I/O-free core driven by ticks |

## Cite only

| Key | Item | Why |
|---|---|---|
| 6VU7NI72 | Deterministic simulation testing (Antithesis docs) | Hypervisor-level approach, short look |
| H8FCHP7C | What's the big deal about DST? (Eaton 2024) | Definition and industry overview |
| XZZ4Z5HX | Applying Deterministic Simulation: The RisingWave Story (part 2) | madsim in practice: trouble with dependencies |
| 2QSNUPLK | DST in Rust: A Theater Of State Machines (Polar Signals 2025) | State-machine architecture required by convention |
| 3RDKBHDD | Testing sync at Dropbox (2020) | Industry DST (Nucleus); inspired the VOPR |
| L7W5T9XZ | How Resonate is tested | Experience report: what DST demanded of the code |
| CMBEWX4X | DST for Our Entire SaaS (WarpStream 2024) | Experience report: Antithesis with no code changes |
| DLIKAAU3 | Building Reliable Cloud Services Using Coyote Actors (2021) | Services declare their nondeterminism |
| G47XH9TS | P: safe asynchronous event-driven programming (2013) | Language-level control of nondeterminism; origin of Coyote |
| I35RZAUX | Verdi (2015) | Separates network semantics from the app, close analogy |
| PPTZX2YN | DDOS: taming nondeterminism in distributed systems (2013) | OS-level determinism, a different enforcement point |
| ECKV7SVL | Engineering Record and Replay for Deployability (rr, 2017) | Record/replay as the alternative to simulation |
| TM48UTKU | MODIST (2009) | Interception-based model checking |
| DLQEPU35 | SAMC (2014) | Interception-based model checking |
| QUGUVLF7 | FlyMC (2019) | Interception-based model checking |
| C39KVHRX | Jepsen: etcd 3.4.3 (2020) | Black-box linearizability testing of a Raft KV store |
| KSFNMC7P | Swarm testing (2012) | Randomizing the fault configuration per seed |
| HXT8E5I8 | Functions (Roc reference) | Effectful vs pure functions |
| FFRSQPY3 | FAQ (Roc) | Rationale for platforms and purity |
| N9RFLLJT | Simple Functional Effects with Tag Unions (Feldman) | Roc's effect model |
| 4P368HIU | Simple Testing Can Prevent Most Critical Failures (Yuan et al. 2014) | Motivation: failures come from fault handling |
| ELWJLWHE | Network protocols, sans I/O | Definition of sans-IO, a convention-based contrast |
| 5BPP346F | Functional Core, Imperative Shell | Convention-based contrast named in the exposé |
| FS6YMRZ8 | Handling Algebraic Effects (Plotkin & Pretnar 2013) | Effect handlers as a related language mechanism |

The experience reports (Polar Signals, Resonate, WarpStream, RisingWave part 2, Dropbox) are
company blog posts about using DST in their own product. They add no new method, but they are
evidence for what DST costs an application in practice, which the comparison needs.

## Skip

| Key | Item | Why |
|---|---|---|
| I8YXBWM8 | Random seeds and state machines (FOSDEM 2026) | Repeats the Polar Signals post |
| QKSPLQUM | Squashing the Heisenbug with DST (Tornow 2025) | General talk restating primary sources |
| ULF2CV93 | sled simulation guide | Informal guide, not a comparison subject |
| ELG6DWY8 | Introduction to simulation testing (Andjelkovic) | Secondary overview |
| MH7S4HPP | Sketching how to simulation test distributed systems | Secondary sketch |
| RY8GLKTJ | Dead Code: Deterministic Simulation (podcast) | Podcast |
| WBEYYZED | A DST primer (Amplify Partners) | Investor blog restating others |
| U3BM252P | Uncovering Bugs in Distributed Storage Systems during Testing (P#, 2016) | Covered by the Coyote paper |
| 8BF2BXBK | Building Reliable Cloud Services Using P# (preprint) | Earlier version of the Coyote paper |
| DF23T4AR | DMP | Deterministic multithreading, out of scope |
| Y9KCY5Q3 | Kendo | Deterministic multithreading, out of scope |
| U42TVSI4 | Deterministic Process Groups in dOS | Covered by DDOS |
| QFWX43YB | SandTable | Spec-level model checking |
| YUUM9MJ9 | Greybox Fuzzing of Distributed Systems | Fuzzing |
| BKBXLLJB | Lineage-driven Fault Injection | Fault-injection theory |
| J388MC6M | Model-guided Fuzzing of Distributed Systems | Fuzzing |
| IW243QFY | quickcheck-state-machine | Not used |
| ANLV5F2Z | Property-based testing stateful systems: a tutorial | Not used |
| 24NY8THN | Implement Raft in Rust (PingCAP) | Ongaro covers Raft |
| IL4KHUXP | raft.tla | No formal verification in scope |
| Y4ICPUNV | ARC: Analysis of Raft Consensus | Not needed for the case study |
| K8LIL7BG | Fault-Tolerant Computing with Unreliable Channels | Theoretical |
| F7J7844T | Changelog #645 with Richard Feldman | Podcast; Roc docs suffice |
| QC4NAV66 | Out of the Tar Pit | Generic motivation |
| VML8ZXRA | Building Protocol Libraries The Right Way | Covered by the sans-IO site |
| H3N2VNJR | sans-IO (Firezone) | Restates sans-IO |
| X3M5KXGV | Sans IO: safe and testable network protocols | Restates sans-IO |
| KBAVBKAW | Netstack3 Core/Bindings | Niche sans-IO example |
| J6DP3KE5 | Commands and Subscriptions (Elm guide) | Closest analogue, but UI only; optional |

## Added 2026-10-31 (were missing)

Essential:

| Key | Item | Collection |
|---|---|---|
| C8FA639A | turmoil (repo) | 1 DST practice |
| 8JH9RIAL | TigerStyle (TIGER_STYLE.md) | 1 DST practice |
| YCQ29UX4 | TigerBeetle (repo): read `src/vopr.zig` and `src/testing/` (`io.zig`, `packet_simulator.zig`, `cluster.zig`) | 1 DST practice |
| VZ6I99MM | Greef, TigerStyle! (Systems Distributed '23) | 1 DST practice |
| LK5C9KJQ | FoundationDB: Simulation and Testing | 1 DST practice |
| AZYEEMUC | FoundationDB: Flow | 1 DST practice |
| JDUFYJR5 | Miller, Deterministic Simulation Testing: BUGGIFY | 1 DST practice |
| R3NF8MWQ | Herlihy & Wing (1990), Linearizability | 3 Testing dist. systems |
| BFK4V9MX | Hevner et al. (2004), Design Science in IS Research | 6 Background and motivation |
| LNGRP36Q | Peffers et al. (2007), A DSR Methodology for IS Research | 6 Background and motivation |
| D6QD9IA8 | basic-cli (repo) | 5 Roc & platforms |
| YIKQKJC5 | Kleppmann & Riccomini (2026), Designing Data-Intensive Applications, 2nd ed.: the chapters on faults in distributed systems and on consistency and consensus (background chapter; linearizability before the checker). Check whether it covers DST | 6 Background and motivation |
| Y2HDX2GQ | Kladov, A Deterministic Walk Down TigerBeetle's main() Street (P99 CONF 2023, 15 min) | 1 DST practice |

Cite only:

| Key | Item | Collection |
|---|---|---|
| QAWX9IU2 | Porcupine (repo) | 3 Testing dist. systems |
| BGGFMN5H | Knossos (repo) | 3 Testing dist. systems |
| 2LTZFQI6 | roc-signals (repo) | 5 Roc & platforms |
| YW7PRUDZ | roc-gui (repo) | 5 Roc & platforms |

The web items have no author or date yet; fill them in before citing.
