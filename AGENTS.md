# Local source checkouts

- This thesis workspace is `~/dev/thesis`.
- Upstream sources are git submodules under `roc_sources/`: basic-cli in `roc_sources/basic-cli/`
  and the Roc compiler in `roc_sources/roc/`. After cloning, run
  `git submodule update --init`.
- Roc's syntax examples are in `roc_sources/roc/test/echo/all_syntax_test.roc`.
- Check these local sources before searching elsewhere for platform or language details.
- The experiments pin their own revisions (`--rev`, `--glue-rev` in each `check.py`), so the
  submodule commits are for reading, not what the experiments build against.
