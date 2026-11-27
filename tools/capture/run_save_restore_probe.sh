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
# Usage:
#   tools/capture/run_save_restore_probe.sh
#   SAVE_SIZE=1120x720 RESTORE_SIZE=1920x1080 tools/capture/run_save_restore_probe.sh
#
# Exit codes: 0 pass, 4 local-coordinate mismatch, 5/6 probe could not run.

set -u

GODOT="${GODOT:-/d/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe}"
RUN_WIN="${RUN_WIN:-/c/Users/Zhang/.workbuddy/tools/run-win.sh}"
SAVE_SIZE="${SAVE_SIZE:-1024x768}"
RESTORE_SIZE="${RESTORE_SIZE:-1920x1080}"
SAVE_AT="${SAVE_AT:-12}"
TOL="${TOL:-0.5}"
SEED="${SEED:-424242}"
SLOT="${SLOT:-5}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${OUT:-$(cd "$ROOT/.." && pwd)/art_captures/save_restore}"

mkdir -p "$OUT" || { echo "cannot create $OUT"; exit 5; }
LOG1="$OUT/run_save.log"
LOG2="$OUT/run_restore.log"

# The probe borrows one save slot, and save slots are player data: whatever was
# there before the run is put back afterwards, and if the slot was empty the
# probe's own file is moved out of the way instead of deleted.
USERDIR="${USERDIR:-$APPDATA/Godot/app_userdata/领土战争}"
SLOT_SAVE="$USERDIR/ballwar_save_slot_${SLOT}.save"
SLOT_BAK="${SLOT_SAVE}.bak"
BACKUP="$OUT/player_slot_backup"
HAD_SAVE=0
HAD_BAK=0
if [ -d "$USERDIR" ]; then
	mkdir -p "$BACKUP"
	if [ -f "$SLOT_SAVE" ]; then cp -p "$SLOT_SAVE" "$BACKUP/" && HAD_SAVE=1; fi
	if [ -f "$SLOT_BAK" ]; then cp -p "$SLOT_BAK" "$BACKUP/" && HAD_BAK=1; fi
else
	echo "WARN: $USERDIR not found, cannot protect slot $SLOT"
fi

restore_slot() {
	[ -d "$USERDIR" ] || return 0
	if [ "$HAD_SAVE" -eq 1 ]; then
		cp -p "$BACKUP/ballwar_save_slot_${SLOT}.save" "$SLOT_SAVE"
		echo "-- slot $SLOT restored from backup"
	else
		mkdir -p "$BACKUP/probe_wrote"
		[ -f "$SLOT_SAVE" ] && mv -f "$SLOT_SAVE" "$BACKUP/probe_wrote/" 
		echo "-- slot $SLOT was empty before the run; probe artifact moved to $BACKUP/probe_wrote"
	fi
	if [ "$HAD_BAK" -eq 1 ]; then
		cp -p "$BACKUP/ballwar_save_slot_${SLOT}.save.bak" "$SLOT_BAK"
	else
		[ -f "$SLOT_BAK" ] && mv -f "$SLOT_BAK" "$BACKUP/probe_wrote/"
	fi
	return 0
}
trap restore_slot EXIT

echo "== probe: save @ $SAVE_SIZE (t=${SAVE_AT}s) -> restore @ $RESTORE_SIZE =="
echo "   out=$OUT  slot=$SLOT  tol=${TOL}px  seed=$SEED"

run_phase() {
	local size="$1" phase="$2" log="$3"
	CAPTURE_OUT="$OUT" \
	CAPTURE_SAVE_RESTORE="$phase" \
	CAPTURE_SAVE_SLOT="$SLOT" \
	CAPTURE_SAVE_AT="$SAVE_AT" \
	CAPTURE_TOL="$TOL" \
	CAPTURE_SEED="$SEED" \
	CAPTURE_GRID=40 \
	CAPTURE_SECONDS=40 \
	CAPTURE_TIME_LIMIT=3 \
	"$RUN_WIN" "$GODOT" --path "$ROOT" --resolution "$size" \
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
