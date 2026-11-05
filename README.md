# Bachelor thesis: Roc platform model for deterministic simulation testing

- [expose.typ](expose.typ): the one-page exposé (build command at the top of the file; needs `.env`, see `.env.example`; earlier long versions are in git history)
- [notes/reading.md](notes/reading.md): Zotero triage (essential, cite only, skip) and missing sources
- [notes/design.md](notes/design.md): design decisions and their reasons
- [notes/criteria.md](notes/criteria.md): evaluation criteria (sources of nondeterminism, practices required of the app, simulator properties)
- [notes/findings.md](notes/findings.md): experiment results, basic-cli facts, prior art, Zulip feedback
- [notes/open-questions.md](notes/open-questions.md)
- [experiments/](experiments/): `baton`, `messaging`, `counters` (each with a flake and `build.sh`), `platform-compatibility` (unchanged source on upstream), and `subset-link` (full API trim and subset-only host linking)
- [material/pitch.html](material/pitch.html): thesis pitch

Feedback from the Roc Zulip thread "Deterministic simulation testing (DST) with Roc platforms"
(2026-10-23/24) is summarized in [notes/findings.md](notes/findings.md).
