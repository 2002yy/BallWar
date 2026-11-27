extends SceneTree

# 主菜单截图台。跑的是真 Main.tscn，菜单也是 Main 自己建的那一层
# （StartMenu.tscn），右侧预览是 PreviewScene 的实际节点。这里只负责
# 切页、等帧、截图、退出，不做任何重排或替身。
#
# 两种拍摄模式：
#
#   窗口模式（默认）—— 用 --resolution WxH 启动，截的是玩家真会看到的画面。
#   注意 project.godot 是 canvas_items + expand，所以 1920×1080 窗口下
#   逻辑画布只有 1280×720、按 1.5 倍放大。那是线上真实行为，不该在截图里改掉。
#
#   离屏模式（CAPTURE_OFFSCREEN=WxH）—— 把 Main 放进一个 WxH 的 SubViewport
#   里渲染，最后存成 WxH 的 PNG，不需要一块那么大的显示器。
#
#   离屏还分两种画布：
#     默认（模拟真机）—— 用 size_2d_override 把逻辑画布压回 canvas_items 拉伸
#       之后的尺寸（4K 上是 1280×720），和玩家在 4K 显示器上看到的一模一样。
#     CAPTURE_2D_CANVAS=native —— 不压，逻辑画布就是 WxH。这是压力测试：
#       布局要在 3840×2160 的逻辑画布下不塌，但它不是玩家会看到的画面。
#
# Environment:
#   CAPTURE_OUT        输出目录（默认 user://menu_captures）
#   CAPTURE_TAG        文件名前缀（默认 window）
#   CAPTURE_PAGES      逗号分隔的页面，默认 main,mode,config,continue
#   CAPTURE_OFFSCREEN  "WxH"，设了就走进离屏模式
#   CAPTURE_2D_CANVAS  "native" 关闭逻辑画布压缩（默认按 canvas_items 拉伸）
#   CAPTURE_DEBUG      "1" 打印状态栏几何，排布局问题时用
#
# Exit codes: 0 ok, 2 目录不可写, 3 拿不到图像

const MAIN_SCENE = preload("res://scenes/Main.tscn")

const PAGES := {
	"main": "main",
	"mode": "mode",
	"config": "config",
	"help": "help",
	"continue": "continue",
}

var _out_dir: String = ""
var _tag: String = "window"
var _pages: PackedStringArray = PackedStringArray()
var _offscreen_size: Vector2i = Vector2i.ZERO
var _menu = null
var _shot_index: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_out_dir = _env("CAPTURE_OUT", ProjectSettings.globalize_path("user://menu_captures"))
	_tag = _env("CAPTURE_TAG", "window")
	_pages = _env("CAPTURE_PAGES", "main,mode,config,continue").split(",", false)

	var offscreen: String = _env("CAPTURE_OFFSCREEN", "")
	if offscreen.contains("x"):
		var parts: PackedStringArray = offscreen.split("x")
		_offscreen_size = Vector2i(int(parts[0]), int(parts[1]))

	if DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		print("[MenuCapture] ERROR: cannot create %s" % _out_dir)
		quit(2)
		return

	print("[MenuCapture] out=%s tag=%s offscreen=%s window=%s" % [
		_out_dir, _tag, str(_offscreen_size), str(DisplayServer.window_get_size())
	])

	var viewport: Viewport = get_root()
	if _offscreen_size != Vector2i.ZERO:
		var sub := SubViewport.new()
		sub.name = "OffscreenCaptureViewport"
		sub.size = _offscreen_size
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if _env("CAPTURE_2D_CANVAS", "") != "native":
			# project.godot 是 canvas_items + expand：真机在 4K 上跑的是
			# 1280×720 的逻辑画布再放大 3 倍，不是 3840×2160 的逻辑画布。
			# 用 2D override 复现这一层，截出来的才是玩家会看到的画面。
			sub.size_2d_override = _canvas_items_logical_size(_offscreen_size)
			sub.size_2d_override_stretch = true
			print("[MenuCapture] logical canvas = %s (canvas_items expand)" % str(sub.size_2d_override))
		else:
			print("[MenuCapture] logical canvas = %s (native stress)" % str(sub.size))
		get_root().add_child(sub)
		viewport = sub

	var main = MAIN_SCENE.instantiate()
	main.name = "CaptureMain"
	viewport.add_child(main)

	# 让菜单完成入场、容器排一次版、预览场景画完第一帧。
	for i in 10:
		await process_frame

	_menu = main.menu_layer
	if _menu == null or not is_instance_valid(_menu):
		print("[MenuCapture] ERROR: Main did not create a start menu layer")
		quit(3)
		return

	for page_key in _pages:
		var key: String = str(page_key).strip_edges()
		if not PAGES.has(key):
			print("[MenuCapture] skip unknown page '%s'" % key)
			continue
		_menu.show_page(key)
		# 换页后容器要重排一次，Bracket/Label 的尺寸依赖排序结果。
		for i in 4:
			await process_frame
		if _env("CAPTURE_DEBUG", "") == "1":
			_dump_status_label()
		await _shot(viewport, key)

	print("[MenuCapture] done, %d shots" % _shot_index)
	quit(0)


func _shot(viewport: Viewport, page_key: String) -> void:
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = viewport.get_texture()
	if tex == null:
		print("[MenuCapture] ERROR: viewport has no texture (headless run?)")
		quit(3)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("[MenuCapture] ERROR: viewport image is null")
		quit(3)
		return
	_shot_index += 1
	var path: String = "%s/%s_%02d_%s.png" % [_out_dir, _tag, _shot_index, page_key]
	var err: int = img.save_png(path)
	if err != OK:
		print("[MenuCapture] ERROR: save_png(%s) -> %d" % [path, err])
		quit(3)
		return
	print("[MenuCapture] %s  %dx%d" % [path, img.get_width(), img.get_height()])


func _env(key: String, fallback: String) -> String:
	var value: String = OS.get_environment(key).strip_edges()
	return value if value != "" else fallback


# 复刻 project.godot 的 canvas_items + expand 算法：scale = min(W/1120, H/720)，
# 逻辑画布 = 像素尺寸 / scale。1120×720 上得 1120×720，4K 上得 1280×720。
func _canvas_items_logical_size(pixel_size: Vector2i) -> Vector2i:
	var scale: float = minf(float(pixel_size.x) / 1120.0, float(pixel_size.y) / 720.0)
	if scale <= 0.0:
		return pixel_size
	return Vector2i(int(round(float(pixel_size.x) / scale)), int(round(float(pixel_size.y) / scale)))


func _dump_status_label() -> void:
	var lbl: Label = _menu.get_node_or_null("%MenuStatusLabel")
	if lbl == null:
		print("[MenuCapture] debug: MenuStatusLabel missing")
		return
	print("[MenuCapture] debug: status text='%s' visible=%s global=%s font=%d" % [
		lbl.text, str(lbl.is_visible_in_tree()), str(lbl.get_global_rect()),
		lbl.get_theme_font_size("font_size")
	])
