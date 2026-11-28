#!/usr/bin/env bash
# P2.6-B 长局玩法筛选：生产候选 × 武器候选 × 300/600 秒。
#
# 生产：F2 四球 / F3 三倍门 / F7 双球+三倍门+快发 / F8 双球+三倍门
# 武器：纯普通 / 穿透3格25% / 穿透5格25% / 纯普通+互撞
# 指标：首座摧毁、实际 game_over、弹幕空窗、火力生产/兑换/发射/损失、性能。
#
# 用法：
#   GODOT_BIN=/path/to/godot RUN_WIN=/path/to/run-iso.sh JOBS=8 \
#     bash scripts/tests/p26b_long.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/p26b_long}"
DURATIONS="${DURATIONS:-300 600}"
SEEDS="${SEEDS:-40001 40002 40003}"
PRODUCTIONS="${PRODUCTIONS:-F2_balls4 F3_gate3 F7_combo F8_balls2_gate3}"
WEAPONS="${WEAPONS:-STD PIERCE3_25 PIERCE5_25 STD_COL}"
JOBS="${JOBS:-6}"
RUN_WIN="${RUN_WIN:-}"
RESULTS="$OUT_ROOT/results.tsv"
LINES="$OUT_ROOT/lines"
mkdir -p "$OUT_ROOT" "$LINES"
if [ -n "$RUN_WIN" ]; then RUNNER=(bash "$RUN_WIN" bash); else RUNNER=(bash); fi
if [ -z "${GODOT_BIN:-}" ]; then echo "Set GODOT_BIN." >&2; exit 2; fi

extract() { awk -v key="$2" 'index($0, key) { sub(/^[^=]*=[ ]*/, "", $0); print $0; exit }' "$1"; }

production_env() {
	case "$1" in
		F2_balls4) echo "BALLWAR_INITIAL_BALLS=4" ;;
		F3_gate3) echo "BALLWAR_GATE_MULTIPLIER=3" ;;
		F7_combo) echo "BALLWAR_INITIAL_BALLS=2 BALLWAR_GATE_MULTIPLIER=3 BALLWAR_BURST_INTERVAL_MULT=0.5" ;;
		F8_balls2_gate3) echo "BALLWAR_INITIAL_BALLS=2 BALLWAR_GATE_MULTIPLIER=3" ;;
		*) echo "" ;;
	esac
}

weapon_env() {
	case "$1" in
		STD) echo "" ;;
		PIERCE3_25) echo "BALLWAR_PIERCE=3 BALLWAR_MIX_PIERCING=25" ;;
		PIERCE5_25) echo "BALLWAR_PIERCE=5 BALLWAR_MIX_PIERCING=25" ;;
		STD_COL) echo "BALLWAR_BULLET_COLLISION=1" ;;
		*) echo "" ;;
	esac
}

