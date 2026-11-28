#!/usr/bin/env bash
# P2.6-A 出生点公平性：把阵营身份、出生位置、随机流身份、结算顺序拆开。
#
# 设计：F8 生产参数（初始球 2 + 倍率门 ×3），纯普通弹、互撞关闭、120s。
#   rotation   0..3     阵营占哪个角（位置变量）
#   stream_map  identity=随机流跟阵营；slot=随机流跟角落
#   order       forward / reverse（实体创建与结算顺序）
# 每个 (rotation, stream_map, order) × 10 个种子配对。
#
# 用法：
#   GODOT_BIN=/path/to/godot RUN_WIN=/path/to/run-iso.sh JOBS=8 \
#     bash scripts/tests/p26a_fairness.sh
# RUN_WIN 可选：未设置时直接调用 GODOT_BIN。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/p26a_fairness}"
DURATION="${DURATION:-120}"
SEEDS="${SEEDS:-30001 30002 30003 30004 30005 30006 30007 30008 30009 30010}"
ROTATIONS="${ROTATIONS:-0 1 2 3}"
STREAM_MAPS="${STREAM_MAPS:-identity slot}"
ORDERS="${ORDERS:-forward reverse}"
JOBS="${JOBS:-4}"
RUN_WIN="${RUN_WIN:-}"
RESULTS="$OUT_ROOT/results.tsv"
LINES="$OUT_ROOT/lines"
mkdir -p "$OUT_ROOT" "$LINES"
if [ -n "$RUN_WIN" ]; then RUNNER=(bash "$RUN_WIN" bash); else RUNNER=(bash); fi

if [ -z "${GODOT_BIN:-}" ]; then echo "Set GODOT_BIN." >&2; exit 2; fi
extract() { awk -v key="$2" 'index($0, key) { sub(/^[^=]*=[ ]*/, "", $0); print $0; exit }' "$1"; }

run_one() {
	local task="$1"
	IFS='|' read -r rotation stream_map order seed <<< "$task"
	local name="r${rotation}_${stream_map}_${order}_s${seed}"
	local order_env=""
	if [ "$order" = "reverse" ]; then order_env="BALLWAR_FACTION_ORDER=reverse"; fi
	env GODOT_BIN="$GODOT_BIN" OUT_ROOT="$OUT_ROOT" BALLWAR_MATCH_SEED="$seed" \
		BALLWAR_SPAWN_ROTATION="$rotation" BALLWAR_RNG_STREAM_MAP="$stream_map" \
		BALLWAR_INITIAL_BALLS=2 BALLWAR_GATE_MULTIPLIER=3 $order_env \
		"${RUNNER[@]}" "$HERE/determinism_probe.sh" "$name" "$DURATION" >/dev/null 2>&1
	local log
	log=$(ls -d "$OUT_ROOT/$name".*/probe.log 2>/dev/null | head -1)
	local line="$LINES/$name.tsv"
	if [ -z "$log" ] || ! grep -q -- "---- end ----" "$log" || grep -q "Cannot finish" "$log"; then
		printf '%s\t%s\t%s\t%s\tINVALID\n' "$rotation" "$stream_map" "$order" "$seed" > "$line"
		echo "[fair] $name INVALID"
		return
	fi
	local end cells leader slot maxshare reversal health destroy leads shots empty low10
	end=$(extract "$log" "end_reason")
	cells=$(grep -E "^  blue=" "$log" | head -1 | sed 's/^  //')
	leader=$(echo "$cells" | awk '{for(i=1;i<=4;i++){split($i,a,"="); if(a[2]+0>m){m=a[2]+0; n=i}}; print n-1}')
	slot=$(( (leader + rotation) % 4 ))
	maxshare=$(extract "$log" "territory" | sed -E 's/.*max_share=([0-9.]+)%.*/\1/')
	reversal=$(extract "$log" "territory" | sed -E 's/.*max_reversal=([0-9.]+)pp.*/\1/')
	health=$(extract "$log" "first_health_drop")
	destroy=$(extract "$log" "first_destroy")
	leads=$(extract "$log" "lead_changes")
	shots=$(grep -E "spawned_total" "$log" | head -1 | sed -E 's/.*= ([0-9]+) by_type.*/\1/')
	empty=$(extract "$log" "activity" | sed -E 's/.*empty_ticks=([0-9.]+)%.*/\1/')
	low10=$(extract "$log" "activity" | sed -E 's/.*low10_ticks=([0-9.]+)%.*/\1/')
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$rotation" "$stream_map" "$order" "$seed" "$end" "$shots" "$health" "$destroy" \
		"$leads" "$maxshare" "$reversal" "$empty" "$low10" "$cells" "$leader" "$slot" > "$line"
	echo "[fair] $name done"
}

if [ "${1:-}" = "--one" ]; then
	run_one "$2"
	exit $?
fi

: > "$RESULTS"
printf 'rotation\tstream_map\torder\tseed\tend\tshots\tfirst_health\tfirst_destroy\tleads\tmax_share\treversal\tempty_pct\tlow10_pct\tcells\tleader_faction\tleader_slot\n' > "$RESULTS"
for rotation in $ROTATIONS; do
	for stream_map in $STREAM_MAPS; do
		for order in $ORDERS; do
			for seed in $SEEDS; do
				echo "$rotation|$stream_map|$order|$seed"
			done
		done
	done
done > "$OUT_ROOT/tasks.txt"

xargs -P "$JOBS" -I{} bash "$0" --one "{}" < "$OUT_ROOT/tasks.txt"

cat "$LINES"/*.tsv 2>/dev/null | sort -t$'\t' -k1,1n -k2,2 -k3,3 -k4,4n >> "$RESULTS"
echo "[fair] results: $RESULTS"
