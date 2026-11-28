#!/usr/bin/env bash
# M01-I2 收口：真实存档状态下的「继续游戏」页取证。
#
# 与 run_menu_capture.sh 的区别：那个脚本每档都开一个新的临时 APPDATA，
# 所以 continue 页永远是五个空槽。这里让所有进程共用同一个隔离 APPDATA，
# 由 capture_battle.gd 真跑对局写出合法存档，再由 capture_menu.gd 拍界面。
#
# 隔离：APPDATA 指向 mktemp 目录，玩家的真实存档从不被打开或覆盖。
#       CAPTURE_MODE 用英文别名，避免中文环境变量在 MSYS 下的编码问题。
#       阶段 [0/7] 会由 Godot 自己解析 user:// 并断言它落在该隔离目录内；
#       Linux/macOS 不认 APPDATA，若未另行设置对应隔离变量就会安全退出，
#       绝不会静默写进玩家真实存档。
#
# 五项验证：
#   1 全空槽位         -> continue_00_empty.png（且 ISO 内无 .save）
#   2 单个有效存档     -> continue_01_single.png（且 ISO 内恰好 1 个 .save）
#   3 合法存档能继续   -> restore 相位 exit 0 + 坐标比对判定文件
#   4 多个有效存档     -> continue_02_multi.png（且 ISO 内 >= 2 个 .save）
#   5 已选槽位详情     -> continue_03_selected.png（且日志有按钮点选记录）
#
# 用法：tools/capture/run_continue_capture.sh
#      KEEP_ISO=1 tools/capture/run_continue_capture.sh  (保留隔离目录供排查)
#
# 退出码：0 五项全过，非 0 表示某一阶段失败（日志在 $OUT/logs）。

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

# Windows 原生 exe 需要 Windows 形态路径；MSYS 才有 pwd -W / cygpath。
ROOT_RUN="$ROOT"
to_native() { printf '%s' "$1"; }
if command -v cygpath > /dev/null 2>&1; then
	ROOT_RUN="$(cd "$ROOT" && pwd -W)"
	to_native() { cygpath -w "$1"; }
fi

OUT="${OUT:-$(cd "$ROOT/.." && pwd)/art_captures/menu_continue}"
LOGS="$OUT/logs"
mkdir -p "$OUT" "$LOGS" || exit 2
OUT_NATIVE="$(to_native "$OUT")"

ISO="$(mktemp -d "${TMPDIR:-/tmp}/ballwar-continue-user-XXXXXX")"
ISO_NATIVE="$(to_native "$ISO")"
cleanup() {
	if [ -n "${KEEP_ISO:-}" ]; then
		echo "-- isolated user dir kept at $ISO"
	else
		rm -rf "$ISO"
	fi
}
trap cleanup EXIT

echo "out : $OUT"
echo "iso : $ISO_NATIVE  (throwaway APPDATA, real saves untouched)"

save_count() { find "$ISO" -type f -name 'ballwar_save_slot_*.save' 2>/dev/null | wc -l; }

# 用与采集进程完全相同的隔离环境启动 Godot，让它自己解析 user://。
# headless 只影响显示驱动，不改变 user:// 的解析规则。
run_user_dir_guard() {
	APPDATA="$ISO_NATIVE" PWD="$ROOT_RUN" MSYS2_ARG_CONV_EXCL='*' \
		CAPTURE_ISOLATED_ROOT="$ISO_NATIVE" \
		"$GODOT" --headless --audio-driver Dummy --path "$ROOT_RUN" \
		--script res://tools/capture/assert_user_dir_isolated.gd \
		> "$LOGS/user_dir_guard.log" 2>&1
	return $?
}

run_menu() {
	local tag="$1" select_slot="$2"
	APPDATA="$ISO_NATIVE" PWD="$ROOT_RUN" MSYS2_ARG_CONV_EXCL='*' \
		CAPTURE_OUT="$OUT_NATIVE" CAPTURE_TAG="$tag" CAPTURE_PAGES="continue" \
		CAPTURE_SELECT_SLOT="$select_slot" \
		"$GODOT" --path "$ROOT_RUN" --resolution 1120x720 \
		--script res://tools/capture/capture_menu.gd > "$LOGS/$tag.log" 2>&1
	return $?
}

run_battle() {
	local phase="$1" slot="$2" mode="$3" save_at="$4" tag="$5"
	APPDATA="$ISO_NATIVE" PWD="$ROOT_RUN" MSYS2_ARG_CONV_EXCL='*' \
		CAPTURE_OUT="$OUT_NATIVE" \
		CAPTURE_SAVE_RESTORE="$phase" CAPTURE_SAVE_SLOT="$slot" \
		CAPTURE_SAVE_AT="$save_at" CAPTURE_MODE="$mode" \
		CAPTURE_TOL="0.5" CAPTURE_SEED="424242" \
		CAPTURE_GRID=40 CAPTURE_SECONDS=40 CAPTURE_TIME_LIMIT=3 \
		"$GODOT" --path "$ROOT_RUN" --resolution 1120x720 \
		--script res://tools/capture/capture_battle.gd > "$LOGS/$tag.log" 2>&1
	return $?
}

