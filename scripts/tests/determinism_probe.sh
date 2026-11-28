#!/usr/bin/env bash
# determinism_probe.sh <label> [seconds] [detail_from] [detail_to]
# Verified with Git Bash and Godot 4.7.1 on Windows.
# Set GODOT_BIN to the Godot console executable. OUT_ROOT defaults to
# <repo>/../determinism_runs. Every invocation creates a fresh directory.
# Exit codes: Godot exit code, or 2 for invalid invocation/setup.
set -uo pipefail

LABEL="${1:-}"
SECS="${2:-15}"
DFROM="${3:-}"
DTO="${4:-}"

if [[ ! "$LABEL" =~ ^[A-Za-z0-9_-]+$ || -z "${GODOT_BIN:-}" ]]; then
  echo "Set GODOT_BIN and use a label containing only letters, digits, _ or -." >&2
  exit 2
fi

case "$(uname -s)" in
  MINGW*|MSYS*) ;;
  *) echo "Run this probe from Windows Git Bash." >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
PROJ="$(cd "$HERE/../.." && pwd)" || exit 2
OUT_ROOT="${OUT_ROOT:-$(cd "$PROJ/.." && pwd)/determinism_runs}"
mkdir -p -- "$OUT_ROOT" || exit 2
OUT="$(mktemp -d -- "$OUT_ROOT/$LABEL.XXXXXXXX")" || exit 2
APP_WIN="$(cd "$OUT" && pwd -W)" || exit 2
TOKEN="${OUT##*/}"
printf '%s' "$TOKEN" > "$OUT/.ballwar-probe" || exit 2

EXTRA=()
ARGS=()
if [[ "${BALLWAR_TEST_SPEED:-1}" != "1" ]]; then
  printf '%s' "$TOKEN" > "$OUT/.ballwar-dev-speed" || exit 2
  EXTRA+=("BALLWAR_DEV_TOKEN=$TOKEN")
  ARGS+=(-- --ballwar-dev-speed)
fi
if [[ -n "$DFROM" ]]; then
  EXTRA+=("BALLWAR_DETAIL_FROM=$DFROM" "BALLWAR_DETAIL_TO=${DTO:-$DFROM}")
fi

env \
  APPDATA="$APP_WIN" \
  BALLWAR_PROBE_TOKEN="$TOKEN" \
  BALLWAR_MATCH_SEED="${BALLWAR_MATCH_SEED:-12345}" \
  BALLWAR_MATCH_SECONDS="$SECS" \
  BALLWAR_TRACE_LABEL="$LABEL" \
  "${EXTRA[@]}" \
  "$GODOT_BIN" --headless --fixed-fps 60 \
    --path "$PROJ" --script res://scripts/tests/MatchBaselineRunner.gd "${ARGS[@]}" \
    > "$OUT/probe.log" 2>&1

rc=$?
echo "[determinism_probe] $LABEL exit=$rc"
echo "  log   : $OUT/probe.log"
echo "  trace : $OUT/Godot/app_userdata/*/trace_$LABEL.tsv"
exit "$rc"
