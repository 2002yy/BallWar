#!/usr/bin/env bash
# Compare simulation hashes, including tick 0. Timing/FPS columns are diagnostic.
# Exit 0 = summaries match, 1 = simulation or termination differs, 2 = invalid trace.
set -uo pipefail

if [[ $# -ne 2 || ! -f "$1" || ! -f "$2" ]]; then
  echo "usage: compare_traces.sh <traceA> <traceB>" >&2
  exit 2
fi

awk -F'\t' '
  function invalid(message) {
    print "INVALID " FILENAME ":" FNR ": " message > "/dev/stderr"
    bad = 1
    exit 2
  }
  FNR == 1 { file++; if ($1 != "# tick" || $2 != "sim_hash" || NF != 13) invalid("header"); next }
  FNR == 2 { if ($0 !~ /^# NOTE:/) invalid("metadata"); next }
  $1 == "# end" {
    if (finished[file] || NF != 4 || ($2 != "time_cap" && $2 != "game_over") ||
        $3 !~ /^[0-9]+$/ || $4 !~ /^[0-9]+$/ ||
        count[file] < 1 || $3 != count[file] - 1 || $4 < $3 ||
        ($2 == "time_cap" && $4 != $3)) invalid("termination")
    finished[file] = 1
    reason[file] = $2
    limit[file] = $4
    next
  }
  {
    if (finished[file] || NF != 13 || $1 !~ /^[0-9]+$/ || $1 + 0 != count[file] + 0 ||
        $2 !~ /^[0-9]+$/) invalid("non-contiguous or malformed tick")
    hashes[file, count[file] + 0] = $2
    count[file]++
  }
  END {
    if (bad) exit 2
    if (file != 2 || !finished[1] || !finished[2]) {
      print "INVALID: missing header, tick data, or termination footer" > "/dev/stderr"
      exit 2
    }
    for (i = 0; i < count[1] && i < count[2]; i++) {
      if (hashes[1, i] != hashes[2, i]) { printf "DIVERGES at tick %d\n", i; exit 1 }
    }
    if (count[1] != count[2] || reason[1] != reason[2] || limit[1] != limit[2]) {
      printf "TERMINATION DIFFERS: %d (%s; limit %d) vs %d (%s; limit %d)\n",
        count[1] - 1, reason[1], limit[1], count[2] - 1, reason[2], limit[2]
      exit 1
    }
    printf "SIMULATION HASHES MATCH (ticks 0..%d, %s)\n", count[1] - 1, reason[1]
  }' "$1" "$2"
