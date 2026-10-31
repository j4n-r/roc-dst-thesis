# Plan

Start 2026-11-02. Registration about mid-November 2026. Deadline four months later, about
mid-March 2027. 30 h per week.

Everything that has to happen to finish the thesis, grouped, roughly in order within each group.

## Week 1 (Mon 2 – Fri 6 Nov, 30 h)

Goal: the professor has exposé v3, the comparison has a first set of criteria, FoundationDB is
understood at paper level, and the basic-cli host is mapped.

| Day | Work | ~h |
|---|---|---|
| Mon | Request the Zeugnis; ask the examination office for the registration form and formal requirements | 1 |
| | Review exposé v3 yourself (it is an LLM draft), then send it to the professor | 2 |
| | Hevner et al. 2004: the seven DSR guidelines | 3 |
| Tue | Peffers et al. 2007: the DSR process | 1.5 |
| | Comparison criteria v0 in `notes/compare/criteria.md`: sources of nondeterminism (clock, randomness, scheduling, network, disk, iteration order, allocation, dependencies) × what each approach requires of the app | 2 |
| | Wilson 2014 talk, with notes | 2.5 |
| Wed | FoundationDB paper (Zhou 2021), focus on simulation and Flow | 3 |
| | FoundationDB Simulation and Testing docs, BUGGIFY post | 2 |
| | Start `notes/compare/foundationdb.md` along the criteria | 1 |
| Thu | basic-cli host at the pinned revision (`cbd8b47`): `platform/main.roc`, then the Rust side of TCP, time, sleep, random and stdout | 5 |
| | Note in `notes/design.md`: which hosted functions the subset keeps and what each depends on | 1 |
| Fri | Kladov's P99 talk (15 min) and a skim of TigerStyle, as a warm-up for TigerBeetle | 1.5 |
| | Update the criteria with what FoundationDB and the talk showed (v1) | 1.5 |
| | Weekly review: tick the task list, plan week 2 | 1 |
| | Buffer | 2 |

Done when:
- [ ] Zeugnis requested, exposé v3 sent
- [ ] `notes/compare/criteria.md` exists
- [ ] `notes/compare/foundationdb.md` covers the paper and docs
- [ ] The basic-cli functions in the subset are listed with their host dependencies

## Admin
- [ ] Get the internship Zeugnis
- [ ] Register the thesis
- [ ] Send exposé v3 to the professor and confirm the new research question
- [ ] Confirm the "unchanged" definition and the basic-cli-dst direction with the professor
- [ ] Find out the formal requirements (length, format, language, citation style, submission)
- [ ] Agree on when the professor sees a full draft

## Study: the comparison (main question)
- [ ] Read up on Design Science Research (Hevner 2004, Peffers 2007)
- [ ] Define the comparison criteria: sources of nondeterminism, practices required of the app
      and its dependencies
- [ ] FoundationDB: paper, Wilson's talk, Flow and the simulator in the code
- [ ] TigerBeetle: VOPR, IO and time interfaces, style rules, talks
- [ ] madsim: how it replaces tokio and std, what leaks
- [ ] turmoil: what it simulates, what it leaves to the app
- [ ] Short look at the rest: Antithesis, Coyote, MODIST/SAMC/FlyMC, sans-IO
- [ ] One note per approach under `notes/compare/`, every claim with a source or code reference
- [ ] Apply the criteria to the Roc approach: where nondeterminism can still leak
- [ ] Comparison matrix

## Build: the Roc side
- [ ] Understand basic-cli's Rust host
- [ ] basic-cli-dst: the trimmed API, plus a check that it only deletes from upstream
- [ ] Sim host skeleton: basic-cli's hello-world runs in the sim
- [ ] Simulated TCP: basic-cli's TCP client example runs against a simulated peer
- [ ] Network faults and the trace format
- [ ] Refresh Raft (paper, Ongaro thesis ch. 3)
- [ ] Raft key-value app on upstream basic-cli
- [ ] The same app in the sim
- [ ] Generic checks: crash, hang, determinism, memory
- [ ] Linearizability checker (Herlihy & Wing; how Porcupine and Knossos do it)
- [ ] Canary: an injected Raft bug found and replayed from its seed
- [ ] Pin Roc and basic-cli revisions, collect the evaluation numbers

## Writing
- [ ] Set up the thesis document (template, bibliography)
- [ ] Ch. 1 Introduction
- [ ] Ch. 2 Background
- [ ] Ch. 3 Existing approaches
- [ ] Ch. 4 Design
- [ ] Ch. 5 Implementation
- [ ] Ch. 6 Evaluation of the Roc approach
- [ ] Ch. 7 Comparison and discussion
- [ ] Ch. 8 Conclusion
- [ ] Full draft to the professor, revise after feedback
- [ ] Proofreading, formatting, references, submission

## Ongoing
- Publish something every 4 weeks (`~/me/focus.md`)
- Keep `findings.md`, `design.md` and `open-questions.md` up to date
