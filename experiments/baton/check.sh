#!/usr/bin/env bash
# Determinism check for the baton experiment.
# 1. Same seed, run twice: the full traces must be byte-identical.
# 2. Many seeds, each run twice: every seed's trace hash must repeat.
# 3. Different seeds should give different runs (count distinct hashes).
# Usage: ./check.sh [seeds] [binary], e.g. ./check.sh 200 ./spawn
set -euo pipefail
cd "$(dirname "$0")"
seeds="${1:-200}"
bin="${2:-./main}"

"$bin" 1 --trace > "${TMPDIR:-/tmp}"/baton-a.txt
"$bin" 1 --trace > "${TMPDIR:-/tmp}"/baton-b.txt
if diff -q "${TMPDIR:-/tmp}"/baton-a.txt "${TMPDIR:-/tmp}"/baton-b.txt > /dev/null; then
  echo "seed 1 twice: identical traces ($(wc -l < "${TMPDIR:-/tmp}"/baton-a.txt) lines)"
else
  echo "seed 1 twice: TRACES DIFFER"; diff "${TMPDIR:-/tmp}"/baton-a.txt "${TMPDIR:-/tmp}"/baton-b.txt | head; exit 1
fi

mismatches=0
hashes=()
for seed in $(seq 1 "$seeds"); do
  a=$("$bin" "$seed" | grep 'trace hash')
  b=$("$bin" "$seed" | grep 'trace hash')
  [[ "$a" == "$b" ]] || { echo "seed $seed: $a vs $b"; mismatches=$((mismatches + 1)); }
  hashes+=("$a")
done
distinct=$(printf '%s\n' "${hashes[@]}" | sort -u | wc -l)
echo "$seeds seeds, each run twice: $mismatches mismatches, $distinct distinct traces"
[[ $mismatches -eq 0 ]]
