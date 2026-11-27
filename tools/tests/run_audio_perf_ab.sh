#!/usr/bin/env bash
# Audio on/off frame-time comparison on the same match.
#
# Why this is not a benchmark suite: the point is a single question - does the
# audio layer cost frames - and the honest answer includes the run-to-run spread
# of the same build. The script therefore repeats each arm and prints the spread
# next to the difference. If the difference is inside the spread, the verdict is
# "below noise", not "audio is free".
#
# Two things are fixed so the two arms see the same match: CAPTURE_SEED and the
# tick count. Both arms run the SAME build; only CAPTURE_AUDIO changes, because
# editing the code between runs would make the comparison meaningless.
#
# Requires a real window (a headless run has no rendered viewport) and vsync off
# (with vsync the renderer is pinned to the display refresh and both arms report
# the same frame time, which measures the cap and not the cost).
#
# Usage:
#   GODOT_BIN=/d/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe \
#     tools/tests/run_audio_perf_ab.sh [reps] [seconds]
#
# Exit: 0 on a completed comparison (including "below noise"), 2 on setup or run
# failure. This is a measurement, so a difference is not an error.

set -uo pipefail

REPS="${1:-3}"
SECS="${2:-20}"
SEED="${BALLWAR_MATCH_SEED:-12345}"

if [ -z "${GODOT_BIN:-}" ] || [ ! -x "${GODOT_BIN:-}" ]; then
	echo "Set GODOT_BIN to the Godot 4.7.1 console executable" >&2
	exit 2
fi
if ! [[ "$REPS" =~ ^[0-9]+$ ]] || [ "$REPS" -lt 2 ]; then
	echo "reps must be >= 2 (a spread needs at least two runs)" >&2
	exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
PROJ="$(cd "$HERE/../.." && pwd)" || exit 2
RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ballwar-audio-perf-XXXXXX")" || exit 2

echo "project : $PROJ"
echo "output  : $RUN_DIR"
echo "reps    : $REPS   seconds: $SECS   seed: $SEED"

run_one() {
	local arm="$1" rep="$2"
	local out="$RUN_DIR/${arm}_${rep}"
	local iso="$RUN_DIR/${arm}_${rep}_ud"
	mkdir -p -- "$out" "$iso" || return 1
	# A real driver, not Dummy: the Dummy driver has no output thread, so its
	# per-sound cost is not the same measurement.
	env APPDATA="$iso" \
		CAPTURE_OUT="$out" \
		CAPTURE_SHOTS="mid:${SECS}" \
		CAPTURE_SECONDS="$SECS" \
		CAPTURE_SEED="$SEED" \
		CAPTURE_GRID=40 \
		CAPTURE_TIME_LIMIT=1 \
		CAPTURE_PERF=1 \
		CAPTURE_NO_VSYNC=1 \
		CAPTURE_FILL_CHAMBERS=1 \
		CAPTURE_AUDIO="$arm" \
		"$GODOT_BIN" --path "$PROJ" --script res://tools/capture/capture_battle.gd \
		> "$RUN_DIR/${arm}_${rep}.log" 2>&1
	return $?
}

fail=0
for rep in $(seq 1 "$REPS"); do
	for arm in on off; do
		if run_one "$arm" "$rep"; then
			printf '%-4s rep%d ok\n' "$arm" "$rep"
		else
			printf '%-4s rep%d FAILED (see %s)\n' "$arm" "$rep" "$RUN_DIR/${arm}_${rep}.log"
			fail=1
		fi
	done
done

if [ "$fail" -ne 0 ]; then
	echo "----"
	echo "a capture failed; logs in $RUN_DIR"
	exit 2
fi

# json_num <file> <key>
json_num() {
	grep -o "\"$2\": *[-0-9.]*" "$1" | head -1 | sed 's/.*: *//'
}

echo "---- per-run frame times (ms) ----"
printf '%-8s %-10s %-10s %-10s %s\n' arm p50 p95 avg samples
for arm in on off; do
	for rep in $(seq 1 "$REPS"); do
		f="$RUN_DIR/${arm}_${rep}/perf.json"
		if [ ! -f "$f" ]; then
			echo "missing $f" >&2
			exit 2
		fi
		printf '%-8s %-10s %-10s %-10s %s\n' \
			"$arm/$rep" "$(json_num "$f" frame_ms_p50)" "$(json_num "$f" frame_ms_p95)" \
			"$(json_num "$f" frame_ms_avg)" "$(json_num "$f" samples)"
	done
done

# median <values...>
median() {
	printf '%s\n' "$@" | sort -g | awk '{a[NR]=$1} END { if (NR%2) print a[(NR+1)/2]; else print (a[NR/2]+a[NR/2+1])/2 }'
}

stats() {
	local arm="$1" key="$2" values=()
	for rep in $(seq 1 "$REPS"); do
		values+=("$(json_num "$RUN_DIR/${arm}_${rep}/perf.json" "$key")")
	done
	echo "$(median "${values[@]}") $(printf '%s\n' "${values[@]}" | sort -g | tail -1) $(printf '%s\n' "${values[@]}" | sort -g | head -1)"
}

echo "---- summary ----"
for key in frame_ms_p50 frame_ms_p95; do
	read -r on_med on_max on_min <<< "$(stats on "$key")"
	read -r off_med off_max off_min <<< "$(stats off "$key")"
	# Run-to-run spread of one build, taken as the widest of the two arms.
	spread=$(awk -v a="$on_max" -v b="$on_min" -v c="$off_max" -v d="$off_min" \
		'BEGIN { s=a-b; t=c-d; if (t>s) s=t; printf "%.4f", s }')
	delta=$(awk -v a="$on_med" -v b="$off_med" 'BEGIN { d=a-b; if (d<0) d=-d; printf "%.4f", d }')
	verdict=$(awk -v d="$delta" -v s="$spread" 'BEGIN { print (d<=s) ? "below run-to-run noise" : "OUTSIDE noise band" }')
	printf '%-13s audio_on=%-8s audio_off=%-8s delta=%-8s spread=%-8s %s\n' \
		"$key" "$on_med" "$off_med" "$delta" "$spread" "$verdict"
done

echo "----"
echo "raw captures : $RUN_DIR"
echo "NOTE: a 'below run-to-run noise' result means this measurement cannot resolve"
echo "      the audio cost, not that the cost is zero. tools/tests/audio_cost_probe.gd"
echo "      measures the per-sound cost directly for that reason."
exit 0
