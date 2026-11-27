#!/usr/bin/env bash
# determinism_probe.sh <label> [seconds] [detail_from] [detail_to]
#
# Runs one headless match with a fixed seed and writes a per-tick trace to an
# isolated user:// root, so two runs cannot share menu_preferences.json or a
# save slot. Companion to scripts/tests/MatchBaselineRunner.gd; see
# docs/technical/DETERMINISM_STAGE0A.md for what the trace columns mean.
#
# Required:
#   GODOT_BIN   path to the Godot console executable
#
# Optional:
#   BALLWAR_MATCH_SEED   default 12345
#   OUT_ROOT             default <repo>/../determinism_runs   (keep out of the tree)
#   ISO_APPDATA_WIN      Windows-style path used as APPDATA for this run. Set
#                        automatically; override only if you know why.
#
# Why APPDATA is isolated: Main._load_menu_preferences() can override the grid
# size / quality / mode passed on the command line (Main.gd:92-103, 487-508),
# so a leftover preferences file silently invalidates an experiment.
#
# Exit: propagates the probe's exit code (0 ok, 2 config mismatch, 3 no
# battlefield, 4 trace write failed).

set -uo pipefail

LABEL="${1:?usage: determinism_probe.sh <label> [seconds] [detail_from] [detail_to]}"
SECS="${2:-15}"
DFROM="${3:-}"
DTO="${4:-}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/determinism_runs}"
OUT="$OUT_ROOT/$LABEL"

if [[ -z "${GODOT_BIN:-}" ]]; then
  echo "determinism_probe.sh: set GODOT_BIN to the Godot console executable" >&2
  echo "  e.g. export GODOT_BIN=/d/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe" >&2
  exit 2
fi

rm -rf "$OUT"
mkdir -p "$OUT"

EXTRA=()
if [[ -n "$DFROM" ]]; then
  EXTRA+=("BALLWAR_DETAIL_FROM=$DFROM")
  EXTRA+=("BALLWAR_DETAIL_TO=${DTO:-$DFROM}")
fi

# Godot writes user:// under APPDATA on Windows, so APPDATA must be a Windows
# path even when this shell is POSIX.
APP_WIN="${ISO_APPDATA_WIN:-$(cd "$OUT" && pwd -W 2>/dev/null | sed 's|/|\\|g')}"

env \
  APPDATA="$APP_WIN" \
  BALLWAR_MATCH_SEED="${BALLWAR_MATCH_SEED:-12345}" \
  BALLWAR_MATCH_SECONDS="$SECS" \
  BALLWAR_TRACE_LABEL="$LABEL" \
  "${EXTRA[@]+"${EXTRA[@]}"}" \
  "$GODOT_BIN" --headless --fixed-fps 60 \
    --path "$PROJ" --script res://scripts/tests/MatchBaselineRunner.gd \
    > "$OUT_ROOT/$LABEL.log" 2>&1

rc=$?
echo "[determinism_probe] $LABEL exit=$rc"
echo "  log   : $OUT_ROOT/$LABEL.log"
echo "  trace : $OUT/Godot/app_userdata/*/trace_$LABEL.tsv"
exit $rc
