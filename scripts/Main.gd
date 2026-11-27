extends Node2D

# Main orchestration boundary:
# Allowed here:
# - create runtime systems
# - connect signals
# - switch top-level game/menu/pause states
# - delegate to coordinators/controllers/views
# Do not add here:
# - concrete physics behavior
# - concrete draw behavior
# - deep save-field repair
# - specific event effect implementation

const VIEW_W: float = 1120.0
const VIEW_H: float = 720.0

# The layout system below already takes a viewport size everywhere; it was
# simply always handed the 1120x720 design canvas. With stretch mode
# canvas_items + aspect expand the real logical canvas is wider than 1120 on
# any 16:9 window (1280x720 at 1920x1080), so the board stayed centred in a
# 1120 strip and the extra width rendered as empty background.
var _view_size: Vector2 = Vector2(VIEW_W, VIEW_H)


func _resolve_view_size() -> Vector2:
	var real_size: Vector2 = get_viewport_rect().size
	# Never go below the design canvas: the profiles are hand-tuned in absolute
	# pixels and smaller canvases would make panels overlap.
	return Vector2(maxf(VIEW_W, real_size.x), maxf(VIEW_H, real_size.y))


# The board is laid out in a viewport-independent design space and then placed by
# a single uniform transform. Simulation coordinates, cell size, bullet speed and
# collision radii are untouched: only the display transform changes, so a bigger
# screen shows the same match, bigger.
const BOARD_SPACE: Vector2 = Vector2(VIEW_W, VIEW_H)
const BOARD_TOP_RESERVE: float = 100.0
const BOARD_BOTTOM_RESERVE: float = 62.0
const BOARD_SIDE_PAD: float = 10.0

const BoardChassisScript = preload("res://scripts/render/BoardChassis.gd")
const ArtStyleScript = preload("res://scripts/render/ArtStyle.gd")
const AudioManagerScript = preload("res://scripts/AudioManager.gd")
const PresentationEventsScript = preload("res://scripts/presentation/PresentationEvents.gd")

var board_root: CanvasLayer = null
var board_chassis: Node2D = null
var audio_manager = null
# Single fan-out point from simulation to presentation. Audio subscribes today;
# effects and HUD feedback will subscribe to the same object rather than digging
# into Turret/ControlChamber state.
var presentation_events = null
var _board_layout: Dictionary = {}


func _board_avail_rect(view: Vector2) -> Rect2:
	var top: float = BOARD_TOP_RESERVE
	var bottom: float = maxf(top + 120.0, view.y - BOARD_BOTTOM_RESERVE)
	return Rect2(Vector2(BOARD_SIDE_PAD, top), Vector2(maxf(320.0, view.x - BOARD_SIDE_PAD * 2.0), bottom - top))


# Bounding box of everything that belongs to the board: battlefield, the four
# chambers and the add-ball buttons. Derived from the real layout, so it stays
# correct for every grid size instead of assuming the 40x40 numbers.
func _board_content_rect(layout: Dictionary) -> Rect2:
	var bf: Rect2 = layout.get("battlefield_rect", Rect2())
	var chamber_size: Vector2 = layout.get("chamber_size", Vector2.ZERO)
	var button_size: Vector2 = layout.get("add_ball_button_size", Vector2.ZERO)
	var lo: Vector2 = bf.position
	var hi: Vector2 = bf.end
	for pos in layout.get("chamber_positions", {}).values():
		lo = Vector2(minf(lo.x, pos.x), minf(lo.y, pos.y))
		hi = Vector2(maxf(hi.x, pos.x + chamber_size.x), maxf(hi.y, pos.y + chamber_size.y))
	for pos in layout.get("add_ball_button_positions", {}).values():
		lo = Vector2(minf(lo.x, pos.x), minf(lo.y, pos.y))
		hi = Vector2(maxf(hi.x, pos.x + button_size.x), maxf(hi.y, pos.y + button_size.y))
	return Rect2(lo, hi - lo)


func _fit_scale(avail: Rect2, content: Rect2) -> float:
	if content.size.x <= 1.0 or content.size.y <= 1.0:
		return 1.0
	return minf(avail.size.x / content.size.x, avail.size.y / content.size.y)


# Scale 1.0 is defined as "the design canvas", so 1120x720 keeps its exact
# hand-tuned look and every other viewport grows from there.
func _board_transform(layout: Dictionary = {}) -> Transform2D:
	var src: Dictionary = layout if not layout.is_empty() else _board_layout
	var content: Rect2 = _board_content_rect(src)
	var base: float = _fit_scale(_board_avail_rect(BOARD_SPACE), content)
	var raw: float = _fit_scale(_board_avail_rect(_view_size), content)
	var s: float = 1.0 if base <= 0.0 else clampf(raw / base, 1.0, 1.45)
	# Test-only override, used by the display-scale invariance regression.
	var forced: String = OS.get_environment("BALLWAR_BOARD_SCALE").strip_edges()
	if forced != "":
		s = clampf(float(forced), 0.5, 3.0)
	var avail: Rect2 = _board_avail_rect(_view_size)
	var origin: Vector2 = avail.position + (avail.size - content.size * s) * 0.5 - content.position * s
	return Transform2D(0.0, Vector2(s, s), 0.0, origin)


func _board_screen_rect() -> Rect2:
	var xf: Transform2D = _board_transform()
	var bf: Rect2 = _board_layout.get("battlefield_rect", Rect2())
	return Rect2(xf * bf.position, bf.size * xf.get_scale().x)


func _chamber_screen_rects() -> Array:
	var xf: Transform2D = _board_transform()
	var out: Array = []
	var size: Vector2 = _board_layout.get("chamber_size", Vector2.ZERO)
	for pos in _board_layout.get("chamber_positions", {}).values():
		out.append(Rect2(xf * pos, size * xf.get_scale().x))
	return out


