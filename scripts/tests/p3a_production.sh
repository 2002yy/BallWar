#!/usr/bin/env bash
# P3 生产/发射解耦实验：A 完全锁定 / B 发射期积累 / C 额外一批缓存。
# 第一轮只跑普通弹、互撞关闭，隔离生产与发射机制。
#
# 用法：
#   GODOT_BIN=... RUN_WIN=... JOBS=6 bash scripts/tests/p3a_production.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/p3a_production}"
DURATION="${DURATION:-300}"
SEEDS="${SEEDS:-50001 50002 50003}"
PRODUCTIONS="${PRODUCTIONS:-F2_balls4 F3_gate3 F7_combo F8_balls2_gate3}"
MODES="${MODES:-locked accumulate extra_batch}"
JOBS="${JOBS:-4}"
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

run_one() {
	local task="$1"
	IFS='|' read -r production mode seed <<< "$task"
	local name="${production}_${mode}_s${seed}"
	local penv; penv="$(production_env "$production")"
	env GODOT_BIN="$GODOT_BIN" OUT_ROOT="$OUT_ROOT" BALLWAR_MATCH_SEED="$seed" \
		BALLWAR_PRODUCTION_MODE="$mode" $penv \
		"${RUNNER[@]}" "$HERE/determinism_probe.sh" "$name" "$DURATION" >/dev/null 2>&1
	local log line="$LINES/$name.tsv"
	log=$(ls -d "$OUT_ROOT/$name".*/probe.log 2>/dev/null | head -1)
	if [ -z "$log" ] || ! grep -q -- "---- end ----" "$log" || grep -q "Cannot finish" "$log"; then
		printf '%s\t%s\t%s\tINVALID\n' "$production" "$mode" "$seed" > "$line"
		echo "[p3] $name INVALID"
		return
	fi
	local end shots peak p50 p95 empty low10 low30 low50 le li l30 l50 health destroy leads maxshare rev cells leader
	end=$(extract "$log" "end_reason")
	shots=$(grep -E "spawned_total" "$log" | head -1 | sed -E 's/.*= ([0-9]+) by_type.*/\1/')
	active_line=$(grep -E '^  active ' "$log" | head -1)
	peak=$(echo "$active_line" | sed -E 's/.*peak=([0-9]+).*/\1/')
	p50=$(echo "$active_line" | sed -E 's/.*p50=([0-9]+).*/\1/')
	p95=$(echo "$active_line" | sed -E 's/.*p95=([0-9]+).*/\1/')
	empty=$(extract "$log" "activity" | sed -E 's/.*empty_ticks=([0-9.]+)%.*/\1/')
	low10=$(extract "$log" "activity" | sed -E 's/.*low10_ticks=([0-9.]+)%.*/\1/')
	low30=$(extract "$log" "activity" | sed -E 's/.*low30_ticks=([0-9.]+)%.*/\1/')
	low50=$(extract "$log" "activity" | sed -E 's/.*low50_ticks=([0-9.]+)%.*/\1/')
	le=$(extract "$log" "longest" | sed -E 's/.*empty=([0-9.]+)s.*/\1/')
	li=$(extract "$log" "longest" | sed -E 's/.*low10=([0-9.]+)s.*/\1/')
	l30=$(extract "$log" "longest" | sed -E 's/.*low30=([0-9.]+)s.*/\1/')
	l50=$(extract "$log" "longest" | sed -E 's/.*low50=([0-9.]+)s.*/\1/')
	health=$(extract "$log" "first_health_drop")
	destroy=$(extract "$log" "first_destroy")
	leads=$(extract "$log" "lead_changes")
	maxshare=$(extract "$log" "territory" | sed -E 's/.*max_share=([0-9.]+)%.*/\1/')
	rev=$(extract "$log" "territory" | sed -E 's/.*max_reversal=([0-9.]+)pp.*/\1/')
	cells=$(grep -E "^  blue=" "$log" | head -1 | sed 's/^  //')
	leader=$(echo "$cells" | awk '{for(i=1;i<=4;i++){split($i,a,"="); if(a[2]+0>m){m=a[2]+0; n=i}}; print n-1}')
	local released releases queued overflow accumulated
	released=$(grep -E "^  f[0-9] mode=" "$log" | sed -E 's/.* fire=([0-9]+).*/\1/' | awk '{s+=$1} END {print s+0}')
	releases=$(grep -E "^  f[0-9] mode=" "$log" | sed -E 's/.* releases=([0-9]+).*/\1/' | awk '{s+=$1} END {print s+0}')
	queued=$(grep -E "^  f[0-9] mode=" "$log" | sed -E 's/.* queued_fire=([0-9]+).*/\1/' | awk '{s+=$1} END {print s+0}')
	overflow=$(grep -E "^  f[0-9] mode=" "$log" | sed -E 's/.* overflow=([0-9]+).*/\1/' | awk '{s+=$1} END {print s+0}')
	accumulated=$(grep -E "^  f[0-9] mode=" "$log" | sed -E 's/.* accumulated=([0-9]+).*/\1/' | awk '{s+=$1} END {print s+0}')
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$production" "$mode" "$seed" "$end" "$shots" "$peak" "$p50" "$p95" "$empty" "$low10" "$low30" "$low50" \
		"$le" "$li" "$l30" "$l50" "$health" "$destroy" "$leads" "$maxshare" "$rev" "$cells" "$leader" \
		"$released" "$releases" "$queued" "$overflow" "$accumulated" > "$line"
	echo "[p3] $name done"
	rm -f "$OUT_ROOT/$name".*/Godot/app_userdata/*/trace_*.tsv 2>/dev/null
}

if [ "${1:-}" = "--one" ]; then run_one "$2"; exit $?; fi

printf 'production\tmode\tseed\tend\tshots\tpeak\tp50\tp95\tempty\tlow10\tlow30\tlow50\tlongest_empty\tlongest_l10\tlongest_l30\tlongest_l50\tfirst_health\tfirst_destroy\tleads\tmax_share\treversal\tcells\tleader\treleased_fire\treleases\tqueued_fire\toverflow\taccumulated\n' > "$RESULTS"
for production in $PRODUCTIONS; do
	for mode in $MODES; do
		for seed in $SEEDS; do
			echo "$production|$mode|$seed"
		done
	done
done > "$OUT_ROOT/tasks.txt"
xargs -P "$JOBS" -I{} bash "$0" --one "{}" < "$OUT_ROOT/tasks.txt"
cat "$LINES"/*.tsv 2>/dev/null | sort -t$'\t' -k1,1 -k2,2 -k3,3n >> "$RESULTS"
echo "[p3] results: $RESULTS"
