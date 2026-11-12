// Exposé (one A4 page). The student ID is kept out of this public repo, in .env
// (see .env.example). Build with:
// sh -c '. ./.env && typst compile --input student-id="$STUDENT_ID" expose.typ'
#set page(paper: "a4", margin: (x: 2.5cm, y: 2cm))
#set text(size: 11pt, lang: "en")
#set par(justify: true, leading: 0.65em, spacing: 1.4em)
#set enum(spacing: 0.8em)

#align(center)[
  #text(size: 13pt, weight: "bold")[Exposé: Bachelor's Thesis] \
  Jan Rüggeberg, student ID #sys.inputs.at("student-id", default: "[student ID]") \
  #text(size: 10pt)[HWR Berlin · Supervisor: Prof. Dr. Alexander Eck · 12 November 2026]
]

*Proposed title.* _Deterministic Simulation Testing of Distributed Systems: Evaluating the
Language-Enforced I/O Boundary of the Roc Programming Language_

*Problem.* Bugs in distributed systems depend on message order, timing, crashes and network
faults, so they are hard to reproduce. Deterministic simulation testing (DST) runs the whole
system in a simulated environment driven by one seed, so every failure can be replayed.
Existing approaches control nondeterminism at different levels: in the application's own
architecture (FoundationDB, TigerBeetle), in a replaced runtime or library (madsim, turmoil),
at the system-call level (Shadow) or in a deterministic hypervisor (Antithesis). They differ in
where the simulation boundary sits and in what that asks of the application. In Roc,
an application gets all of its I/O primitives from its execution environment, which Roc calls
the _platform_; the language offers no other way to perform I/O. This language-enforced I/O boundary could serve as the simulation boundary: only the
platform is swapped, so the same application source runs both on Roc's default platform, basic-cli, and under
simulation. Roc projects already use alternative hosts or test modes for scripted tests, but
no work was found that uses this boundary for seeded simulation of a distributed system.

*Goal.* The thesis answers: _To what extent is Roc's language-enforced I/O boundary suitable
for deterministic simulation testing of distributed systems?_ Sub-questions: (1) To what extent can the same
distributed application code run unchanged both in Roc's default execution environment
(the basic-cli platform) and in a prototype deterministic simulation environment? (2) Which
sources of nondeterminism relevant to replay in the case study can the prototype control
through this I/O boundary, and under what assumptions? (3) In the case
study, which constraints does DST impose on the application's design and on its choice and use
of dependencies?

*Approach.*
+ Analyse the literature on DST and flaky tests, guided by: which sources of nondeterminism
  visible to application code do existing DST approaches and studies report, and how do they
  control them? This yields the evaluation criteria (sources such as clock, randomness,
  scheduling, network, disk and iteration order, and practices required of the application).
+ Build a simulation host for a subset of Roc's basic-cli platform (seeded scheduler,
  virtual time, network faults, complete trace) and a Raft key-value store as case study. With only blocking I/O, bugs
  arise only from interleavings between nodes, and Raft exercises exactly these. It is also the
  standard teaching system for distributed systems: simple to specify, but error-prone to
  implement.
+ Evaluate: how much of the app's code runs unchanged on upstream basic-cli and in the simulation; one seed
  reproduces an identical trace; an injected Raft bug is found and replayed from its seed;
  the client operations are checked for linearizability; an unmodified third-party package works in both.
+ Apply the criteria to the Roc approach, using the prototype and the host code, and discuss
  the results against the existing approaches, which form the related work.

*Key literature.*
#set text(size: 10pt)
#set par(spacing: 0.5em)
#set list(spacing: 0.35em)
- Herlihy, M. P., Wing, J. M. (1990). Linearizability: A Correctness Condition for Concurrent Objects. _ACM TOPLAS_ 12(3).
- Jansen, R., Newsome, J., Wails, R. (2022). Co-opting Linux Processes for High-Performance Network Simulation. _USENIX ATC_.
- Luo, Q., Hariri, F., Eloussi, L., Marinov, D. (2014). An Empirical Analysis of Flaky Tests. _ACM FSE_.
- Ongaro, D., Ousterhout, J. (2014). In Search of an Understandable Consensus Algorithm. _USENIX ATC_.
- Roc (2026). Platforms. Language reference, roc-lang.org/docs/main/langref/platforms.
- TigerBeetle (2026). Deterministic Simulation Testing (VOPR). Documentation, github.com/tigerbeetle/tigerbeetle.
- Wilson, W. (2014). Testing Distributed Systems w/ Deterministic Simulation. Talk, _Strange Loop_.
- Zhou, J. et al. (2021). FoundationDB: A Distributed Unbundled Transactional Key Value Store. _ACM SIGMOD_.
