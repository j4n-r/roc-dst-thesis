# Exposé (v3, 2026-10-31)

Changes from v2 (in git history): after the meeting with the professor on 2026-10-27, the
**comparison with existing DST approaches is the main question**. It is done from their papers
and source code, not by reimplementing the case study in other tools. The simulation host and
the Raft app remain, as the Roc side of the comparison. Deadline: four months after
registration, which is planned for mid-November 2026.

## Working title

_The Platform as Simulation Boundary: Deterministic Simulation Testing of Distributed Systems with Roc_

## Problem and motivation

Distributed systems fail in ways that are hard to reproduce: the bugs depend on message
order, timing, crashes and network faults. Deterministic simulation testing (DST) runs the
whole system in a simulated environment driven by a single seed, so that any failure can be
replayed exactly. FoundationDB and TigerBeetle show that it works, but it takes a great deal
of discipline. Every source of nondeterminism (clock, randomness, network, thread
scheduling) has to go through a replaceable interface, and a single leak breaks
reproducibility. Existing approaches rely on convention, patch the runtime, or simulate the
whole machine.

Roc takes a different route. A Roc application cannot perform side effects itself: all I/O
goes through the *platform* it runs on, and the compiler enforces this. A platform consists
of a Roc API (the modules apps import) and a native *host* that implements it. This thesis
investigates whether that boundary can serve as the simulation boundary: the same
application is built once against upstream basic-cli and once against a simulation host,
without changing its code.

## Background and related research

- **DST in practice:** FoundationDB simulates network, disk and machines within a single
  process (Zhou et al., 2021; Wilson, 2014). TigerBeetle's VOPR runs entire clusters in
  simulation. Antithesis makes unmodified software deterministic inside a hypervisor.
- **Library and runtime level:** madsim and turmoil replace the async runtime in Rust.
  Coyote/P# lets services declare their nondeterminism and controls it during testing
  (Deligiannis et al., 2021).
- **Architecture by convention:** sans-IO protocol libraries, "functional core, imperative
  shell", and etcd/raft, a Raft core with no I/O. These keep effects at the edge only by
  discipline: etcd/raft must be driven by explicit ticks and messages so that it never reads
  the clock or touches the network itself. In Roc the platform boundary enforces this, so
  the application needs no such abstraction.
- **Implementation-level model checking:** MODIST, SAMC and FlyMC intercept messages and
  timeouts of unmodified systems (Yang et al., 2009; Leesatapornwongsa et al., 2014;
  Lukman et al., 2019). They control only what they intercept.
- **Host swapping in Roc:** roc-signals builds one app against a browser host or a
  simulated-DOM test host. roc-gui embeds headless spec runners in the shipped binary
  behind a flag. Both are driven by hand-written scripts and run a single app instance
  (Boswell, 2026a, 2026b).
- **Raft:** the case-study protocol (Ongaro & Ousterhout, 2014; Ongaro, 2014).
- **Correctness:** linearizability as the property of the key-value store (Herlihy & Wing, 1990).

**Gap:** Roc already swaps hosts for scripted testing, but no source found so far uses a
language-enforced effect boundary for *seeded* simulation of a *distributed* system: many
instances in one process, with randomized fault injection and virtual time. The Roc
community confirmed that it knows of no such work.

## Research question and objectives

_How does deterministic simulation testing through Roc's platform model compare with existing
approaches, in what it requires of the application and in which sources of nondeterminism it
rules out?_

Sub-questions:
1. What do existing DST approaches (FoundationDB, TigerBeetle, madsim and turmoil) require of
   the application, and how does each control every source of nondeterminism? Answered from
   their papers and source code.
2. Can a distributed system written as an ordinary basic-cli app, using none of those
   practices, run unchanged in production and under deterministic simulation? Answered by
   building it.
3. Where can nondeterminism still leak in each approach, Roc's included, and what does the
   Roc approach gain and lose?

"Unchanged" means that the same application source builds against upstream basic-cli and
against the simulation, with no code or configuration differences inside the app.

Objectives:
1. **Comparison framework and analysis:** criteria from the literature (sources of
   nondeterminism; practices required of the app and its dependencies), applied to
   FoundationDB, TigerBeetle, madsim and turmoil at pinned revisions, with a code reference
   for every claim.
2. **Simulatable subset:** a copy of basic-cli's Roc API that only *deletes* what the sim does
   not support (TCP, time, sleep, stdout, arguments, random seed remain). An app that
   compiles against the subset is guaranteed to run in the sim; one that uses an
   unsupported effect fails to compile.
3. **Simulation host (Rust)** for that subset: several app instances in one process, a
   seeded scheduler that runs one instance at a time, virtual time, and TCP faults (delay,
   loss, partitions, partial reads, resets). It writes a complete trace of every effect.
4. **Case study:** Raft (leader election, log replication) with an in-memory key-value
   store, written as an ordinary basic-cli app in an assertion-heavy style. The Raft module
   receives its effects (send, receive, time, randomness) as functions, so its user chooses
   the transport. It performs them itself, with no sans-IO core or explicit ticks, so the
   determinism comes from the platform and not from the code style.
5. **Checking:** generic checks that need no app knowledge (crash, hang, determinism,
   memory budget) and an app-specific linearizability checker that reads the trace.
6. **Evaluation and comparison** with existing DST approaches.

