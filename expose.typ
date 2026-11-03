// Exposé (one A4 page). The student ID is kept out of this public repo, in .env
// (see .env.example). Build with:
// sh -c '. ./.env && typst compile --input student-id="$STUDENT_ID" expose.typ'
#set page(paper: "a4", margin: (x: 2.5cm, y: 2cm))
#set text(size: 11pt, lang: "en")
#set par(justify: true, leading: 0.6em, spacing: 1em)
#set enum(spacing: 0.6em)

#align(center)[
  #text(size: 13pt, weight: "bold")[Exposé: Bachelor's Thesis] \
  Jan Rüggeberg, student ID #sys.inputs.at("student-id", default: "[student ID]") \
  #text(size: 10pt)[HWR Berlin · Supervisor: Prof. Dr. Alexander Eck]
]

*Proposed title.* _The Platform as Simulation Boundary: How Suitable Is Roc's Platform Model
for Deterministic Simulation Testing of Distributed Systems?_

*Problem.* Bugs in distributed systems depend on message order, timing, crashes and network
faults, so they are hard to reproduce. Deterministic simulation testing (DST) runs the whole
system in a simulated environment driven by one seed, so every failure can be replayed.
Existing approaches control nondeterminism at different levels: in the application's own
architecture (FoundationDB, TigerBeetle), in a replaced runtime or library (madsim, turmoil),
at the system-call level (Shadow) or in a deterministic hypervisor (Antithesis). They differ in
where the simulation boundary sits and in what that asks of the application. In Roc,
an application gets all of its I/O primitives from its _platform_; the language offers no
other way to perform I/O. That boundary could serve as the simulation boundary: only the
platform is swapped, so the same application source runs both in production and under
simulation. Roc projects already use alternative hosts or test modes for scripted tests, but
no work was found that uses this boundary for seeded simulation of a distributed system.

*Goal.* The thesis answers: _To what extent is Roc's platform model suitable for deterministic
simulation testing of distributed systems?_ Here, suitable means that the application runs
unchanged in both environments, every run is reproducible from its seed, and the remaining
paths for nondeterminism are known. Sub-questions: (1) Can a distributed system run
from identical source, using only a subset of basic-cli and no simulation-specific code, in
production and under deterministic simulation? (2) Which sources of nondeterminism does the
platform boundary control, and where can they still leak, for example in the host, the
compiler or dependencies? (3) Which restrictions does the approach place on the application
and its dependencies, compared with the existing approaches?

*Approach.*
+ Derive evaluation criteria from DST practice and research on flaky tests: the sources of nondeterminism (for
  example clock, randomness, scheduling, network, disk and iteration order) and the practices
  that existing approaches require of the application and its dependencies.
+ Build a simulation host for a subset of Roc's basic-cli platform (seeded scheduler,
  virtual time, network faults, complete trace) and a Raft key-value store as case study.
+ Evaluate: the app runs unchanged on upstream basic-cli and in the simulation; one seed
  reproduces an identical trace; an injected Raft bug is found and replayed from its seed;
  results are checked for linearizability; an unmodified third-party package works in both.
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
