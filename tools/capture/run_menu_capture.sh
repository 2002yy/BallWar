#!/usr/bin/env bash
# 主菜单截图：三档产品画面 + 一档开发压力测试。
#
# 为什么要这几档：
#   1120×720 是设计画布，也是 project.godot 的基准分辨率；
#   1920×1080 走 canvas_items + expand，逻辑画布其实是 1280×720 再放大 1.5 倍，
#     这是玩家真会看到的画面，所以必须拍窗口而不是拍离屏；
#   3840×2160 用 SubViewport 离屏渲染，并以 size_2d_override 复现 canvas_items
#     缩放后的逻辑画布（1280×720），不需要一块 4K 显示器也能拍到真机画面。
#   3840×2160 native 只关掉逻辑画布压缩，是开发压力测试，不是产品画面。
#
# 用法：
#   tools/capture/run_menu_capture.sh
#   OUT=/some/dir tools/capture/run_menu_capture.sh
#
# 退出码：0 全部成功，非 0 表示某一档失败（日志在 $OUT/logs）。

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

OUT="${OUT:-$(cd "$ROOT/.." && pwd)/art_captures/menu}"
LOGS="$OUT/logs"
mkdir -p "$OUT" "$LOGS" || exit 2

# 原生 exe 需要 Windows 形态的路径；MSYS 才有 pwd -W / cygpath，CI 上保持原样。
ROOT_RUN="$ROOT"
to_native() { printf '%s' "$1"; }
if command -v cygpath > /dev/null 2>&1; then
	ROOT_RUN="$(cd "$ROOT" && pwd -W)"
	to_native() { cygpath -w "$1"; }
fi
OUT_NATIVE="$(to_native "$OUT")"

run_capture() {
	local tag="$1"
	local offscreen="$2"
	local canvas_mode="$3"
	local pages="$4"
	shift 4
	local log="$LOGS/${tag}.log"
	APPDATA="$(to_native "$(mktemp -d "${TMPDIR:-/tmp}/ballwar-capture-XXXXXX")")" \
		PWD="$ROOT_RUN" MSYS2_ARG_CONV_EXCL='*' \
		CAPTURE_OUT="$OUT_NATIVE" CAPTURE_TAG="$tag" CAPTURE_OFFSCREEN="$offscreen" \
		CAPTURE_2D_CANVAS="$canvas_mode" CAPTURE_PAGES="$pages" \
		"$GODOT" --path "$ROOT_RUN" --script res://tools/capture/capture_menu.gd "$@" \
		> "$log" 2>&1
	local status=$?
	if [ "$status" -ne 0 ]; then
		echo "  $tag  FAILED (exit=$status) log=$log"
		return "$status"
	fi
	echo "  $tag  ok"
	return 0
}

# 四页是用户裁定的验收截图；玩法说明是本轮新增的导航项，一起拍进去供复核。
ALL_PAGES="main,mode,config,help,continue"
fail=0
echo "out : $OUT"

echo "[1/4] 1120x720 windowed (design canvas)"
run_capture "1120x720" "" "" "$ALL_PAGES" --resolution 1120x720 || fail=1

echo "[2/4] 1920x1080 windowed (canvas_items expand -> 1280x720 logical)"
run_capture "1920x1080" "" "" "$ALL_PAGES" --resolution 1920x1080 || fail=1

echo "[3/4] 3840x2160 offscreen, real display path (canvas_items 3x)"
run_capture "3840x2160" "3840x2160" "" "$ALL_PAGES" --resolution 800x600 || fail=1

# [4/4] 仅开发压力测试：native 逻辑画布不属于产品布局要求，只验证不崩溃/不溢出。
# 结果图不用于美术验收；正式 4K 产品画面是 [3/4] 的 canvas_items 缩放路径。
echo "[4/4] 3840x2160 offscreen, native canvas stress (DEV ONLY, not a product layout)"
run_capture "3840x2160_native" "3840x2160" "native" "main" --resolution 800x600 || fail=1

echo "----"
ls -1 "$OUT"/*.png 2>/dev/null | sed "s#^$OUT/##"
[ "$fail" -eq 0 ] || { echo "some captures failed; logs in $LOGS" >&2; exit "$fail"; }
echo "all captures ok"
