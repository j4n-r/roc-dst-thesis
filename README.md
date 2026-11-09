# Bachelor thesis: Roc platform model for deterministic simulation testing

Deterministic simulation testing is hard and puts a lot of constraints on your applications design and code.
Rocs platfrom model provides a native boundary to decouple non determinism from the application.
This thesis explores that boundary and how it might help writing a deterministic simulator for your applications or a general even one.

All of the projects code is written by myself, excluding the experiments. Not because I hate LLMs but because I think it is valuable in this context to do so.
I need to defend this thesis and its project so I should know whats written in it and more importantly why it was written.
The thesis will also be hand-written, the expose isn't.

Everything below this line is LLM-generated.

---

This repo contains most of the work for my bachelor thesis about deterministic simulation testing with roc.

- [expose.typ](expose.typ): the one-page exposé (build command at the top of the file; needs `.env`, see `.env.example`; earlier long versions are in git history)
- [notes/reading.md](notes/reading.md): Zotero triage (essential, cite only, skip) and missing sources
- [notes/design.md](notes/design.md): design decisions and their reasons
- [notes/criteria.md](notes/criteria.md): evaluation criteria (sources of nondeterminism, practices required of the app, simulator properties)
- [notes/findings.md](notes/findings.md): experiment results, basic-cli facts, prior art, Zulip feedback
- [notes/open-questions.md](notes/open-questions.md)
- [experiments/](experiments/): `baton` (several blocking nodes under a seeded scheduler; flake and `build.sh`), `platform-compatibility` (unchanged source on upstream), and `subset-link` (full API trim and subset-only host linking)
- [roc_sources/](roc_sources/): upstream basic-cli and the Roc compiler as git submodules, for
  reading and for the experiments' scripts. Clone with `git clone --recurse-submodules`, or run
  `git submodule update --init` afterwards.

Feedback from the Roc Zulip thread "Deterministic simulation testing (DST) with Roc platforms"
(2026-10-23/24) is summarized in [notes/findings.md](notes/findings.md).