func _apply_board_transform() -> void:
	if board_root == null or not is_instance_valid(board_root):
		return
	var xf: Transform2D = _board_transform()
	board_root.transform = xf
const LEGACY_SAVE_PATH: String = "user://ballwar_save.json"
const LEGACY_SLOT_SAVE_PATH_TEMPLATE: String = "user://ballwar_save_slot_%d.json"
const SAVE_PATH_TEMPLATE: String = "user://ballwar_save_slot_%d.save"
const SAVE_SLOT_COUNT: int = 5
const MENU_PREF_PATH: String = "user://menu_preferences.json"
const GameRuntimeContextScript = preload("res://scripts/GameRuntimeContext.gd")
const BulletRestoreQueueScript = preload("res://scripts/BulletRestoreQueue.gd")
const StartMenuScene = preload("res://scenes/ui/StartMenu.tscn")
const GameHUDScene = preload("res://scenes/ui/GameHUD.tscn")
const EventRouletteScene = preload("res://scenes/ui/EventRouletteView.tscn")

var runtime = GameRuntimeContextScript.new()
var current_score_counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
var is_mobile_layout: bool = false
var player_settings: Dictionary = {}

var menu_layer
var game_layer
var selected_grid_size: int = 40
var selected_palette_name: String = "默认随机"
var selected_quality_name: String = GameConfig.QUALITY_MEDIUM
var selected_game_mode_name: String = GameConfig.GAME_MODE_BASIC
var selected_time_limit_minutes: int = GameConfig.DEFAULT_TIMED_MODE_MINUTES
var selected_save_slot: int = 1
var game_elapsed_time: float = 0.0
var is_game_over: bool = false

# Negative keeps the historical behavior (time-based randomization).
# A non-negative value seeds the global RNG so a match can be replayed.
var match_seed: int = -1

var menu_title_label
var menu_start_button
var menu_continue_button
var menu_status_label
var pending_menu_status_message: String = ""
var ui_time: float = 0.0
var chamber_scale: float = 1.0
var bullet_restore_queue = BulletRestoreQueueScript.new()
var perf_debug_update_timer: float = 0.0
var hud_meta_update_timer: float = 0.0
const PERF_DEBUG_UPDATE_INTERVAL: float = 0.25
const HUD_META_UPDATE_INTERVAL: float = 0.25

func _runtime_grid_size() -> int:
	return int(runtime.current_config.get("grid_size", selected_grid_size))

func _hud_ref(key: String, default_value = null):
	return runtime.hud_ref(key, default_value)

func _set_hud_ref(key: String, value) -> void:
	runtime.set_hud_ref(key, value)

func _ui_runtime_ref(key: String, default_value = null):
	return runtime.ui_runtime_ref(key, default_value)

func _set_ui_runtime_ref(key: String, value) -> void:
	runtime.set_ui_runtime_ref(key, value)

func _build_runtime_layout(grid_size: int) -> Dictionary:
	var layout: Dictionary = LayoutProfiles.get_profile(grid_size).duplicate(true)
	layout.merge(LayoutCoordinator.calculate_layout(grid_size, _view_size, is_mobile_layout), true)
	# Add-ball buttons live on a CanvasLayer, so they are not affected by
	# board_root's transform; feed them the already-transformed positions or they
	# would drift away from the chambers once the board is scaled.
	if not _board_layout.is_empty():
		var xf: Transform2D = _board_transform(_board_layout)
		var moved := {}
		for fid in _board_layout.get("add_ball_button_positions", {}).keys():
			moved[fid] = xf * Vector2(_board_layout["add_ball_button_positions"][fid])
		layout["add_ball_button_positions"] = moved
		layout["add_ball_positions"] = moved
	return layout


func _build_board_layout(grid_size: int) -> Dictionary:
	# Deliberately the design canvas: the board must not re-flow when the window
	# changes, only scale as one piece. Same function, different space - this is
	# not a second layout system.
	var layout: Dictionary = LayoutProfiles.get_profile(grid_size).duplicate(true)
	layout.merge(LayoutCoordinator.calculate_layout(grid_size, BOARD_SPACE, is_mobile_layout), true)
	return layout

func _sync_runtime_context(grid_size: int) -> void:
	_board_layout = _build_board_layout(grid_size)
	runtime.set_layout(_build_runtime_layout(grid_size))
	runtime.set_config({
		"grid_size": grid_size,
		"palette_name": selected_palette_name,
		"quality_name": selected_quality_name,
		"game_mode_name": selected_game_mode_name,
		"time_limit_minutes": selected_time_limit_minutes,
		"save_slot": selected_save_slot,
	})

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if match_seed >= 0:
		seed(match_seed)
	else:
		randomize()
	_view_size = _resolve_view_size()
	is_mobile_layout = _detect_mobile_layout()
	player_settings = PlayerSettingsStore.load_settings()
	presentation_events = PresentationEventsScript.new()
	audio_manager = AudioManagerScript.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)
	audio_manager.bind_presentation(presentation_events)
	_apply_audio_settings()
	_apply_performance_setting()
	_load_menu_preferences()
	_create_background()
	_create_start_menu()
	var size_cb: Callable = Callable(self, "_on_viewport_resized")
	if not get_viewport().size_changed.is_connected(size_cb):
		get_viewport().size_changed.connect(size_cb)


