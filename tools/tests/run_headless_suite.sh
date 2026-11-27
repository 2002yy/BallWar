#!/usr/bin/env bash
# Run the headless runner suite locally the way CI runs it, but with a throwaway
# user-data directory per script instead of the player's real one.
#
# Why not just back up and restore the real slot files: a test that can only be
# run by moving the player's saves around is a test nobody will run. On Windows
# Godot resolves user:// from APPDATA, so pointing APPDATA at a temp directory
# isolates every write - settings, saves, logs - with no cleanup step that can
# be forgotten and no risk of clobbering a real slot.
#
# Note: do NOT wrap this in tools/run-win.sh. That wrapper hardcodes APPDATA for
# the trimmed-environment problem, which would put the runs back into the real
# user directory. A direct launch is enough here because the project is already
# imported (the wrapper is only needed for the first import).
#
# Usage:
#   tools/tests/run_headless_suite.sh
#   GODOT=/path/to/godot tools/tests/run_headless_suite.sh SmokeTestRunner
#
# Exit code: 0 only if every runner passed.

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
if [ -z "$GODOT" ] && command -v godot > /dev/null 2>&1; then
	GODOT="$(command -v godot)"
fi
if [ -z "$GODOT" ]; then
	echo "GODOT not found; set GODOT=/path/to/godot" >&2
	exit 2
fi

DEFAULT_RUNNERS=(
	SmokeTestRunner
	StartMenuSceneTestRunner
	GameHUDSceneTestRunner
	EventRouletteSceneTestRunner
	SettingsPanelSceneTestRunner
	GameStateCoordinatorTestRunner
	SaveFlowControllerTestRunner
	RestorePlanTestRunner
	IntegrationTestRunner
	LayoutSanityTestRunner
	SettingsAndResultTestRunner
	EndToEndContinueMainTestRunner
	BoardCoordinatesTestRunner
	AudioIsolationTestRunner
)

if [ "$#" -gt 0 ]; then
	RUNNERS=("$@")
else
	RUNNERS=("${DEFAULT_RUNNERS[@]}")
fi

LOGS="$(mktemp -d "${TMPDIR:-/tmp}/ballwar-runner-logs-XXXXXX")"
echo "godot : $GODOT"
echo "logs  : $LOGS"

fail=0
for script in "${RUNNERS[@]}"; do
	iso="$(mktemp -d "${TMPDIR:-/tmp}/ballwar-user-XXXXXX")"
	log="$LOGS/${script}.log"
	APPDATA="$iso" "$GODOT" --headless --audio-driver Dummy --path "$ROOT" \
		--script "res://scripts/tests/${script}.gd" > "$log" 2>&1
	status=$?
	mark=""
	if grep -Eq "SCRIPT ERROR|^ERROR:|FAIL" "$log"; then
		mark="ERR-OR-FAIL"
		status=1
	elif grep -q "PASS" "$log"; then
		mark="PASS"
	fi
	printf "%-34s exit=%d %s\n" "$script" "$status" "$mark"
	rm -rf "$iso"
	[ "$status" -ne 0 ] && fail=1
done

echo "----"
if [ "$fail" -eq 0 ]; then
	echo "all runners passed"
else
	echo "some runners failed; logs kept in $LOGS"
fi
exit "$fail"
