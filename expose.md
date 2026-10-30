---
tags:
  - atomic
up:
  - "[[Bachelor Thesis - Roc DST]]"
---
## Working Title
 _The Platform as Simulation Boundary: Deterministic Simulation Testing of Distributed Systems with Roc_
## Problem and motivation

Distributed systems fail in ways that are hard to reproduce: the bugs depend on message order, timing, crashes and network faults. Deterministic simulation testing (DST) addresses this by running the whole system in a simulated environment driven by a single seed, so that any failure can be replayed exactly. Its use at FoundationDB and TigerBeetle shows that it works, but it needs a great deal of discipline. Every source of nondeterminism (clock, randomness, network, thread scheduling) has to be routed through a replaceable interface, and a single leak breaks reproducibility. Existing approaches either rely on convention, patch the runtime, or simulate the whole machine.

Roc takes a different route. A Roc application cannot perform side effects itself: all I/O goes through the *platform* it runs on, and the compiler enforces this. This thesis investigates whether that platform boundary can serve as the simulation boundary, so that one application runs unchanged on a simulation platform and a production platform.

## Background and related research

- **DST in practice:** FoundationDB simulates network, disk and machines within a single process (Zhou et al., 2021; Wilson, 2014). TigerBeetle's VOPR runs entire clusters in simulation. Antithesis makes unmodified software deterministic inside a hypervisor.
- **Library and runtime level:** madsim and turmoil replace the async runtime in Rust. Coyote/P# lets services declare their nondeterminism and controls it during testing (Deligiannis et al., 2021).
- **Architecture by convention:** sans-IO protocol libraries, "functional core, imperative shell", and etcd/raft, a Raft core with no I/O driven by explicit ticks and messages. All of these keep effects at the edge, but only by discipline.
- **Implementation-level model checking:** MODIST, SAMC and FlyMC intercept messages and timeouts of unmodified systems (Yang et al., 2009; Leesatapornwongsa et al., 2014; Lukman et al., 2019). They control only what they intercept.
- **Raft:** the case-study protocol (Ongaro & Ousterhout, 2014; Ongaro, 2014).
- **Roc:** a pure functional language in which platforms provide all I/O primitives.

**Gap:** none of the sources found so far examines a language-enforced effect boundary as the boundary of a deterministic simulation.

## Research question and objectives

_How can Roc's platform model be used to run one distributed system unchanged under deterministic simulation and in production, and what does this approach gain and lose compared with existing approaches?_

Objectives:
1. Design a Roc platform API that a Raft node needs: messages, timers, client requests, and state inspection for invariant checks.
2. Implement a simulation platform and a production platform behind that API, with Rust hosts.
3. Implement Raft (leader election, log replication) with an in-memory key-value store as a Roc application that runs on both.
4. Evaluate the approach and compare it with existing DST approaches.

Out of scope: persistence (only if time remains), sharding, and evaluating how effective DST is at finding bugs.

## Methodology

The thesis follows Design Science Research (Hevner et al., 2004; Peffers et al., 2007): build an artefact, then evaluate it against the research question.

1. **Problem analysis:** From the literature, identify where nondeterminism enters a distributed system (time, randomness, network, scheduling) and how existing approaches control it. This yields the requirements for the platform API and the criteria for the comparison.
2. **Design:** The platform API, shared by both platforms.
3. **Implementation:** A simulation platform (seeded PRNG, logical time, network faults, crashes), a production platform (sockets, real clock), and the Raft application.
4. **Evaluation:**
   - *Feasibility:* the same application code runs on both platforms without changes.
   - *Determinism:* the same seed reproduces an identical trace.
   - *Comparison:* a criteria-based comparison with existing approaches, including for each source of nondeterminism whether it is impossible, caught or silently allowed.

   An injected Raft bug serves as a canary to show that the simulation works; how effective DST is at finding bugs is out of scope.

## Expected contribution

- A platform API design that makes Roc's platform boundary usable as a simulation boundary.
- An open-source implementation of a narrow simulation platform, a production platform, and a Raft key-value store that runs on both.
- A comparison of the platform-model approach with library-level, system-level and convention-based DST, including a classification of where nondeterminism can still leak.
- An experience report on the practical limits of the approach, e.g. host code outside the simulation and the maturity of a pre-1.0 language.

## Preliminary chapter outline

1. Introduction
2. Background: distributed systems and Raft, nondeterminism, DST, Roc platforms
3. Related work: approaches to deterministic simulation
4. Design of the platform API
5. Implementation: simulation platform, production platform, Raft application
6. Evaluation
7. Discussion: gains, losses, limitations
8. Conclusion

## Risks

- **Roc is pre-1.0:** the compiler and the glue generator are changing; known glue bugs already require workarounds.
- **Implementation effort:** mitigated by the narrow scope (no persistence, no sharding).
- **"Unchanged" may need a shared package:** each Roc app names exactly one platform, so running the same Raft code on two platforms may require a shared Raft package with two thin app wrappers.

## Schedule

Start: 2026-10-25. Deadline: TBD.

1. Literature review and exposé
2. Platform API design and simulation platform
3. Raft application
4. Production platform
5. Evaluation and comparison
6. Writing and buffer

## References

- Deligiannis, P., Ganapathy, N., Lal, A., Qadeer, S. (2021). Building Reliable Cloud Services Using Coyote Actors. *ACM SoCC*.
- Hevner, A. R., March, S. T., Park, J., Ram, S. (2004). Design Science in Information Systems Research. *MIS Quarterly* 28(1).
- Leesatapornwongsa, T., Hao, M., Joshi, P., Lukman, J. F., Gunawi, H. S. (2014). SAMC: Semantic-Aware Model Checking for Fast Discovery of Deep Bugs in Cloud Systems. *OSDI*.
- Lukman, J. F. et al. (2019). FlyMC: Highly Scalable Testing of Complex Interleavings in Distributed Systems. *EuroSys*.
- Ongaro, D. (2014). *Consensus: Bridging Theory and Practice*. PhD thesis, Stanford University.
- Ongaro, D., Ousterhout, J. (2014). In Search of an Understandable Consensus Algorithm. *USENIX ATC*.
- Peffers, K., Tuunanen, T., Rothenberger, M. A., Chatterjee, S. (2007). A Design Science Research Methodology for Information Systems Research. *Journal of Management Information Systems* 24(3).
- Wilson, W. (2014). Testing Distributed Systems w/ Deterministic Simulation. *Strange Loop*.
- Yang, J. et al. (2009). MODIST: Transparent Model Checking of Unmodified Distributed Systems. *NSDI*.
- Zhou, J. et al. (2021). FoundationDB: A Distributed Unbundled Transactional Key Value Store. *ACM SIGMOD*.