# Live resize. The board itself needs nothing but a new transform: its layout is
# viewport-independent by construction, so chambers, turrets and add-ball anchors
# all keep their relative positions for free. Only the screen-space pieces have to
# be re-applied: the chassis, the HUD, and the add-ball buttons (which live on
# their own CanvasLayer and therefore do not inherit board_root's transform).
func _on_viewport_resized() -> void:
	var new_size: Vector2 = _resolve_view_size()
	if new_size.is_equal_approx(_view_size):
		return
	_view_size = new_size
	if game_layer == null or not is_instance_valid(game_layer):
		return
	_sync_runtime_context(_runtime_grid_size())
	_apply_board_transform()
	_refresh_chassis()
	var hud_canvas = _hud_ref("ui_canvas")
	if hud_canvas != null and is_instance_valid(hud_canvas) and hud_canvas.has_method("setup_static"):
		hud_canvas.setup_static(self, _view_size, runtime.current_layout, is_mobile_layout)
	# Rebuild the add-ball buttons rather than moving them. They live on their own
	# CanvasLayer, which does not inherit board_root, and their positions are also
	# touched by the idle animation, so assigning position afterwards lost the
	# race (observed: right-hand buttons ended up on top of their chambers).
	# Re-running the original creation path is the only version guaranteed to
	# agree with a fresh start.
	var stale = game_layer.get_node_or_null("ControlButtons")
	if stale != null and is_instance_valid(stale):
		stale.queue_free()
	_create_control_buttons()

func _process(delta: float) -> void:
	ui_time += delta

	if GameStateCoordinator.should_process_restore_queue(get_tree(), is_game_over, bullet_restore_queue.pending_count()):
		_process_pending_bullet_restore()

	if GameStateCoordinator.should_advance_gameplay(get_tree(), game_layer, is_game_over):
		game_elapsed_time += delta
		for chamber in runtime.chambers.values():
			if chamber != null and is_instance_valid(chamber):
				chamber.set_game_elapsed_time(game_elapsed_time)

	perf_debug_update_timer -= delta
	if perf_debug_update_timer <= 0.0:
		perf_debug_update_timer = PERF_DEBUG_UPDATE_INTERVAL
		var fps_label = _hud_ref("fps_label")
		if fps_label != null and is_instance_valid(fps_label):
			fps_label.text = RuntimeHudController.get_perf_debug_text(runtime.bullet_pool, runtime.battlefield, _runtime_grid_size(), runtime.turrets)

	hud_meta_update_timer -= delta
	if hud_meta_update_timer <= 0.0:
		hud_meta_update_timer = HUD_META_UPDATE_INTERVAL
		RuntimeHudController.update_meta(_hud_ref("timer_label"), _hud_ref("stage_label"), _hud_ref("leader_label"), current_score_counts, game_elapsed_time)
		_check_winner()

	UIAnimationController.animate_menu_and_title(
		ui_time,
		menu_title_label,
		menu_start_button,
		menu_continue_button,
		_hud_ref("game_title_label"),
		_hud_ref("winner_label")
	)
	UIAnimationController.animate_add_ball_buttons(
		get_tree().paused,
		_ui_runtime_ref("add_ball_buttons", {}),
		_ui_runtime_ref("add_ball_button_base_positions", {}),
		ui_time
	)

func _detect_mobile_layout() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if DisplayServer.get_name() == "headless" or GameConfig.is_test_mode():
		return false
	var screen_size: Vector2i = GameConfig.get_safe_screen_size()
	if screen_size.x <= 1400 or screen_size.y <= 900:
		return true
	return false

func _toggle_settings_panel() -> void:
	var settings_panel = _hud_ref("settings_panel")
	if settings_panel == null or not is_instance_valid(settings_panel):
		return
	if settings_panel.visible:
		if settings_panel.has_method("hide_panel"):
			settings_panel.hide_panel()
		else:
			settings_panel.visible = false
		return

	settings_panel.show_panel()

func _create_background() -> void:
	var background = ColorRect.new()
	background.name = "MainBackground"
	background.color = Color(0.03, 0.07, 0.14)
	background.size = _view_size
	add_child(background)
	background.z_index = -100

func _create_start_menu() -> void:
	if menu_layer != null:
		menu_layer.queue_free()

	var menu_nodes: Dictionary
	var menu_layout: Dictionary = _build_runtime_layout(LayoutProfiles.sanitize_grid_size(selected_grid_size))
	var instance: CanvasLayer = StartMenuScene.instantiate()
	add_child(instance)
	instance.setup(self, _view_size, _get_save_slot_summaries(), menu_layout)
	menu_nodes = instance.get_parts()

	menu_layer = menu_nodes.get("menu_layer", null)
	menu_title_label = menu_nodes.get("menu_title_label", null)
	menu_start_button = menu_nodes.get("menu_start_button", null)
	menu_continue_button = menu_nodes.get("menu_continue_button", null)
	menu_status_label = menu_nodes.get("menu_status_label", null)
	if pending_menu_status_message != "":
		_show_menu_status(pending_menu_status_message)
		pending_menu_status_message = ""

