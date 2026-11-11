#!/usr/bin/env bash
# Run one FoundationDB simulation test in a fresh directory and judge it.
#
#   ./fdb-sim.sh <test file> [seed] [buggify: on|off]
#
# Needs fdbserver on PATH (nix develop). fdbserver writes trace files and a simfdb/
# directory into its working directory, so every run gets its own under runs/ (gitignored).
set -euo pipefail

test=$(realpath "${1:?usage: fdb-sim.sh <test file> [seed] [on|off]}")
seed=${2:-$RANDOM}
buggify=${3:-on}

mkdir -p "$(dirname "$0")/runs"
dir=$(mktemp -d "$(realpath "$(dirname "$0")")/runs/$seed-XXXX")
cd "$dir"

# --crash: abort on the first SevError, as upstream's ctest runs do.
set +e
fdbserver -r simulation -f "$test" -s "$seed" -b "$buggify" --crash >out.txt 2>&1
code=$?
set -e

# One event per line. Injected faults are logged as SevError too and don't count.
errors=$(cat trace.*.xml | grep 'Severity="40"' | grep -vc 'ErrorIsInjectedFault="1"' || true)
summary=$(grep -E 'tests passed' out.txt || echo 'no test summary')
unseed=$(grep -E '^Unseed' out.txt || echo 'Unseed: none')

echo "seed=$seed buggify=$buggify exit=$code sev_errors=$errors | $summary | $unseed"
echo "logs: $dir (out.txt, trace.*.xml)"

# Upstream's ctest (tests/TestRunner) fails a run only on a non-zero exit or a SevError.
# Apple's nightly harness (contrib/TestHarness2) also wants every [[test]] to report Passed=1;
# the summary line shows that.
if [ "$code" -ne 0 ] || [ "$errors" -ne 0 ]; then
  echo "FAIL"
  exit 1
fi
echo "PASS"
