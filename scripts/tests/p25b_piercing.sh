#!/usr/bin/env bash
# P2.5-B 穿透弹自然平衡：生产参数固定为 F8（2 球 + 门×3），扫描穿透预算/火力比例/互撞。
# 用法：GODOT_BIN=... SEEDS="12345 23456 34567" bash scripts/tests/p25b_piercing.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/p25b_piercing}"
DURATION="${DURATION:-120}"
SEEDS="${SEEDS:-12345}"
RUN_WIN="${RUN_WIN:-}"
RESULTS="$OUT_ROOT/results.tsv"
mkdir -p "$OUT_ROOT"
if [ -n "$RUN_WIN" ]; then RUNNER=(bash "$RUN_WIN" bash); else RUNNER=(bash); fi
if [ -z "${GODOT_BIN:-}" ]; then echo "Set GODOT_BIN." >&2; exit 2; fi

extract() { awk -v key="$2" 'index($0, key) { sub(/^[^=]*=[ ]*/, "", $0); print $0; exit }' "$1"; }

variant_env() {
	case "$1" in
		BASE_off) echo "BALLWAR_BULLET_COLLISION=0" ;;
		BASE_on) echo "BALLWAR_BULLET_COLLISION=1" ;;
		*) echo "" ;;
	esac
}

echo -e "variant\tseed\tend\tshots\tpierce\tshare_pct\tfirst_health\tfirst_destroy\tleads\tmax_share\treversal\tempty_pct\tlow_pct\tcells" > "$RESULTS"
for pierce in 3 5; do
	for mix in 10 25 50; do
		for collision in 0 1; do
			variant="P${pierce}_m${mix}_c${collision}"
			for seed in $SEEDS; do
				name="${variant}_s${seed}"
				env GODOT_BIN="$GODOT_BIN" OUT_ROOT="$OUT_ROOT" BALLWAR_MATCH_SEED="$seed" \
					BALLWAR_INITIAL_BALLS=2 BALLWAR_GATE_MULTIPLIER=3 \
					BALLWAR_BULLET_COLLISION="$collision" BALLWAR_PIERCE="$pierce" BALLWAR_MIX_PIERCING="$mix" \
					"${RUNNER[@]}" "$HERE/determinism_probe.sh" "$name" "$DURATION" >/dev/null 2>&1
				log=$(ls -d "$OUT_ROOT/$name".*/probe.log 2>/dev/null | head -1)
				if [ -z "$log" ] || ! grep -q -- "---- end ----" "$log" || grep -q "Cannot finish" "$log"; then
					echo -e "$variant\t$seed\tINVALID" >> "$RESULTS"
					continue
				fi
				end=$(extract "$log" "end_reason")
				shots=$(grep -E "spawned_total" "$log" | head -1 | sed -E 's/.*= ([0-9]+) by_type.*/\1/')
				pierce_count=$(grep -E "spawned_total" "$log" | head -1 | sed -E 's/.*\{ 0: [0-9]+, 2: ([0-9]+).*/\1/')
				if [ -z "$pierce_count" ]; then pierce_count=0; fi
				share=$(awk -v s="$shots" -v p="$pierce_count" 'BEGIN { if (s>0) printf "%.1f", 100*p/s; else print "0" }')
				health=$(extract "$log" "first_health_drop")
				destroy=$(extract "$log" "first_destroy")
				leads=$(extract "$log" "lead_changes")
				maxshare=$(extract "$log" "territory" | sed -E 's/.*max_share=([0-9.]+)%.*/\1/')
				reversal=$(extract "$log" "territory" | sed -E 's/.*max_reversal=([0-9.]+)pp.*/\1/')
				empty=$(extract "$log" "activity" | sed -E 's/.*empty_ticks=([0-9.]+)%.*/\1/')
				low=$(extract "$log" "activity" | sed -E 's/.*low10_ticks=([0-9.]+)%.*/\1/')
				cells=$(grep -E "^  blue=" "$log" | head -1 | sed 's/^  //')
				echo -e "$variant\t$seed\t$end\t$shots\t$pierce_count\t$share\t$health\t$destroy\t$leads\t$maxshare\t$reversal\t$empty\t$low\t$cells" >> "$RESULTS"
				echo "[p25b] $name done"
			done
		done
	done
done
# 纯普通弹基线（同样生产参数）
for collision in 0 1; do
	variant="BASE_c${collision}"
	for seed in $SEEDS; do
		name="${variant}_s${seed}"
		env GODOT_BIN="$GODOT_BIN" OUT_ROOT="$OUT_ROOT" BALLWAR_MATCH_SEED="$seed" \
			BALLWAR_INITIAL_BALLS=2 BALLWAR_GATE_MULTIPLIER=3 BALLWAR_BULLET_COLLISION="$collision" \
			"${RUNNER[@]}" "$HERE/determinism_probe.sh" "$name" "$DURATION" >/dev/null 2>&1
		log=$(ls -d "$OUT_ROOT/$name".*/probe.log 2>/dev/null | head -1)
		if [ -z "$log" ] || ! grep -q -- "---- end ----" "$log" || grep -q "Cannot finish" "$log"; then
			echo -e "$variant\t$seed\tINVALID" >> "$RESULTS"
			continue
		fi
		end=$(extract "$log" "end_reason")
		shots=$(grep -E "spawned_total" "$log" | head -1 | sed -E 's/.*= ([0-9]+) by_type.*/\1/')
		health=$(extract "$log" "first_health_drop")
		destroy=$(extract "$log" "first_destroy")
		leads=$(extract "$log" "lead_changes")
		maxshare=$(extract "$log" "territory" | sed -E 's/.*max_share=([0-9.]+)%.*/\1/')
		reversal=$(extract "$log" "territory" | sed -E 's/.*max_reversal=([0-9.]+)pp.*/\1/')
		empty=$(extract "$log" "activity" | sed -E 's/.*empty_ticks=([0-9.]+)%.*/\1/')
		low=$(extract "$log" "activity" | sed -E 's/.*low10_ticks=([0-9.]+)%.*/\1/')
		cells=$(grep -E "^  blue=" "$log" | head -1 | sed 's/^  //')
		echo -e "$variant\t$seed\t$end\t$shots\t0\t0\t$health\t$destroy\t$leads\t$maxshare\t$reversal\t$empty\t$low\t$cells" >> "$RESULTS"
		echo "[p25b] $name done"
	done
done
echo "[p25b] results: $RESULTS"