func _start_game(grid_size: int, suppress_banner: bool = false, clear_save: bool = true,
		reserve_economy_enabled: bool = false) -> void:
	grid_size = LayoutProfiles.sanitize_grid_size(grid_size)
	selected_grid_size = grid_size
	game_elapsed_time = 0.0
	is_game_over = false

	if clear_save and not reserve_economy_enabled and _has_save_file(selected_save_slot):
		var save_path: String = _get_save_path(selected_save_slot)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveFlowController.get_backup_path(save_path)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveFlowController.get_temp_path(save_path)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SLOT_SAVE_PATH_TEMPLATE % selected_save_slot))
		if selected_save_slot == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))

	GameConfig.set_quality_by_name(selected_quality_name)
	GameConfig.set_game_mode_by_name(selected_game_mode_name)
	GameConfig.set_time_limit_minutes(selected_time_limit_minutes)

	if selected_palette_name == "默认随机":
		GameConfig.set_random_palette()
	else:
		GameConfig.set_palette_by_name(selected_palette_name)

	_cleanup_menu()
	_cleanup_game_layer()
	get_tree().paused = false
	_sync_runtime_context(grid_size)
	# 对局配置只在开局时快照一次：窗口缩放、UI 重建都不应该重新解释地图与武器规则。
	var match_config := MatchConfig.capture_current(grid_size, match_seed)
	match_config.reserve_economy_enabled = reserve_economy_enabled
	runtime.set_match_config(match_config)

	game_layer = Node2D.new()
	game_layer.name = "GameLayer"
	# Main 是 ALWAYS 以便暂停菜单可点击，但游戏层必须显式设为 PAUSABLE。
	# 否则子节点继承 Main 的 ALWAYS，暂停后子弹/炮塔/控制仓仍会继续运行。
	game_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game_layer)

	# Draw order: chassis first so the whole board sits on top of it.
	board_chassis = BoardChassisScript.new()
	board_chassis.name = "BoardChassis"
	game_layer.add_child(board_chassis)

	# CanvasLayer, not Node2D: a Node2D parent's scale changes what children
	# report as global_position, and Bullet/Turret/SaveGameCodec all work in
	# global space (measured: at scale 1.45 a +3 px global step became 2.07 px of
	# local movement, i.e. the simulation ran 1.45x slower). A CanvasLayer
	# transform is applied when drawing, so global_position stays in the design
	# space and the simulation is untouched - verified with
	# tools/tests/coord_semantics_probe.gd.
	board_root = CanvasLayer.new()
	board_root.name = "BoardRoot"
	board_root.layer = 1
	game_layer.add_child(board_root)
	_apply_board_transform()

	_create_battlefield(grid_size)
	_create_turrets()
	_create_control_chambers()
	_refresh_chassis()
	_create_ui()
	_create_event_roulette_system()
	_create_control_buttons()
	if not suppress_banner:
		_show_center_banner("领土战争", "开战！", Color(1.0, 0.94, 0.48), true)

func _create_battlefield(grid_size: int) -> void:
	var scene_nodes: Dictionary = GameSceneBuilder.create_battlefield(self, board_root, grid_size, _board_layout, BOARD_SPACE)
	runtime.battlefield = scene_nodes.get("battlefield", null)
	runtime.bullet_pool = scene_nodes.get("bullet_container", null)
	chamber_scale = float(scene_nodes.get("chamber_scale", 0.80))

func _on_release_sfx(faction_id = null, count = null, _chamber = null) -> void:
	if presentation_events != null:
		presentation_events.emit_released(int(faction_id) if faction_id != null else 0, int(count) if count != null else 0)


func _on_turret_destroyed_sfx(faction_id = null) -> void:
	if presentation_events != null:
		presentation_events.emit_destroyed(int(faction_id) if faction_id != null else 0)


func _on_turret_damaged_sfx(faction_id = null, amount = null) -> void:
	if presentation_events != null:
		presentation_events.emit_damaged(int(faction_id) if faction_id != null else 0, int(amount) if amount != null else 0)


func _on_ball_landed_sfx(faction_id = null, ball_count = null) -> void:
	if presentation_events != null:
		presentation_events.emit_ball_landed(int(faction_id) if faction_id != null else 0, int(ball_count) if ball_count != null else 0)


func _on_gate_multiplier_sfx(faction_id = null, multiplier = null, pending = null) -> void:
	if presentation_events != null:
		presentation_events.emit_multiplier_applied(
			int(faction_id) if faction_id != null else 0,
			int(multiplier) if multiplier != null else 0,
			int(pending) if pending != null else 0)


func _apply_audio_settings() -> void:
	if audio_manager == null:
		return
	audio_manager.apply_volumes(
		float(player_settings.get("master_volume", 0.7)),
		float(player_settings.get("sfx_volume", 0.55)),
		float(player_settings.get("music_volume", 0.6)))


func _refresh_chassis() -> void:
	if board_chassis == null or not is_instance_valid(board_chassis):
		return
	board_chassis.setup(_view_size, _board_screen_rect(), _chamber_screen_rects(), ArtStyleScript.low_effect())


func _create_turrets() -> void:
	runtime.turrets = GameSceneBuilder.create_turrets(self, board_root, runtime.battlefield, runtime.bullet_pool, _board_layout)
	for fid in runtime.turrets.keys():
		var t = runtime.turrets[fid]
		if t == null or not is_instance_valid(t):
			continue
		if t.has_signal("destroyed"):
			var cb: Callable = Callable(self, "_on_turret_destroyed_sfx")
			if not t.destroyed.is_connected(cb):
				t.destroyed.connect(cb)
		if t.has_signal("damaged"):
			var cb_damaged: Callable = Callable(self, "_on_turret_damaged_sfx")
			if not t.damaged.is_connected(cb_damaged):
				t.damaged.connect(cb_damaged)
	if runtime.bullet_pool != null and is_instance_valid(runtime.bullet_pool) and runtime.bullet_pool.has_method("set_tracked_turrets"):
		runtime.bullet_pool.set_tracked_turrets(runtime.turrets)

func _create_control_chambers() -> void:
	runtime.chambers = GameSceneBuilder.create_control_chambers(self, board_root, runtime.battlefield, runtime.turrets, _board_layout, chamber_scale, BOARD_SPACE)
	for fid in runtime.chambers.keys():
		var ch = runtime.chambers[fid]
		if ch == null or not is_instance_valid(ch):
			continue
		for pair in [
			["release_requested", "_on_release_sfx"],
			["ball_landed", "_on_ball_landed_sfx"],
			["gate_multiplier_applied", "_on_gate_multiplier_sfx"],
		]:
			var signal_name: String = String(pair[0])
			if not ch.has_signal(signal_name):
				continue
			var callback: Callable = Callable(self, String(pair[1]))
			var sig: Signal = ch.get(signal_name)
			if not sig.is_connected(callback):
				sig.connect(callback)
	_sync_chamber_game_elapsed_time()

