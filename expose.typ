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
  #text(size: 10pt)[HWR Berlin · Supervisor: Prof. Dr. Alexander Eck · Second examiner: Prof. Dr. Markus Schaal]
]

*Proposed title.* _Simulation Boundaries for Distributed Systems: A Comparison of Existing DST
Approaches and Roc's Platform Model_

*Problem.* Bugs in distributed systems depend on message order, timing, crashes and network
faults, so they are hard to reproduce. Deterministic simulation testing (DST) runs the whole
system in a simulated environment driven by one seed, so every failure can be replayed.
FoundationDB and TigerBeetle run entire clusters in one process with simulated network, disk
and time, and route every source of nondeterminism through interfaces the simulator can
replace; a call that bypasses them breaks reproducibility. Other approaches replace the async
runtime or networking library (madsim, turmoil), intercept system calls (Shadow) or run the
whole system in a deterministic hypervisor (Antithesis). In Roc, an application gets all of
its I/O primitives from its _platform_; the language offers no other way to perform I/O. That boundary could serve as the simulation
boundary: only the platform is swapped, so the unchanged application source runs both in
production and under simulation.
Roc projects already use alternative hosts or test modes for scripted tests, but no work was
found that uses this boundary for seeded simulation of a distributed system.

*Goal.* The thesis answers: _How does deterministic simulation testing through Roc's platform
model compare with existing approaches, in what it requires of the application and in which
sources of nondeterminism it controls?_ Sub-questions: (1) What do FoundationDB,
TigerBeetle, madsim, turmoil, Shadow and Antithesis require of the application, and how does
each control the sources of nondeterminism named in the comparison criteria? (2) Can a
distributed system run from identical source, using only a subset of basic-cli and no
simulation-specific code, in production and under deterministic simulation? (3) Where can
nondeterminism still leak in each approach, Roc's included? The main contribution is the
comparison: which restrictions Roc's I/O boundary removes from the application and which
remain in the host, compiler and dependencies. The prototype only supplies evidence.

*Approach.*
+ Derive comparison criteria from the literature: the sources of nondeterminism (for example
  clock, randomness, scheduling, network, disk, iteration order and memory allocation) and
  the practices each approach requires of the application and its dependencies.
+ Analyse the existing approaches against these criteria from their papers, documentation and
  source code at pinned revisions, with a reference for every claim. Antithesis is closed
  source, so its claims rest on its documentation and are marked as such.
+ As an experiment for sub-question 2, build a simulation host for a subset of Roc's
  basic-cli platform and a Raft key-value store, and test whether the app runs unchanged,
  one seed reproduces an identical trace, and an injected Raft bug is found and replayed.
+ Apply the same criteria to the Roc approach and present the results as a comparison
  matrix: per source of nondeterminism, how each approach controls it and what can still
  escape, and per approach, what it requires of the application and its dependencies.

*Key literature.*
#set text(size: 10pt)
#set par(spacing: 0.5em)
#set list(spacing: 0.35em)
- Antithesis (2026). How Antithesis Works. Documentation, antithesis.com/docs.
- Jansen, R., Newsome, J., Wails, R. (2022). Co-opting Linux Processes for High-Performance Network Simulation. _USENIX ATC_.
- madsim-rs (2026). madsim: Magical Deterministic Simulator for Distributed Systems in Rust. Source code, github.com/madsim-rs/madsim.
- Ongaro, D., Ousterhout, J. (2014). In Search of an Understandable Consensus Algorithm. _USENIX ATC_.
- Pshenichkin, A. (2024). So You Think You Want to Write a Deterministic Hypervisor? Blog post, Antithesis.
- Roc (2026). Platforms. Language reference, roc-lang.org/docs/main/langref/platforms.
- Shadow (2026). The Shadow Simulator. Source code and documentation, github.com/shadow/shadow.
- TigerBeetle (2026). Deterministic Simulation Testing (VOPR). Documentation, github.com/tigerbeetle/tigerbeetle.
- tokio-rs (2026). turmoil: Add Hardship to Your Tests. Source code, github.com/tokio-rs/turmoil.
- Wilson, W. (2014). Testing Distributed Systems w/ Deterministic Simulation. Talk, _Strange Loop_.
- Zhou, J. et al. (2021). FoundationDB: A Distributed Unbundled Transactional Key Value Store. _ACM SIGMOD_.
