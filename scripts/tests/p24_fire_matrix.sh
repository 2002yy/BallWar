#!/usr/bin/env bash
# P2.4 自然火力生产链实验：F0 基准 / F1-F6 单变量 / F7 组合。
# 只改实验参数，不改经典默认值。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
RUN_WIN="${RUN_WIN:-}"
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/p24_matrix}"
if [ -n "$RUN_WIN" ]; then
	RUNNER=(bash "$RUN_WIN" bash)
else
	RUNNER=(bash)
fi
DURATION="${DURATION:-120}"
SEEDS="${SEEDS:-12345}"
RESULTS="$OUT_ROOT/results.tsv"
mkdir -p "$OUT_ROOT"

if [ -z "${GODOT_BIN:-}" ]; then
	echo "Set GODOT_BIN to the Godot console executable." >&2
	exit 2
fi

variant_env() {
	case "$1" in
		F0_baseline) echo "" ;;
		F1_balls2) echo "BALLWAR_INITIAL_BALLS=2" ;;
		F2_balls4) echo "BALLWAR_INITIAL_BALLS=4" ;;
		F3_gate3) echo "BALLWAR_GATE_MULTIPLIER=3" ;;
		F4_stay7) echo "BALLWAR_STAY_SECONDS=7" ;;
		F5_pending5) echo "BALLWAR_PENDING_START=5" ;;
		F6_burst_half) echo "BALLWAR_BURST_INTERVAL_MULT=0.5" ;;
		F7_combo) echo "BALLWAR_INITIAL_BALLS=2 BALLWAR_GATE_MULTIPLIER=3 BALLWAR_BURST_INTERVAL_MULT=0.5" ;;
		F8_balls2_gate3) echo "BALLWAR_INITIAL_BALLS=2 BALLWAR_GATE_MULTIPLIER=3" ;;
		*) echo "" ;;
	esac
}

extract() { awk -v key="$2" 'index($0, key) { sub(/^[^=]*=[ ]*/, "", $0); print $0; exit }' "$1"; }

echo -e "variant\tseed\tend\tshots\tpeak\tp95\treleases\tfire\tleads\tfirst_health\tcells" > "$RESULTS"

for variant in ${VARIANTS:-F0_baseline F1_balls2 F2_balls4 F3_gate3 F4_stay7 F5_pending5 F6_burst_half F7_combo F8_balls2_gate3}; do
	envs="$(variant_env "$variant")"
	for seed in $SEEDS; do
		name="${variant}_s${seed}"
		env GODOT_BIN="$GODOT_BIN" OUT_ROOT="$OUT_ROOT" BALLWAR_MATCH_SEED="$seed" \
			$envs \
			"${RUNNER[@]}" "$HERE/determinism_probe.sh" "$name" "$DURATION" >/dev/null 2>&1
		log=$(ls -d "$OUT_ROOT/$name".*/probe.log 2>/dev/null | head -1)
		if [ -z "$log" ] || [ ! -f "$log" ]; then
			echo -e "$variant\t$seed\tMISSING" >> "$RESULTS"
			continue
		fi
		if ! grep -q -- "---- end ----" "$log" || grep -q "Cannot finish" "$log"; then
			echo -e "$variant\t$seed\tINVALID_TRACE" >> "$RESULTS"
			continue
		fi
		end=$(extract "$log" "end_reason")
		spawned=$(grep -E "spawned_total" "$log" | head -1 | sed -E 's/.*= ([0-9]+) by_type.*/\1/')
		peak=$(extract "$log" "peak_active")
		p95=$(grep -E "^  active " "$log" | head -1 | sed -E 's/.*p95=([0-9]+).*/\1/')
		releases=$(grep -E "^  f[0-9] " "$log" | sed -E 's/.*releases=([0-9]+).*/\1/' | awk '{s+=$1} END {print s+0}')
		fire=$(grep -E "^  f[0-9] " "$log" | sed -E 's/.* fire=([0-9]+) .*/\1/' | awk '{s+=$1} END {print s+0}')
		leads=$(extract "$log" "lead_changes")
		health=$(extract "$log" "first_health_drop")
		cells=$(grep -E "^  blue=" "$log" | head -1 | sed 's/^  //')
		echo -e "$variant\t$seed\t$end\t$spawned\t$peak\t$p95\t$releases\t$fire\t$leads\t$health\t$cells" >> "$RESULTS"
		echo "[p24] $name done"
	done
done
echo "[p24] results: $RESULTS"
