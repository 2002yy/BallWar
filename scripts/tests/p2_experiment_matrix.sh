#!/usr/bin/env bash
# P2 特殊弹种实验矩阵：穿透弹 / 爆炸弹 × 互撞 × 火力密度。
#
# 用法：
#   GODOT_BIN=/d/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe \
#   FIRE=dense SEEDS="12345" bash scripts/tests/p2_experiment_matrix.sh
#
# FIRE=dense 走强制齐射（BALLWAR_EXPERIMENT_FIRE=1），natural 走控制仓自然火力。
# 结果写到 $OUT_ROOT/results_$FIRE.tsv，原始日志在 $OUT_ROOT/<run>/probe.log。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
RUN_WIN="${RUN_WIN:-/c/Users/Zhang/AppData/Local/Temp/bwaudit/run-iso.sh}"
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/p2_matrix}"
FIRE="${FIRE:-dense}"
DURATION="${DURATION:-120}"
SEEDS="${SEEDS:-12345}"
RESULTS="$OUT_ROOT/results_$FIRE.tsv"
mkdir -p "$OUT_ROOT"

if [ -z "${GODOT_BIN:-}" ]; then
	echo "Set GODOT_BIN to the Godot console executable." >&2
	exit 2
fi

FORCED=0
if [ "$FIRE" = "dense" ]; then FORCED=1; fi

extract() { # file key
	awk -v key="$2" 'index($0, key) { sub(/^[^=]*=[ ]*/, "", $0); print $0; exit }' "$1"
}

variant_env() {
	case "$1" in
		A_classic_off) echo "BALLWAR_BULLET_COLLISION=0" ;;
		B_classic_on) echo "BALLWAR_BULLET_COLLISION=1" ;;
		C_p5_m50_off) echo "BALLWAR_BULLET_COLLISION=0 BALLWAR_PIERCE=5 BALLWAR_MIX_PIERCING=50" ;;
		D_p5_m50_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_PIERCE=5 BALLWAR_MIX_PIERCING=50" ;;
		D_p3_m100_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_PIERCE=3 BALLWAR_MIX_PIERCING=100" ;;
		D_p5_m100_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_PIERCE=5 BALLWAR_MIX_PIERCING=100" ;;
		D_p10_m100_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_PIERCE=10 BALLWAR_MIX_PIERCING=100" ;;
		D_pinf_m100_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_PIERCE=-1 BALLWAR_MIX_PIERCING=100" ;;
		D_p5_m10_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_PIERCE=5 BALLWAR_MIX_PIERCING=10" ;;
		D_p5_m25_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_PIERCE=5 BALLWAR_MIX_PIERCING=25" ;;
		E_b1_m50_off) echo "BALLWAR_BULLET_COLLISION=0 BALLWAR_EXPLOSION_RADIUS=1 BALLWAR_MIX_EXPLOSIVE=50" ;;
		F_b1_m50_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_EXPLOSION_RADIUS=1 BALLWAR_MIX_EXPLOSIVE=50" ;;
		F_b2_m50_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_EXPLOSION_RADIUS=2 BALLWAR_MIX_EXPLOSIVE=50" ;;
		F_b3_m50_on) echo "BALLWAR_BULLET_COLLISION=1 BALLWAR_EXPLOSION_RADIUS=3 BALLWAR_MIX_EXPLOSIVE=50" ;;
		*) echo "" ;;
	esac
}

row_header="variant	seed	end	first_health	first_destroy	lead_changes	cells	hits	depth	active_p50	active_p95	pool_avg_ms	pool_max_ms	collision_avg_us	spawned"
echo "$row_header" > "$RESULTS"

for variant in A_classic_off B_classic_on C_p5_m50_off D_p5_m50_on D_p3_m100_on D_p5_m100_on D_p10_m100_on D_pinf_m100_on D_p5_m10_on D_p5_m25_on E_b1_m50_off F_b1_m50_on F_b2_m50_on F_b3_m50_on; do
	envs="$(variant_env "$variant")"
	for seed in $SEEDS; do
		name="${variant}_${FIRE}_s${seed}"
		env GODOT_BIN="$GODOT_BIN" OUT_ROOT="$OUT_ROOT" BALLWAR_MATCH_SEED="$seed" \
			BALLWAR_EXPERIMENT_FIRE="$FORCED" BALLWAR_TRACK_NEAR_MISS=1 \
			$envs \
			bash "$RUN_WIN" bash "$HERE/determinism_probe.sh" "$name" "$DURATION" >/dev/null 2>&1
		log=$(ls -d "$OUT_ROOT/$name".*/probe.log 2>/dev/null | head -1)
		if [ -z "$log" ] || [ ! -f "$log" ]; then
			echo -e "$variant\t$seed\tMISSING" >> "$RESULTS"
			continue
		fi
		end=$(extract "$log" "end_reason")
		health=$(extract "$log" "first_health_drop")
		destroy=$(extract "$log" "first_destroy")
		leads=$(extract "$log" "lead_changes")
		cells=$(grep -E "^  blue=" "$log" | head -1 | sed 's/^  //')
		hits=$(extract "$log" "totals" | sed -E 's/.*hits=([0-9]+).*/\1/')
		depth=$(extract "$log" "depth / blast" | sed -E 's/.*max_capture_depth=([0-9]+).*/\1/')
		p50=$(extract "$log" "active" | sed -E 's/.*p50=([0-9]+).*/\1/')
		p95=$(extract "$log" "active" | sed -E 's/.*p95=([0-9]+).*/\1/')
		step=$(extract "$log" "pool_step")
		step_avg=$(echo "$step" | sed -E 's/avg=([0-9.]+)ms.*/\1/')
		step_max=$(echo "$step" | sed -E 's/.*max=([0-9.]+)ms.*/\1/')
		coll=$(extract "$log" "collision_usec" | sed -E 's/avg=([0-9]+).*/\1/')
		spawned=$(extract "$log" "spawned_total")
		echo -e "$variant\t$seed\t$end\t$health\t$destroy\t$leads\t$cells\t$hits\t$depth\t$p50\t$p95\t$step_avg\t$step_max\t$coll\t$spawned" >> "$RESULTS"
		echo "[matrix] $name done"
	done
done
echo "[matrix] results: $RESULTS"