func _create_ui() -> void:
	var game_hud: CanvasLayer = GameHUDScene.instantiate()
	game_hud.name = "UICanvas"
	game_hud.layer = 3
	game_layer.add_child(game_hud)
	game_hud.setup_static(self, _view_size, runtime.current_layout, is_mobile_layout)
	var hud_nodes: Dictionary = game_hud.get_static_parts()

	runtime.set_hud_parts(hud_nodes)
	var settings_panel = _hud_ref("settings_panel")
	var settings_changed := Callable(self, "_on_player_settings_changed")
	if settings_panel != null and settings_panel.has_signal("settings_changed"):
		if not settings_panel.is_connected("settings_changed", settings_changed):
			settings_panel.connect("settings_changed", settings_changed)
	_apply_performance_setting()
	runtime.set_ui_runtime_parts({
		"top_bar_segments": hud_nodes.get("top_bar_segments", {}),
		"top_bar_labels": hud_nodes.get("top_bar_labels", {}),
		"top_bar_name_labels": hud_nodes.get("top_bar_name_labels", {}),
		"top_bar_total_width": hud_nodes.get("top_bar_total_width", 0.0),
	})
	runtime.set_hud_ref("opening_banner", null)

	_on_scores_changed(runtime.battlefield.count_cells_by_team())

func _create_event_roulette_system() -> void:
	var ui_canvas = _hud_ref("ui_canvas")
	if game_layer == null or ui_canvas == null:
		return

	runtime.event_view = EventRouletteScene.instantiate()
	runtime.event_view.setup(_view_size, runtime.current_layout, is_mobile_layout)
	ui_canvas.add_child(runtime.event_view)

	var event_controller_script = load("res://scripts/EventRouletteController.gd")
	runtime.event_controller = event_controller_script.new()
	runtime.event_controller.name = "EventRouletteController"
	game_layer.add_child(runtime.event_controller)
	runtime.event_controller.setup(self, runtime.battlefield, runtime.chambers, runtime.turrets, _hud_ref("event_label"), runtime.event_view)
	_apply_event_log_setting()

	var finished_callable: Callable = Callable(self, "_on_event_round_finished")
	if not runtime.event_controller.event_round_finished.is_connected(finished_callable):
		runtime.event_controller.event_round_finished.connect(finished_callable)
	var banner_callable: Callable = Callable(self, "_on_event_banner_requested")
	if not runtime.event_controller.banner_requested.is_connected(banner_callable):
		runtime.event_controller.banner_requested.connect(banner_callable)
	var chamber_refresh_callable: Callable = Callable(self, "_on_event_chamber_ui_refresh_requested")
	if not runtime.event_controller.chamber_ui_refresh_requested.is_connected(chamber_refresh_callable):
		runtime.event_controller.chamber_ui_refresh_requested.connect(chamber_refresh_callable)

	_refresh_event_log()

func _create_control_buttons() -> void:
	var button_nodes: Dictionary = GameHudView.create_control_buttons(self, game_layer, runtime.chambers, runtime.current_layout, _view_size, is_mobile_layout)
	_set_ui_runtime_ref("add_ball_buttons", button_nodes.get("add_ball_buttons", {}))
	_set_ui_runtime_ref("add_ball_button_base_positions", button_nodes.get("add_ball_button_base_positions", {}))
	for faction_id in _ui_runtime_ref("add_ball_buttons", {}).keys():
		_refresh_add_ball_button(faction_id)

func _add_ball_to_chamber(faction_id: int) -> void:
	if not runtime.chambers.has(faction_id):
		return
	var chamber: ControlChamber = runtime.chambers[faction_id]
	if runtime.reserve_economy == null:
		chamber.add_control_ball()
	elif not is_game_over:
		runtime.reserve_economy.try_buy_control_ball(chamber)
	_refresh_add_ball_button(faction_id)

func _on_ball_count_changed(faction_id: int, _count: int) -> void:
	_refresh_add_ball_button(faction_id)

func _refresh_add_ball_button(faction_id: int) -> void:
	GameHudView.refresh_add_ball_button(faction_id, _ui_runtime_ref("add_ball_buttons", {}), runtime.chambers)

func _on_chamber_release_requested(faction_id, bullet_count, chamber) -> void:
	if is_game_over:
		chamber.set_locked(false)
		_refresh_add_ball_button(faction_id)
		return

	if runtime.turrets.has(faction_id):
		var turret: Turret = runtime.turrets[faction_id]
		var firepower := int(bullet_count)
		if runtime.reserve_economy != null:
			if runtime.chambers.get(faction_id) != chamber or turret.burst_remaining > 0:
				return
			if not turret.can_start_burst() or firepower <= 0:
				chamber.set_locked(false)
				_refresh_add_ball_button(faction_id)
				return
			firepower = mini(firepower, GameConfig.get_max_pending_count())
			firepower = runtime.reserve_economy.convert_release(faction_id, firepower)
		# 火力 → 弹种分配。P0 只解锁普通弹，分配总发数等于火力值，和旧行为一致；
		# P2 起弹种真正进入弹幕时，只需改这里的发射方式，不动分配与配置。
		var volley: Dictionary = _build_volley(firepower)
		var shot_count: int = WeaponRuleset.total_shots(volley)
		if shot_count <= 0:
			chamber.set_locked(false)
			_refresh_add_ball_button(faction_id)
			return
		chamber.start_locked(shot_count)
		_refresh_add_ball_button(faction_id)
		turret.fire_burst(shot_count)

func _build_volley(fire: int) -> Dictionary:
	if runtime.match_config != null and runtime.match_config.has_method("allocate_volley"):
		return runtime.match_config.allocate_volley(fire)
	return {WeaponRuleset.BulletType.STANDARD: maxi(0, fire)}

func _on_turret_burst_progress(faction_id, remaining) -> void:
	if runtime.chambers.has(faction_id):
		runtime.chambers[faction_id].update_locked_remaining(remaining)
	_refresh_add_ball_button(faction_id)