Out of scope: persistence and a simulated filesystem, HTTP and the remaining basic-cli
modules, sharding, upstreaming the sim into basic-cli, evaluating how effective DST is
at finding bugs, and reimplementing the case study with the other approaches.

## Methodology

The thesis follows Design Science Research (Hevner et al., 2004; Peffers et al., 2007): build
an artefact, then evaluate it against the research question.

1. **Problem analysis:** from the literature, identify where nondeterminism enters a
   distributed system and how existing approaches control it. This yields the subset of
   effects to simulate and the criteria for the comparison.
   **Analysis of existing approaches:** for FoundationDB, TigerBeetle, madsim and turmoil,
   read the papers, talks and source code and record, per criterion, the mechanism and where
   it lives in the code.
2. **Design:** the simulatable subset of basic-cli, the scheduler, the fault model and the
   trace format.
3. **Implementation:** the simulation host and the Raft key-value app.
4. **Evaluation:**
   - *Feasibility:* the app runs unchanged on upstream basic-cli and in the sim.
   - *Determinism:* the same seed reproduces an identical trace, including under parallel
     load. A prototype already meets this for 200 seeds.
   - *Canary:* an injected Raft bug is found by a seed and replayed from it.
   - *Comparison,* criteria-based, from papers and source code: for each source of
     nondeterminism (clock, randomness, threads, hash order, sockets, allocation), whether
     it is impossible, caught or silently allowed in each approach, and which practices the
     app and its dependencies must follow.

## Expected contribution

- A simulatable subset of basic-cli and a simulation host for it, usable by any app within
  the subset, with app-specific checkers plugged in through the trace.
- A Raft key-value store that runs unchanged on upstream basic-cli and in the simulation.
- A comparison of the platform-model approach with library-level, system-level and
  convention-based DST, including where nondeterminism can still leak.
- An experience report on the practical limits, e.g. host code outside the simulation and
  the maturity of a pre-1.0 language.

## Preliminary chapter outline

1. Introduction
2. Background: distributed systems and Raft, nondeterminism, DST, Roc platforms and hosts
3. Existing approaches: comparison criteria; FoundationDB, TigerBeetle, madsim, turmoil;
   host swapping in Roc
4. Design: the simulatable subset, scheduler, fault model, trace and checkers
5. Implementation: simulation host, Raft key-value app
6. Evaluation of the Roc approach
7. Comparison and discussion: gains, losses, where nondeterminism leaks
8. Conclusion

## Risks

- **Roc is pre-1.0:** the compiler and glue generator change. Development tracks nightly; one
  compiler and one basic-cli revision are pinned for the evaluation.
- **basic-cli drift:** signatures can change between releases. Mitigated by pinning and by a
  check that the subset differs from upstream only by deletions.
- **Running several app instances in one process** works in a prototype but is not
  documented as supported. Asked in the Roc community.
- **Scope:** simulating at the TCP level is more work than a message-level API. Mitigated by
  the narrow subset; a message-level platform (as in v1) is the fallback.

## Schedule

Start: 2026-11-02. Registration: about mid-November 2026. Deadline: four months after
registration, about mid-March 2027. 30 hours per week. Task list in
[notes/plan.md](notes/plan.md).

1. Comparison criteria and analysis of existing approaches, next to the sim host and simulated TCP (Nov)
2. Raft key-value app on upstream basic-cli, then in the sim (Dec)
3. Checkers, canary, applying the comparison to Roc (Jan)
4. Writing, revision and buffer (Feb–Mar)

## References

- Boswell, L. (2026a). roc-signals. https://github.com/lukewilliamboswell/roc-signals
- Boswell, L. (2026b). roc-gui. https://github.com/lukewilliamboswell/roc-gui
- Deligiannis, P., Ganapathy, N., Lal, A., Qadeer, S. (2021). Building Reliable Cloud Services Using Coyote Actors. *ACM SoCC*.
- Herlihy, M. P., Wing, J. M. (1990). Linearizability: A Correctness Condition for Concurrent Objects. *ACM TOPLAS* 12(3).
- Hevner, A. R., March, S. T., Park, J., Ram, S. (2004). Design Science in Information Systems Research. *MIS Quarterly* 28(1).
- Leesatapornwongsa, T., Hao, M., Joshi, P., Lukman, J. F., Gunawi, H. S. (2014). SAMC: Semantic-Aware Model Checking for Fast Discovery of Deep Bugs in Cloud Systems. *OSDI*.
- Lukman, J. F. et al. (2019). FlyMC: Highly Scalable Testing of Complex Interleavings in Distributed Systems. *EuroSys*.
- Ongaro, D. (2014). *Consensus: Bridging Theory and Practice*. PhD thesis, Stanford University.
- Ongaro, D., Ousterhout, J. (2014). In Search of an Understandable Consensus Algorithm. *USENIX ATC*.
- Peffers, K., Tuunanen, T., Rothenberger, M. A., Chatterjee, S. (2007). A Design Science Research Methodology for Information Systems Research. *Journal of Management Information Systems* 24(3).
- Wilson, W. (2014). Testing Distributed Systems w/ Deterministic Simulation. *Strange Loop*.
- Yang, J. et al. (2009). MODIST: Transparent Model Checking of Unmodified Distributed Systems. *NSDI*.
- Zhou, J. et al. (2021). FoundationDB: A Distributed Unbundled Transactional Key Value Store. *ACM SIGMOD*.
