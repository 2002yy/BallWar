#!/usr/bin/env bash
# compare_traces.sh <traceA> <traceB>
#
# Prints the first TICK whose simulation hash differs, or "IDENTICAL (ticks 0..N)".
#
# Two details that silently produce wrong answers:
#
#   1. The trace has TWO header lines, so tick = line_number - 3. Using line
#      numbers directly reports every divergence one tick late.
#   2. Comparing past the end of the shorter file yields empty fields, which a
#      naive `a[FNR] != $2` reports as divergence -- that is how a run that was
#      identical for its whole length gets mis-reported as "diverges at the
#      last tick". The comparison is therefore clamped to min(lenA, lenB).
#
# Only column 2 (sim_hash) is compared. Columns 11-13 are proc/phys/fps and are
# deliberately NOT part of the digest.

set -uo pipefail

A="${1:?usage: compare_traces.sh <traceA> <traceB>}"
B="${2:?usage: compare_traces.sh <traceA> <traceB>}"

for f in "$A" "$B"; do
  if [[ ! -f "$f" ]]; then
    echo "compare_traces.sh: no such file: $f" >&2
    exit 2
  fi
done

awk -F'\t' '
  FNR==NR { a[FNR] = $2; na = FNR; next }
  { b[FNR] = $2; nb = FNR }
  END {
    n = (na < nb) ? na : nb
    for (i = 4; i <= n; i++) {          # line 3 is tick 0
      if (a[i] != b[i]) { printf "DIVERGES at tick %d\n", i - 3; exit }
    }
    printf "IDENTICAL (ticks 0..%d)\n", n - 3
  }' "$A" "$B"