func _on_turret_burst_lock_changed(faction_id, locked) -> void:
	if runtime.chambers.has(faction_id):
		runtime.chambers[faction_id].set_locked(locked)
	_refresh_add_ball_button(faction_id)

func _on_turret_destroyed(faction_id: int) -> void:
	if runtime.chambers.has(faction_id):
		runtime.chambers[faction_id].set_damaged()
	_refresh_add_ball_button(faction_id)
	_check_winner()

func _check_winner() -> void:
	if is_game_over:
		return
	if game_layer == null or runtime.battlefield == null or runtime.turrets.is_empty():
		return

	var mode_name: String = GameConfig.get_game_mode_name()
	var counts: Dictionary = current_score_counts
	if counts.is_empty() and runtime.battlefield != null and is_instance_valid(runtime.battlefield):
		counts = runtime.battlefield.count_cells_by_team()

	var time_expired: bool = mode_name == GameConfig.GAME_MODE_TIMED and game_elapsed_time >= GameConfig.get_time_limit_seconds()
	var total_cells: int = _runtime_grid_size() * _runtime_grid_size()

	var result: Dictionary = WinConditionEvaluator.evaluate(mode_name, runtime.turrets, counts, total_cells, time_expired)

	if not result.ended:
		return
	if result.draw:
		_finish_as_draw(result.sub_text)
	else:
		_finish_with_winner(result.winner, result.sub_text)

func _finish_with_winner(faction_id: int, sub_text: String) -> void:
	GameStateCoordinator.finish_with_winner(self, _hud_ref("winner_label"), faction_id, sub_text)

func _finish_as_draw(sub_text: String) -> void:
	GameStateCoordinator.finish_as_draw(self, _hud_ref("winner_label"), sub_text)

func _stop_all_actions_for_game_over() -> void:
	GameStateCoordinator.stop_actions_for_game_over(
		runtime.turrets,
		runtime.chambers,
		Callable(self, "_refresh_add_ball_button"),
		Callable(self, "_clear_bullets"),
		runtime.event_controller,
		runtime.event_view
	)

func _on_scores_changed(counts: Dictionary) -> void:
	current_score_counts = counts.duplicate()
	RuntimeHudController.update_top_bar(
		counts,
		_ui_runtime_ref("top_bar_segments", {}),
		_ui_runtime_ref("top_bar_labels", {}),
		_ui_runtime_ref("top_bar_name_labels", {}),
		float(_ui_runtime_ref("top_bar_total_width", 0.0)),
		is_mobile_layout
	)
	RuntimeHudController.update_meta(_hud_ref("timer_label"), _hud_ref("stage_label"), _hud_ref("leader_label"), current_score_counts, game_elapsed_time)

func _show_center_banner(title_text: String, sub_text: String, accent: Color, auto_hide: bool) -> void:
	_set_hud_ref(
		"opening_banner",
		BannerController.show(
			self,
			_hud_ref("ui_canvas"),
			_hud_ref("opening_banner"),
			_view_size,
			runtime.current_layout,
			title_text,
			sub_text,
			accent,
			auto_hide
		)
	)

func _sync_chamber_game_elapsed_time() -> void:
	for chamber in runtime.chambers.values():
		if chamber != null and is_instance_valid(chamber):
			chamber.set_game_elapsed_time(game_elapsed_time)
			chamber.queue_redraw()

func _toggle_pause() -> void:
	if GameStateCoordinator.should_ignore_pause(is_game_over, game_layer):
		return
	GameStateCoordinator.apply_pause_toggle(
		get_tree(),
		_hud_ref("pause_overlay"),
		_hud_ref("pause_button"),
		Callable(self, "_save_game_progress")
	)
	# Pausing must not leave battle sounds ringing, and resuming must not replay
	# a backlog: events are played immediately, so stopping is the whole story.
	if audio_manager != null:
		audio_manager.on_pause_changed(get_tree().paused)

func _on_player_settings_changed(settings: Dictionary) -> void:
	var event_log_changed: bool = bool(player_settings.get("show_event_log", true)) != bool(settings.get("show_event_log", true))
	player_settings = settings.duplicate()
	# Volume moves the bus graph immediately; the panel already wrote the value
	# through, so a restart is not needed for any of these.
	_apply_audio_settings()
	_apply_performance_setting()
	if event_log_changed:
		_apply_event_log_setting()

func _apply_performance_setting() -> void:
	var enabled: bool = bool(player_settings.get("show_performance_info", OS.is_debug_build()))
	RuntimeHudController.set_performance_visible(enabled)
	for key in ["fps_label", "fps_bg"]:
		var control = _hud_ref(key)
		if control != null and is_instance_valid(control):
			control.visible = enabled and not is_mobile_layout

func _apply_event_log_setting() -> void:
	var enabled: bool = bool(player_settings.get("show_event_log", true))
	if runtime.event_controller != null and is_instance_valid(runtime.event_controller):
		runtime.event_controller.event_log_visible = enabled
	for key in ["event_log_label", "event_log_toggle_btn"]:
		var control = _hud_ref(key)
		if control != null and is_instance_valid(control):
			control.visible = enabled
	_refresh_event_log()

func _refresh_event_log() -> void:
	var event_log_label = _hud_ref("event_log_label")
	if event_log_label == null or not is_instance_valid(event_log_label):
		return
	if runtime.event_controller == null or not is_instance_valid(runtime.event_controller):
		return
	if not runtime.event_controller.has_method("get_event_log_text"):
		return
	var log_text: String = runtime.event_controller.get_event_log_text(8)
	if log_text.is_empty():
		return
	if event_log_label.has_method("update_event_log"):
		event_log_label.update_event_log(log_text)
	else:
		event_log_label.text = log_text

func _on_event_round_finished(_payload: Dictionary) -> void:
	_refresh_event_log()

