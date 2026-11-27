#!/usr/bin/env bash
# Save / restore coordinate round trip across two window sizes.
#
# Process 1 starts a seeded match at SAVE_SIZE, plays to SAVE_AT seconds, writes
# state_before.json and saves to a probe slot. Process 2 starts at RESTORE_SIZE,
# continues that save, drains the restore queue in one frame, writes
# state_after.json and compares the two snapshots.
#
# Pass condition: every bullet's battlefield-LOCAL position matches within TOL px.
# A large GLOBAL delta is expected when the two sizes give the board a different
# origin or scale - it is reported as proof the comparison is not vacuous.
#
# Isolation: both processes run against a throwaway APPDATA, so the save file is
# written there and the player's real slots are never opened. Nothing is backed
# up or restored, because nothing real is touched.
#
# Note: this must NOT be wrapped in tools/run-win.sh - that wrapper hardcodes
# APPDATA for the trimmed-environment problem, which would drop the probe back
# into the real user directory. The project must already be imported.
#
# Usage:
#   tools/capture/run_save_restore_probe.sh
#   SAVE_SIZE=1120x720 RESTORE_SIZE=1920x1080 tools/capture/run_save_restore_probe.sh
#
# Exit codes: 0 pass, 4 local-coordinate mismatch, 5/6 probe could not run.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
	for candidate in \
		/d/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe \
		/c/Program\ Files/Godot/Godot_v4.7.1-stable_win64_console.exe; do
		[ -x "$candidate" ] && GODOT="$candidate" && break
	done
fi
if [ -z "$GODOT" ]; then
	echo "GODOT not found; set GODOT=/path/to/godot" >&2
	exit 2
fi

SAVE_SIZE="${SAVE_SIZE:-1024x768}"
RESTORE_SIZE="${RESTORE_SIZE:-1920x1080}"
SAVE_AT="${SAVE_AT:-15}"
TOL="${TOL:-0.5}"
SEED="${SEED:-424242}"
SLOT="${SLOT:-5}"

OUT="${OUT:-$(cd "$ROOT/.." && pwd)/art_captures/save_restore}"
mkdir -p "$OUT" || { echo "cannot create $OUT"; exit 5; }
LOG1="$OUT/run_save.log"
LOG2="$OUT/run_restore.log"

ISO="$(mktemp -d "${TMPDIR:-/tmp}/ballwar-probe-user-XXXXXX")"
cleanup() {
	if [ -n "${KEEP_ISO:-}" ]; then
		echo "-- isolated user dir kept at $ISO"
	else
		rm -rf "$ISO"
	fi
}
trap cleanup EXIT

echo "== probe: save @ $SAVE_SIZE (t=${SAVE_AT}s) -> restore @ $RESTORE_SIZE =="
echo "   out=$OUT  slot=$SLOT  tol=${TOL}px  seed=$SEED"
echo "   isolated APPDATA=$ISO"

run_phase() {
	local size="$1" phase="$2" log="$3"
	APPDATA="$ISO" \
	CAPTURE_OUT="$OUT" \
	CAPTURE_SAVE_RESTORE="$phase" \
	CAPTURE_SAVE_SLOT="$SLOT" \
	CAPTURE_SAVE_AT="$SAVE_AT" \
	CAPTURE_TOL="$TOL" \
	CAPTURE_SEED="$SEED" \
	CAPTURE_GRID=40 \
	CAPTURE_SECONDS=40 \
	CAPTURE_TIME_LIMIT=3 \
	"$GODOT" --path "$ROOT" --resolution "$size" \
		--script res://tools/capture/capture_battle.gd > "$log" 2>&1
	return $?
}

run_phase "$SAVE_SIZE" save "$LOG1"
rc1=$?
echo "-- phase save exit=$rc1 (log: $LOG1)"
grep -E "\[Probe\]|\[Capture\] ERROR" "$LOG1" | sed 's/^/   /'

if [ "$rc1" -ne 0 ]; then
	echo "RESULT: INCOMPLETE (save phase failed)"
	exit 5
fi

run_phase "$RESTORE_SIZE" restore "$LOG2"
rc2=$?
echo "-- phase restore exit=$rc2 (log: $LOG2)"
grep -E "\[Probe\]|\[Capture\] ERROR" "$LOG2" | sed 's/^/   /'

if [ "$rc2" -eq 4 ]; then
	echo "RESULT: FAIL - restored bullets do not line up with the battlefield"
	exit 4
fi
if [ "$rc2" -ne 0 ]; then
	echo "RESULT: INCOMPLETE (restore phase failed to run)"
	exit 5
fi
echo "RESULT: PASS - local positions match, see $OUT/save_restore_verdict.json"
exit 0