run_one() {
	local task="$1"
	IFS='|' read -r production weapon duration seed <<< "$task"
	local name="${production}_${weapon}_${duration}s_s${seed}"
	local penv wen
	penv="$(production_env "$production")"
	wen="$(weapon_env "$weapon")"
	env GODOT_BIN="$GODOT_BIN" OUT_ROOT="$OUT_ROOT" BALLWAR_MATCH_SEED="$seed" \
		$penv $wen "${RUNNER[@]}" "$HERE/determinism_probe.sh" "$name" "$duration" >/dev/null 2>&1
	local log line="$LINES/$name.tsv"
	log=$(ls -d "$OUT_ROOT/$name".*/probe.log 2>/dev/null | head -1)
	if [ -z "$log" ] || ! grep -q -- "---- end ----" "$log" || grep -q "Cannot finish" "$log"; then
		printf '%s\t%s\t%s\t%s\tINVALID\n' "$production" "$weapon" "$duration" "$seed" > "$line"
		echo "[long] $name INVALID"
		return
	fi
	local end ticks shots pierce_count peak p95 health destroy leads maxshare reversal empty low10 cells leader
	end=$(extract "$log" "end_reason")
	ticks=$(extract "$log" "ticks")
	shots=$(grep -E "spawned_total" "$log" | head -1 | sed -E 's/.*= ([0-9]+) by_type.*/\1/')
	pierce_count=$(grep -E "spawned_total" "$log" | head -1 | sed -nE 's/.*2: ([0-9]+).*/\1/p')
	[ -z "$pierce_count" ] && pierce_count=0
	peak=$(extract "$log" "peak_active")
	p95=$(grep -E "^  active " "$log" | head -1 | sed -E 's/.*p95=([0-9]+).*/\1/')
	health=$(extract "$log" "first_health_drop")
	destroy=$(extract "$log" "first_destroy")
	leads=$(extract "$log" "lead_changes")
	maxshare=$(extract "$log" "territory" | sed -E 's/.*max_share=([0-9.]+)%.*/\1/')
	reversal=$(extract "$log" "territory" | sed -E 's/.*max_reversal=([0-9.]+)pp.*/\1/')
	empty=$(extract "$log" "activity" | sed -E 's/.*empty_ticks=([0-9.]+)%.*/\1/')
	low10=$(extract "$log" "activity" | sed -E 's/.*low10_ticks=([0-9.]+)%.*/\1/')
	cells=$(grep -E "^  blue=" "$log" | head -1 | sed 's/^  //')
	leader=$(echo "$cells" | awk '{for(i=1;i<=4;i++){split($i,a,"="); if(a[2]+0>m){m=a[2]+0; n=i}}; print n-1}')
	local converted fired pending lost remain hits pool_max
	converted=$(grep -E "^     ledger_units" "$log" | sed -nE 's/.*converted=([0-9]+).*/\1/p' | awk '{s+=$1} END {print s+0}')
	fired=$(grep -E "^     ledger_units" "$log" | sed -nE 's/.*fired=([0-9]+).*/\1/p' | awk '{s+=$1} END {print s+0}')
	pending=$(grep -E "^     ledger_units" "$log" | sed -nE 's/.*pending=([0-9]+).*/\1/p' | awk '{s+=$1} END {print s+0}')
	lost=$(grep -E "^     ledger_units" "$log" | sed -nE 's/.*lost=([0-9]+).*/\1/p' | awk '{s+=$1} END {print s+0}')
	remain=$(grep -E "^     ledger_units" "$log" | sed -nE 's/.*remain=([0-9]+).*/\1/p' | awk '{s+=$1} END {print s+0}')
	hits=$(extract "$log" "totals" | sed -E 's/.*hits=([0-9]+).*/\1/')
	pool_max=$(extract "$log" "pool_step" | sed -E 's/.*max=([0-9.]+)ms.*/\1/')
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$production" "$weapon" "$duration" "$seed" "$end" "$ticks" "$shots" "$pierce_count" "$peak" "$p95" \
		"$health" "$destroy" "$leads" "$maxshare" "$reversal" "$empty" "$low10" "$cells" "$leader" \
		"$converted" "$fired" "$pending" "$lost" > "$line"
	echo "[long] $name done"
	# 600s 轨迹很大；日志保留，轨迹删除。
	rm -f "$OUT_ROOT/$name".*/Godot/app_userdata/*/trace_*.tsv 2>/dev/null
}

if [ "${1:-}" = "--one" ]; then
	run_one "$2"
	exit $?
fi

printf 'production\tweapon\tduration\tseed\tend\tticks\tshots\tpierce_shots\tpeak\tp95\tfirst_health\tfirst_destroy\tleads\tmax_share\treversal\tempty_pct\tlow10_pct\tcells\tleader_faction\tconverted\tfired\tpending\tlost\n' > "$RESULTS"
for duration in $DURATIONS; do
	for production in $PRODUCTIONS; do
		for weapon in $WEAPONS; do
			for seed in $SEEDS; do
				echo "$production|$weapon|$duration|$seed"
			done
		done
	done
done > "$OUT_ROOT/tasks.txt"

xargs -P "$JOBS" -I{} bash "$0" --one "{}" < "$OUT_ROOT/tasks.txt"
cat "$LINES"/*.tsv 2>/dev/null | sort -t$'\t' -k3,3n -k1,1 -k2,2 -k4,4n >> "$RESULTS"
echo "[long] results: $RESULTS"
