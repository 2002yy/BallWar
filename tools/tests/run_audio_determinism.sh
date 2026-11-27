#!/usr/bin/env bash
# Audio on/off determinism comparison for A4.
#
# The question is NOT "is this build deterministic at every frame rate". The
# simulation still mixes wall-clock values into its update (issues #25 / #28 fix
# that and are not merged here), so a blanket determinism claim would be false.
# The question this script answers is narrower and answerable:
#
#   at a fixed tick rate and the same seed, does turning audio on change the
#   simulation trace at any tick?
#
# Three arms, because "audio off" is ambiguous:
#   on    - the shipped audio graph, playing for the whole match
#   off   - audio node alive but play() short-circuits (what a player gets by
#           muting; the presentation bus and its throttling still run)
#   none  - the audio node is freed before the match starts, so nothing is
#           subscribed to the presentation bus at all
#
# Comparisons:
#   on_a vs on_b       repeatability floor: if this diverges, no other result
#                      below means anything
#   on_a vs none_a     audio removed entirely
#   on_a vs off_a      audio muted
#   on_a vs seedctl    POSITIVE CONTROL. Different seed must diverge, otherwise
#                      the comparator is blind and every "match" above is luck.
#
# Also fails if the "on" arm never played a sound: an audio run that produced no
# audio would match the silent arms for the wrong reason.
#
# Usage:
#   GODOT_BIN=/d/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe \
#     tools/tests/run_audio_determinism.sh [seconds]
#
# Exit: 0 all comparisons as expected, 1 a comparison disagreed, 2 setup error.

set -uo pipefail

SECS="${1:-30}"
SEED="${BALLWAR_MATCH_SEED:-12345}"

if ! [[ "$SEED" =~ ^[0-9]+$ ]]; then
	echo "BALLWAR_MATCH_SEED must be a non-negative integer" >&2
	exit 2
fi
if [ -z "${GODOT_BIN:-}" ] || [ ! -x "${GODOT_BIN:-}" ]; then
	echo "Set GODOT_BIN to the Godot 4.7.1 console executable" >&2
	exit 2
fi

case "$(uname -s)" in
	MINGW*|MSYS*) ;;
	*) echo "Run this from Windows Git Bash (APPDATA isolation assumes it)" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
PROJ="$(cd "$HERE/../.." && pwd)" || exit 2
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/determinism_runs}"
mkdir -p -- "$OUT_ROOT" || exit 2
RUN_DIR="$(mktemp -d -- "$OUT_ROOT/audio-ab.XXXXXXXX")" || exit 2
COMPARE="$PROJ/scripts/tests/compare_traces.sh"

echo "project : $PROJ"
echo "output  : $RUN_DIR"
echo "seconds : $SECS   seed: $SEED"

# run_arm <label> <on|off|none> <seed>
run_arm() {
	local label="$1" arm="$2" seed_value="$3"
	local dir="$RUN_DIR/$label"
	mkdir -p -- "$dir" || return 1
	printf '%s' "$label" > "$dir/.ballwar-probe" || return 1
	local app_win
	app_win="$(cd "$dir" && pwd -W)" || return 1

	env \
		APPDATA="$app_win" \
		BALLWAR_PROBE_TOKEN="$label" \
		BALLWAR_MATCH_SEED="$seed_value" \
		BALLWAR_MATCH_SECONDS="$SECS" \
		BALLWAR_TRACE_LABEL="$label" \
		BALLWAR_AUDIO="$arm" \
		"$GODOT_BIN" --headless --fixed-fps 60 \
			--path "$PROJ" --script res://scripts/tests/MatchBaselineRunner.gd \
			> "$dir/probe.log" 2>&1
	local rc=$?
	printf '%-10s arm=%-5s seed=%-7s exit=%d\n' "$label" "$arm" "$seed_value" "$rc"
	return $rc
}

trace_of() {
	find "$RUN_DIR/$1/Godot/app_userdata" -name "trace_$1.tsv" -print 2>/dev/null | head -1
}