func _on_event_banner_requested(title_text: String, sub_text: String, accent: Color, auto_hide: bool) -> void:
	_show_center_banner(title_text, sub_text, accent, auto_hide)

func _on_event_chamber_ui_refresh_requested(faction_id: int) -> void:
	_refresh_add_ball_button(faction_id)

func _load_menu_preferences() -> void:
	if not FileAccess.file_exists(MENU_PREF_PATH):
		return
	var file: FileAccess = FileAccess.open(MENU_PREF_PATH, FileAccess.READ)
	if file == null:
		return
	var raw_text: String = file.get_as_text()
	file.close()
	if raw_text.is_empty():
		return
	var test_json = JSON.new()
	if test_json.parse(raw_text) != OK:
		return
	var data = test_json.get_data()
	if not (data is Dictionary):
		return
	selected_grid_size = LayoutProfiles.sanitize_grid_size(int(data.get("grid_size", 40)))
	selected_palette_name = _sanitize_pref_palette(str(data.get("palette_name", "默认随机")))
	selected_quality_name = _sanitize_pref_quality(str(data.get("quality_name", GameConfig.QUALITY_MEDIUM)))
	selected_game_mode_name = _sanitize_pref_mode(str(data.get("game_mode_name", GameConfig.GAME_MODE_BASIC)))
	selected_time_limit_minutes = clampi(int(data.get("time_limit_minutes", GameConfig.DEFAULT_TIMED_MODE_MINUTES)), GameConfig.TIMED_MODE_MIN_MINUTES, GameConfig.TIMED_MODE_MAX_MINUTES)
	selected_save_slot = clampi(int(data.get("save_slot", 1)), 1, SAVE_SLOT_COUNT)

func _sanitize_pref_palette(value: String) -> String:
	if value == "默认随机":
		return value
	for pn in GameConfig.get_palette_names():
		if pn == value:
			return value
	return "默认随机"

func _sanitize_pref_quality(value: String) -> String:
	for qn in GameConfig.get_quality_names():
		if qn == value:
			return value
	return GameConfig.QUALITY_MEDIUM

func _sanitize_pref_mode(value: String) -> String:
	for mn in GameConfig.get_game_mode_names():
		if mn == value:
			return value
	return GameConfig.GAME_MODE_BASIC