fail=0
check() {
	local name="$1" ok="$2" detail="$3"
	if [ "$ok" = "1" ]; then
		printf 'VERIFY: PASS  %-26s %s\n' "$name" "$detail"
	else
		printf 'VERIFY: FAIL  %-26s %s\n' "$name" "$detail"
		fail=1
	fi
}

echo "[0/7] assert user:// is inside the isolated APPDATA (fail-fast)"
run_user_dir_guard
guard_rc=$?
grep -E "\[UserDirGuard\]" "$LOGS/user_dir_guard.log" | sed 's/^/   /'
if [ "$guard_rc" -ne 0 ]; then
	echo "RESULT: ABORT - user:// is not isolated; refusing to touch any save" >&2
	exit 3
fi

echo "[1/7] empty slots screenshot"
run_menu "continue_00_empty" "" || { echo "  menu capture FAILED"; fail=1; }
empty_count="$(save_count)"
[ "$empty_count" -eq 0 ] && ok=1 || ok=0
check "all slots empty" "$ok" "save files=$empty_count, shot=continue_00_empty_01_continue.png"

echo "[2/7] real match -> save slot 1 (basic, t=12s)"
run_battle "save" 1 "basic" 12 "battle_01_save_slot1" || { echo "  battle save FAILED"; fail=1; }
one_count="$(save_count)"
[ "$one_count" -eq 1 ] && ok=1 || ok=0
check "one valid save produced" "$ok" "save files=$one_count (must be 1)"
grep -E "\[Probe\] (save ok|save path|ERROR)" "$LOGS/battle_01_save_slot1.log" | sed 's/^/   /'

echo "[3/7] single-save screenshot"
run_menu "continue_01_single" "" || { echo "  menu capture FAILED"; fail=1; }
[ -f "$OUT/continue_01_single_01_continue.png" ] && ok=1 || ok=0
check "single save page captured" "$ok" "continue_01_single_01_continue.png"

echo "[4/7] real continue from slot 1 (restore phase + coordinate round trip)"
run_battle "restore" 1 "basic" 12 "battle_02_restore_slot1"
restore_rc=$?
grep -E "\[Probe\] (phase=restore|ERROR)|RESULT" "$LOGS/battle_02_restore_slot1.log" | sed 's/^/   /'
[ "$restore_rc" -eq 0 ] && [ -f "$OUT/save_restore_verdict.json" ] && ok=1 || ok=0
check "save actually continues" "$ok" "restore exit=$restore_rc, verdict=$( [ -f "$OUT/save_restore_verdict.json" ] && echo present || echo missing )"

echo "[5/7] second real match -> save slot 2 (occupation, t=18s)"
run_battle "save" 2 "occupation" 18 "battle_03_save_slot2" || { echo "  battle save FAILED"; fail=1; }
multi_count="$(save_count)"
[ "$multi_count" -ge 2 ] && ok=1 || ok=0
check "multiple valid saves" "$ok" "save files=$multi_count (must be >= 2)"
find "$ISO" -type f -name 'ballwar_save_slot_*.save' -printf '   %f  %s bytes\n' 2>/dev/null

echo "[6/7] multi-save screenshot"
run_menu "continue_02_multi" "" || { echo "  menu capture FAILED"; fail=1; }
[ -f "$OUT/continue_02_multi_01_continue.png" ] && ok=1 || ok=0
check "multi save page captured" "$ok" "continue_02_multi_01_continue.png"

echo "[7/7] selected-slot detail screenshot (real button click on slot 2, differs from default slot 1)"
run_menu "continue_03_selected" "2" || { echo "  menu capture FAILED"; fail=1; }
grep -q "\[MenuCapture\] selected save slot 2" "$LOGS/continue_03_selected.log" && ok=1 || ok=0
[ -f "$OUT/continue_03_selected_01_continue.png" ] || ok=0
check "selected slot detail" "$ok" "slot=2 clicked, shot=continue_03_selected_01_continue.png"

echo "----"
ls -1 "$OUT"/*.png 2>/dev/null | sed "s#^$OUT/##"
if [ "$fail" -ne 0 ]; then
	echo "RESULT: FAIL - see logs in $LOGS" >&2
	exit 1
fi
echo "RESULT: PASS - 1 isolation guard + 5 checks, 4 real-save-state screenshots, isolated APPDATA only"