audio_total() {
	local json
	json="$(find "$RUN_DIR/$1/Godot/app_userdata" -name "audio_$1.json" -print 2>/dev/null | head -1)"
	[ -z "$json" ] && { echo "-1"; return; }
	local line
	line="$(grep -o '"played_total": *[0-9]*' "$json" | head -1)"
	echo "${line##*: }"
}

event_total() {
	local json
	json="$(find "$RUN_DIR/$1/Godot/app_userdata" -name "audio_$1.json" -print 2>/dev/null | head -1)"
	[ -z "$json" ] && { echo "-1"; return; }
	local line
	line="$(grep -o '"event_total": *[0-9]*' "$json" | head -1)"
	echo "${line##*: }"
}

fail=0
run_arm on_a   on   "$SEED"   || fail=1
run_arm on_b   on   "$SEED"   || fail=1
run_arm off_a  off  "$SEED"   || fail=1
run_arm none_a none "$SEED"   || fail=1
run_arm seedctl on "$((SEED + 1))" || fail=1

if [ "$fail" -ne 0 ]; then
	echo "----"
	echo "a run failed; logs in $RUN_DIR/*/probe.log"
	exit 2
fi

for label in on_a on_b off_a none_a seedctl; do
	t="$(trace_of "$label")"
	if [ -z "$t" ]; then
		echo "missing trace for $label" >&2
		exit 2
	fi
	printf '%s\t%s\n' "$label" "$t"
done > "$RUN_DIR/traces.txt"

declare -A TRACE
while IFS=$'\t' read -r label path; do
	TRACE["$label"]="$path"
done < "$RUN_DIR/traces.txt"

echo "---- audio actually ran? ----"
printf 'on_a   played=%s emitted=%s\n' "$(audio_total on_a)" "$(event_total on_a)"
printf 'off_a  played=%s emitted=%s\n' "$(audio_total off_a)" "$(event_total off_a)"
printf 'none_a played=%s emitted=%s\n' "$(audio_total none_a)" "$(event_total none_a)"

if [ "$(audio_total on_a)" -le 0 ]; then
	echo "FAIL: the 'on' arm played no sound, so it is not an audio run"
	fail=1
fi
if [ "$(audio_total off_a)" -ne 0 ] || [ "$(audio_total none_a)" -ne 0 ]; then
	echo "FAIL: a silent arm still played something; the arm switch is not effective"
	fail=1
fi
if [ "$(event_total on_a)" -le 0 ]; then
	echo "FAIL: the game emitted no presentation events; nothing was tested"
	fail=1
fi

echo "---- comparisons ----"
# expect_same <label-a> <label-b> <description>
expect_same() {
	local out
	out="$(bash "$COMPARE" "${TRACE[$1]}" "${TRACE[$2]}" 2>&1)"
	local rc=$?
	if [ "$rc" -eq 0 ]; then
		printf 'SAME  %-9s vs %-9s  %s\n' "$1" "$2" "$3"
	else
		printf 'DIFF  %-9s vs %-9s  %s\n      %s\n' "$1" "$2" "$3" "$out"
		fail=1
	fi
}

# expect_diff <label-a> <label-b> <description>
expect_diff() {
	local out
	out="$(bash "$COMPARE" "${TRACE[$1]}" "${TRACE[$2]}" 2>&1)"
	local rc=$?
	if [ "$rc" -eq 1 ]; then
		printf 'DIFF  %-9s vs %-9s  %s  (%s)\n' "$1" "$2" "$3" "$out"
	else
		printf 'SAME  %-9s vs %-9s  %s  -- CONTROL FAILED, comparator is blind\n' "$1" "$2" "$3"
		fail=1
	fi
}

expect_same on_a on_b    "repeatability floor, same build twice"
expect_same on_a none_a  "audio node removed entirely"
expect_same on_a off_a   "audio muted, event plumbing still live"
expect_diff on_a seedctl "control: different seed must diverge"

echo "----"
if [ "$fail" -eq 0 ]; then
	echo "RESULT PASS  audio changes no simulation tick"
else
	echo "RESULT FAIL  see $RUN_DIR"
fi
exit "$fail"
