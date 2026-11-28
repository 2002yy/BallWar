#!/usr/bin/env bash
# P2.5-A 出生点旋转对照：同一套生产参数，四个旋转，检查是阵营偏差还是角落偏差。
# 用法：GODOT_BIN=... SEEDS="20001 20002 20003 20004 20005" bash scripts/tests/p25a_rotation.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/p25a_rotation}"
DURATION="${DURATION:-120}"
SEEDS="${SEEDS:-20001 20002 20003 20004 20005}"
RUN_WIN="${RUN_WIN:-}"
RESULTS="$OUT_ROOT/results.tsv"
mkdir -p "$OUT_ROOT"
if [ -n "$RUN_WIN" ]; then RUNNER=(bash "$RUN_WIN" bash); else RUNNER=(bash); fi

if [ -z "${GODOT_BIN:-}" ]; then echo "Set GODOT_BIN." >&2; exit 2; fi
extract() { awk -v key="$2" 'index($0, key) { sub(/^[^=]*=[ ]*/, "", $0); print $0; exit }' "$1"; }

echo -e "rotation\tseed\tend\tcells\tleader\tslot\tmax_share\treversal\tfirst_health\tshots" > "$RESULTS"
for rotation in 0 1 2 3; do
	for seed in $SEEDS; do
		name="rot${rotation}_s${seed}"
		env GODOT_BIN="$GODOT_BIN" OUT_ROOT="$OUT_ROOT" BALLWAR_MATCH_SEED="$seed" \
			BALLWAR_SPAWN_ROTATION="$rotation" BALLWAR_INITIAL_BALLS=2 BALLWAR_GATE_MULTIPLIER=3 \
			"${RUNNER[@]}" "$HERE/determinism_probe.sh" "$name" "$DURATION" >/dev/null 2>&1
		log=$(ls -d "$OUT_ROOT/$name".*/probe.log 2>/dev/null | head -1)
		if [ -z "$log" ] || ! grep -q -- "---- end ----" "$log" || grep -q "Cannot finish" "$log"; then
			echo -e "$rotation\t$seed\tINVALID" >> "$RESULTS"
			continue
		fi
		end=$(extract "$log" "end_reason")
		cells=$(grep -E "^  blue=" "$log" | head -1 | sed 's/^  //')
		leader=$(echo "$cells" | awk '{for(i=1;i<=4;i++){split($i,a,"="); if(a[2]+0>m){m=a[2]+0; n=i}}; print n-1}')
		slot=$(( (leader + rotation) % 4 ))
		maxshare=$(extract "$log" "territory" | sed -E 's/.*max_share=([0-9.]+)%.*/\1/')
		reversal=$(extract "$log" "territory" | sed -E 's/.*max_reversal=([0-9.]+)pp.*/\1/')
		health=$(extract "$log" "first_health_drop")
		shots=$(grep -E "spawned_total" "$log" | head -1 | sed -E 's/.*= ([0-9]+) by_type.*/\1/')
		echo -e "$rotation\t$seed\t$end\t$cells\t$leader\t$slot\t$maxshare\t$reversal\t$health\t$shots" >> "$RESULTS"
		echo "[rot] $name done"
	done
done
echo "[rot] results: $RESULTS"