func _save_menu_preferences() -> void:
	var data: Dictionary = {
		"grid_size": selected_grid_size,
		"palette_name": selected_palette_name,
		"quality_name": selected_quality_name,
		"game_mode_name": selected_game_mode_name,
		"time_limit_minutes": selected_time_limit_minutes,
		"save_slot": selected_save_slot,
	}
	var file: FileAccess = FileAccess.open(MENU_PREF_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[Main] cannot write menu preferences")
		return
	file.store_string(JSON.stringify(data, "\t", false, true))
	file.close()

func reset_menu_preferences() -> void:
	selected_grid_size = 40
	selected_palette_name = "默认随机"
	selected_quality_name = GameConfig.QUALITY_MEDIUM
	selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	selected_time_limit_minutes = GameConfig.DEFAULT_TIMED_MODE_MINUTES
	_save_menu_preferences()
	_create_start_menu()

func _save_and_exit_to_menu() -> void:
	if runtime.battlefield != null:
		_save_game_progress()
	get_tree().paused = false
	_cleanup_game_layer()
	_create_start_menu()

func _cleanup_menu() -> void:
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null
	menu_title_label = null
	menu_start_button = null
	menu_continue_button = null
	menu_status_label = null

func _cleanup_game_layer() -> void:
	GameStateCoordinator.reset_pause_and_winner_state(_hud_ref("pause_overlay"), _hud_ref("pause_button"), _hud_ref("winner_label"))
	if game_layer != null:
		game_layer.queue_free()
		game_layer = null
	board_root = null
	board_chassis = null
	# A fresh match must not inherit the previous one's sound tail. Connections
	# themselves die with the turrets and chambers, which are recreated per match.
	if audio_manager != null:
		audio_manager.stop_all()
	if presentation_events != null:
		presentation_events.reset_counts()
	runtime.reset()
	bullet_restore_queue.reset()

func _get_save_path(slot_index: int) -> String:
	return SaveFlowController.get_save_path(slot_index, SAVE_PATH_TEMPLATE, SAVE_SLOT_COUNT)

func _has_save_file(slot_index: int = -1) -> bool:
	return SaveFlowController.has_save_file(
		slot_index,
		selected_save_slot,
		SAVE_SLOT_COUNT,
		SAVE_PATH_TEMPLATE,
		LEGACY_SAVE_PATH,
		LEGACY_SLOT_SAVE_PATH_TEMPLATE
	)

func _get_save_slot_summaries() -> Array:
	return SaveFlowController.build_save_slot_summaries(
		SAVE_SLOT_COUNT,
		Callable(self, "_load_saved_data")
	)

func _clear_bullets() -> void:
	if runtime.bullet_pool == null:
		return
	if runtime.bullet_pool.has_method("clear_active"):
		runtime.bullet_pool.clear_active()
	else:
		for node in runtime.bullet_pool.get_children():
			node.queue_free()

func _restore_bullet_states(states) -> void:
	if runtime.bullet_pool == null or runtime.battlefield == null:
		return

	_clear_bullets()
	bullet_restore_queue.load_states(states, GameConfig.get_restore_bullet_limit())

func _process_pending_bullet_restore() -> void:
	if runtime.bullet_pool == null or runtime.battlefield == null:
		bullet_restore_queue.reset()
		return

	for state in bullet_restore_queue.take_batch(GameConfig.get_restore_per_frame()):
		if not (state is Dictionary):
			continue

		var bullet
		if runtime.bullet_pool.has_method("spawn_bullet_from_state"):
			bullet = runtime.bullet_pool.spawn_bullet_from_state(state, runtime.battlefield, runtime.turrets)
		else:
			bullet = Bullet.new()
			bullet.restore_from_state(state, runtime.battlefield, runtime.turrets)
			bullet.activate()
			runtime.bullet_pool.add_child(bullet)

func _save_game_progress() -> Dictionary:
	if runtime.reserve_economy != null:
		pending_menu_status_message = "储备实验未写入普通存档。"
		return {"ok": false, "error_message": pending_menu_status_message}
	var result: Dictionary = SaveFlowController.write_game_progress_result(
		selected_save_slot,
		SAVE_PATH_TEMPLATE,
		SAVE_SLOT_COUNT,
		runtime.chambers,
		runtime.turrets,
		runtime.battlefield,
		runtime.bullet_pool,
		runtime.event_controller,
		game_elapsed_time,
		is_game_over,
		_hud_ref("winner_label")
	)
	if not bool(result.get("ok", false)):
		pending_menu_status_message = str(result.get("error_message", "保存失败"))
		push_warning(pending_menu_status_message)
		if _hud_ref("ui_canvas") != null:
			_show_center_banner("保存失败", pending_menu_status_message, Color(1.0, 0.50, 0.36), true)
	return result

func _load_saved_data(slot_index: int = -1, allow_legacy: bool = true) -> Dictionary:
	return SaveFlowController.load_saved_data(
		slot_index,
		selected_save_slot,
		SAVE_SLOT_COUNT,
		SAVE_PATH_TEMPLATE,
		LEGACY_SAVE_PATH,
		allow_legacy,
		LEGACY_SLOT_SAVE_PATH_TEMPLATE
	)

func _select_save_slot(slot_index: int) -> void:
	selected_save_slot = SaveFlowController.normalize_slot(slot_index, selected_save_slot, SAVE_SLOT_COUNT)
	_save_menu_preferences()
	_show_menu_status(SaveFlowController.build_slot_selection_status_message(selected_save_slot, _has_save_file(selected_save_slot)))
	_refresh_menu_save_slots()

func _refresh_menu_save_slots() -> void:
	var summaries: Array = _get_save_slot_summaries()
	if menu_layer != null and is_instance_valid(menu_layer) and menu_layer.has_method("refresh_slots"):
		menu_layer.refresh_slots(summaries)

func _show_menu_status(message: String) -> void:
	if menu_status_label != null and is_instance_valid(menu_status_label):
		menu_status_label.text = message
	else:
		push_warning(message)

func _continue_saved_game() -> void:
	var prepared: Dictionary = SaveFlowController.prepare_continue_payload(
		-1,
		selected_save_slot,
		SAVE_SLOT_COUNT,
		SAVE_PATH_TEMPLATE,
		LEGACY_SAVE_PATH,
		true,
		LEGACY_SLOT_SAVE_PATH_TEMPLATE
	)
	if not bool(prepared.get("ok", false)):
		_show_menu_status(str(prepared.get("error_message", "存档读取失败或存档已损坏")))
		var warning_message: String = str(prepared.get("warning_message", ""))
		if warning_message != "":
			push_warning(warning_message)
		return

	_continue_from_prepared_payload(prepared)

func _apply_saved_state(restore_input) -> void:
	if runtime.battlefield == null:
		return

	var restore_plan: RestorePlan = restore_input if restore_input is RestorePlan else RestorePlan.build_from_clean_data(restore_input if restore_input is Dictionary else {})
	var restore_data: Dictionary = restore_plan.to_restore_dictionary()

	SaveStateApplier.apply_owners(runtime.battlefield, restore_data, Callable(self, "_on_scores_changed"))
	SaveStateApplier.apply_factions(
		runtime.chambers,
		runtime.turrets,
		restore_plan.faction_states,
		func(chamber): chamber.set_locked(false),
		Callable(self, "_refresh_add_ball_button")
	)

	SaveStateApplier.apply_event_state(runtime.event_controller, {"event_state": restore_plan.event_state})

	_refresh_event_log()

	_restore_bullet_states(restore_plan.bullet_states)

	is_game_over = SaveStateApplier.apply_game_over_state(restore_plan.game_over_state, _hud_ref("winner_label"))
	if is_game_over:
		_stop_all_actions_for_game_over()

func _continue_from_prepared_payload(prepared: Dictionary) -> void:
	var execution_plan: Dictionary = SaveFlowController.prepare_continue_start_plan(prepared.get("data", {}), selected_time_limit_minutes)
	var status_message: String = str(prepared.get("status_message", ""))
	if status_message != "":
		var banner: Dictionary = execution_plan.get("banner", {}).duplicate(true)
		banner["subtitle"] = "%s\n%s" % [str(banner.get("subtitle", "继续作战")), status_message]
		execution_plan["banner"] = banner
	var execution_data: Dictionary = execution_plan.get("data", {})
	var restore_plan: RestorePlan = RestorePlan.build_from_clean_data(execution_data)
	_apply_continue_start_plan(execution_plan, restore_plan)

func _apply_continue_start_plan(execution_plan: Dictionary, restore_plan: RestorePlan) -> void:
	var execution_start_values: Dictionary = execution_plan.get("start_values", {})
	var execution_banner: Dictionary = execution_plan.get("banner", {})
	SaveFlowController.apply_continue_start_plan(execution_plan, self)
	_start_game(int(execution_start_values.get("grid_size", 40)), true, false)
	game_elapsed_time = float(execution_start_values.get("game_elapsed_time", 0.0))
	_sync_chamber_game_elapsed_time()
	_apply_saved_state(restore_plan)
	_show_center_banner(
		str(execution_banner.get("title", "领土战争")),
		str(execution_banner.get("subtitle", "继续作战")),
		execution_banner.get("accent", Color(0.84, 0.96, 1.0)),
		bool(execution_banner.get("auto_hide", true))
	)
