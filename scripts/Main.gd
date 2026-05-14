extends Node2D

const VIEW_W: float = 1120.0
const VIEW_H: float = 720.0
const LEGACY_SAVE_PATH: String = "user://ballwar_save.json"
const SAVE_PATH_TEMPLATE: String = "user://ballwar_save_slot_%d.json"
const SAVE_SLOT_COUNT: int = 5

var battlefield
var bullet_container
var turrets: Dictionary = {}
var chambers: Dictionary = {}
var add_ball_buttons: Dictionary = {}
var add_ball_button_base_positions: Dictionary = {}

var top_bar_segments: Dictionary = {}
var top_bar_labels: Dictionary = {}
var top_bar_name_labels: Dictionary = {}
var top_bar_total_width: float = 0.0

var winner_label
var game_title_label
var ui_canvas
var opening_banner
var pause_overlay
var pause_button
var exit_button
var fps_label
var settings_button
var settings_panel
var leader_label
var timer_label
var stage_label
var event_info_label
var current_score_counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
var is_mobile_layout: bool = false
var event_roulette_controller = null
var event_roulette_view = null

var menu_layer
var game_layer
var selected_grid_size: int = 40
var selected_palette_name: String = "默认随机"
var selected_quality_name: String = GameConfig.QUALITY_MEDIUM
var selected_game_mode_name: String = GameConfig.GAME_MODE_BASIC
var selected_time_limit_minutes: int = GameConfig.DEFAULT_TIMED_MODE_MINUTES
var selected_save_slot: int = 1
var current_layout: Dictionary = {}
var game_elapsed_time: float = 0.0
var is_game_over: bool = false

var menu_title_label
var menu_start_button
var menu_continue_button
var menu_save_slot_buttons: Dictionary = {}
var menu_status_label
var ui_time: float = 0.0
var chamber_scale: float = 1.0
var pending_restore_bullets: Array = []
var pending_restore_index: int = 0
var perf_debug_update_timer: float = 0.0
var hud_meta_update_timer: float = 0.0
const PERF_DEBUG_UPDATE_INTERVAL: float = 0.25
const HUD_META_UPDATE_INTERVAL: float = 0.25

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    randomize()
    is_mobile_layout = _detect_mobile_layout()
    _create_background()
    _create_start_menu()

func _process(delta: float) -> void:
    ui_time += delta

    if GameStateCoordinator.should_process_restore_queue(get_tree(), is_game_over, pending_restore_bullets.size()):
        _process_pending_bullet_restore()

    if GameStateCoordinator.should_advance_gameplay(get_tree(), game_layer, is_game_over):
        game_elapsed_time += delta
        for chamber in chambers.values():
            if chamber != null and is_instance_valid(chamber):
                chamber.set_game_elapsed_time(game_elapsed_time)

    perf_debug_update_timer -= delta
    if perf_debug_update_timer <= 0.0:
        perf_debug_update_timer = PERF_DEBUG_UPDATE_INTERVAL
        if fps_label != null and is_instance_valid(fps_label):
            fps_label.text = RuntimeHudController.get_perf_debug_text(bullet_container, battlefield, selected_grid_size, turrets)

    hud_meta_update_timer -= delta
    if hud_meta_update_timer <= 0.0:
        hud_meta_update_timer = HUD_META_UPDATE_INTERVAL
        RuntimeHudController.update_meta(timer_label, stage_label, leader_label, current_score_counts, game_elapsed_time)
        _check_winner()

    UIAnimationController.animate_menu_and_title(
        ui_time,
        menu_title_label,
        menu_start_button,
        menu_continue_button,
        game_title_label,
        winner_label
    )
    UIAnimationController.animate_add_ball_buttons(get_tree().paused, add_ball_buttons, add_ball_button_base_positions, ui_time)

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
    if settings_panel == null or not is_instance_valid(settings_panel):
        return
    if settings_panel.visible:
        if settings_panel.has_method("hide_panel"):
            settings_panel.hide_panel()
        else:
            settings_panel.visible = false
        return

    if settings_panel.has_method("show_content"):
        settings_panel.show_content(GameConfig.get_quality_name(), "手机横屏" if is_mobile_layout else "电脑")
    else:
        settings_panel.visible = true

func _create_background() -> void:
    var background = ColorRect.new()
    background.name = "MainBackground"
    background.color = Color(0.03, 0.07, 0.14)
    background.size = Vector2(VIEW_W, VIEW_H)
    add_child(background)
    background.z_index = -100

func _create_start_menu() -> void:
    if menu_layer != null:
        menu_layer.queue_free()

    var menu_nodes: Dictionary
    var scene_path: String = "res://scenes/ui/StartMenu.tscn"
    if ResourceLoader.exists(scene_path):
        var scene: PackedScene = load(scene_path)
        var instance: CanvasLayer = scene.instantiate()
        add_child(instance)
        instance.setup(self, Vector2(VIEW_W, VIEW_H), _get_save_slot_summaries())
        menu_nodes = instance.get_parts()
        print("[StartMenu] Loaded scene StartMenu.tscn")
    else:
        menu_nodes = StartMenuView.create(self, Vector2(VIEW_W, VIEW_H), _get_save_slot_summaries())
        print("[StartMenu] Scene load failed, fallback to legacy StartMenuView.gd")

    menu_layer = menu_nodes.get("menu_layer", null)
    menu_title_label = menu_nodes.get("menu_title_label", null)
    menu_start_button = menu_nodes.get("menu_start_button", null)
    menu_continue_button = menu_nodes.get("menu_continue_button", null)
    menu_save_slot_buttons = menu_nodes.get("menu_save_slot_buttons", {})
    menu_status_label = menu_nodes.get("menu_status_label", null)

func _start_game(grid_size: int, suppress_banner: bool = false, clear_save: bool = true) -> void:
    grid_size = LayoutProfiles.sanitize_grid_size(grid_size)
    selected_grid_size = grid_size
    current_layout = LayoutProfiles.get_profile(grid_size)
    game_elapsed_time = 0.0
    is_game_over = false

    if clear_save and _has_save_file(selected_save_slot):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(_get_save_path(selected_save_slot)))
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

    turrets.clear()
    chambers.clear()
    add_ball_buttons.clear()
    add_ball_button_base_positions.clear()
    top_bar_segments.clear()
    top_bar_labels.clear()
    top_bar_name_labels.clear()

    game_layer = Node2D.new()
    game_layer.name = "GameLayer"
    # Main 是 ALWAYS 以便暂停菜单可点击，但游戏层必须显式设为 PAUSABLE。
    # 否则子节点继承 Main 的 ALWAYS，暂停后子弹/炮塔/控制仓仍会继续运行。
    game_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(game_layer)

    _create_battlefield(grid_size)
    _create_turrets()
    _create_control_chambers()
    _create_ui()
    _create_event_roulette_system()
    _create_control_buttons()
    if not suppress_banner:
        _show_center_banner("领土战争", "开战！", Color(1.0, 0.94, 0.48), true)

func _create_battlefield(grid_size: int) -> void:
    var scene_nodes: Dictionary = GameSceneBuilder.create_battlefield(self, game_layer, grid_size, current_layout, Vector2(VIEW_W, VIEW_H))
    battlefield = scene_nodes.get("battlefield", null)
    bullet_container = scene_nodes.get("bullet_container", null)
    chamber_scale = float(scene_nodes.get("chamber_scale", 0.80))

func _create_turrets() -> void:
    turrets = GameSceneBuilder.create_turrets(self, game_layer, battlefield, bullet_container)
    if bullet_container != null and is_instance_valid(bullet_container) and bullet_container.has_method("set_tracked_turrets"):
        bullet_container.set_tracked_turrets(turrets)

func _create_control_chambers() -> void:
    chambers = GameSceneBuilder.create_control_chambers(self, game_layer, battlefield, turrets, current_layout, chamber_scale, Vector2(VIEW_W, VIEW_H))
    _sync_chamber_game_elapsed_time()

func _create_ui() -> void:
    var hud_nodes: Dictionary
    var scene_path: String = "res://scenes/ui/GameHUD.tscn"
    if ResourceLoader.exists(scene_path):
        var scene: PackedScene = load(scene_path)
        var game_hud: CanvasLayer = scene.instantiate()
        game_hud.name = "UICanvas"
        game_layer.add_child(game_hud)
        game_hud.setup_static(self, Vector2(VIEW_W, VIEW_H), current_layout, is_mobile_layout)
        hud_nodes = game_hud.get_static_parts()
        print("[GameHUD] Loaded scene GameHUD.tscn")
    else:
        hud_nodes = GameHudView.create_runtime_ui(self, game_layer, battlefield, current_layout, Vector2(VIEW_W, VIEW_H), is_mobile_layout)
        print("[GameHUD] Scene load failed, fallback to legacy GameHudView.gd")

    ui_canvas = hud_nodes.get("ui_canvas", null)
    top_bar_segments = hud_nodes.get("top_bar_segments", {})
    top_bar_labels = hud_nodes.get("top_bar_labels", {})
    top_bar_name_labels = hud_nodes.get("top_bar_name_labels", {})
    top_bar_total_width = float(hud_nodes.get("top_bar_total_width", 0.0))
    winner_label = hud_nodes.get("winner_label", null)
    game_title_label = hud_nodes.get("game_title_label", null)
    pause_overlay = hud_nodes.get("pause_overlay", null)
    pause_button = hud_nodes.get("pause_button", null)
    exit_button = hud_nodes.get("exit_button", null)
    fps_label = hud_nodes.get("fps_label", null)
    settings_button = hud_nodes.get("settings_button", null)
    settings_panel = hud_nodes.get("settings_panel", null)
    leader_label = hud_nodes.get("leader_label", null)
    timer_label = hud_nodes.get("timer_label", null)
    stage_label = hud_nodes.get("stage_label", null)
    event_info_label = hud_nodes.get("event_label", null)

    _on_scores_changed(battlefield.count_cells_by_team())

func _create_event_roulette_system() -> void:
    if game_layer == null or ui_canvas == null:
        return

    var scene_path: String = "res://scenes/ui/EventRouletteView.tscn"
    if ResourceLoader.exists(scene_path):
        var scene: PackedScene = load(scene_path)
        event_roulette_view = scene.instantiate()
        event_roulette_view.setup(Vector2(VIEW_W, VIEW_H), current_layout, is_mobile_layout)
        print("[EventRoulette] Loaded scene EventRouletteView.tscn")
    else:
        var event_view_script = load("res://scripts/EventRouletteView.gd")
        event_roulette_view = event_view_script.new()
        event_roulette_view.name = "EventRouletteView"
        event_roulette_view.setup(Vector2(VIEW_W, VIEW_H), current_layout, is_mobile_layout)
        print("[EventRoulette] Scene load failed, fallback to legacy EventRouletteView.gd")
    ui_canvas.add_child(event_roulette_view)

    var event_controller_script = load("res://scripts/EventRouletteController.gd")
    event_roulette_controller = event_controller_script.new()
    event_roulette_controller.name = "EventRouletteController"
    game_layer.add_child(event_roulette_controller)
    event_roulette_controller.setup(self, battlefield, chambers, turrets, event_info_label, event_roulette_view)

func _create_control_buttons() -> void:
    var button_nodes: Dictionary = GameHudView.create_control_buttons(self, game_layer, chambers, current_layout, Vector2(VIEW_W, VIEW_H), is_mobile_layout)
    add_ball_buttons = button_nodes.get("add_ball_buttons", {})
    add_ball_button_base_positions = button_nodes.get("add_ball_button_base_positions", {})
    for faction_id in add_ball_buttons.keys():
        _refresh_add_ball_button(faction_id)

func _add_ball_to_chamber(faction_id: int) -> void:
    if not chambers.has(faction_id):
        return
    chambers[faction_id].add_control_ball()
    _refresh_add_ball_button(faction_id)

func _on_ball_count_changed(faction_id: int, _count: int) -> void:
    _refresh_add_ball_button(faction_id)

func _refresh_add_ball_button(faction_id: int) -> void:
    GameHudView.refresh_add_ball_button(faction_id, add_ball_buttons, chambers)

func _on_chamber_release_requested(faction_id, bullet_count, chamber) -> void:
    if is_game_over:
        chamber.set_locked(false)
        _refresh_add_ball_button(faction_id)
        return

    if turrets.has(faction_id):
        chamber.start_locked(bullet_count)
        _refresh_add_ball_button(faction_id)
        turrets[faction_id].fire_burst(bullet_count)

func _on_turret_burst_progress(faction_id, remaining) -> void:
    if chambers.has(faction_id):
        chambers[faction_id].update_locked_remaining(remaining)
    _refresh_add_ball_button(faction_id)

func _on_turret_burst_lock_changed(faction_id, locked) -> void:
    if chambers.has(faction_id):
        chambers[faction_id].set_locked(locked)
    _refresh_add_ball_button(faction_id)

func _on_turret_destroyed(faction_id: int) -> void:
    if chambers.has(faction_id):
        chambers[faction_id].set_damaged()
    _refresh_add_ball_button(faction_id)
    _check_winner()

func _check_winner() -> void:
    if is_game_over:
        return
    if game_layer == null or battlefield == null or turrets.is_empty():
        return

    var mode_name: String = GameConfig.get_game_mode_name()
    var counts: Dictionary = current_score_counts
    if counts.is_empty() and battlefield != null and is_instance_valid(battlefield):
        counts = battlefield.count_cells_by_team()

    var time_expired: bool = mode_name == GameConfig.GAME_MODE_TIMED and game_elapsed_time >= GameConfig.get_time_limit_seconds()
    var total_cells: int = selected_grid_size * selected_grid_size

    var result: Dictionary = WinConditionEvaluator.evaluate(mode_name, turrets, counts, total_cells, time_expired)

    if not result.ended:
        return
    if result.draw:
        _finish_as_draw(result.sub_text)
    else:
        _finish_with_winner(result.winner, result.sub_text)

# Deprecated after v2.0.4:
# win-condition logic is now delegated to WinConditionEvaluator.
# Kept temporarily for safe rollback in non-git workspace.
# Remove in v2.0.5 or v2.0.6 once confirmed stable.

func _get_occupation_winner() -> int:
    var counts: Dictionary = current_score_counts
    if counts.is_empty() and battlefield != null and is_instance_valid(battlefield):
        counts = battlefield.count_cells_by_team()

    var total: int = 0
    var best_id: int = -1
    var best_count: int = -1
    var tied: bool = false
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var count: int = int(counts.get(faction_id, 0))
        total += count
        if count > best_count:
            best_count = count
            best_id = int(faction_id)
            tied = false
        elif count == best_count:
            tied = true

    if total <= 0 or tied:
        return -1
    var target_percent: int = GameConfig.get_occupation_target_percent()
    if best_count * 100 >= total * target_percent:
        return best_id
    return -1

# Deprecated after v2.0.4. See _get_occupation_winner note above.

func _get_score_winner() -> int:
    var counts: Dictionary = current_score_counts
    if counts.is_empty() and battlefield != null and is_instance_valid(battlefield):
        counts = battlefield.count_cells_by_team()

    var best_id: int = -1
    var best_count: int = -1
    var tied: bool = false
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var count: int = int(counts.get(faction_id, 0))
        if count > best_count:
            best_count = count
            best_id = int(faction_id)
            tied = false
        elif count == best_count:
            tied = true
    if tied:
        return -1
    return best_id

func _finish_with_winner(faction_id: int, sub_text: String) -> void:
    GameStateCoordinator.finish_with_winner(self, winner_label, faction_id, sub_text)

func _finish_as_draw(sub_text: String) -> void:
    GameStateCoordinator.finish_as_draw(self, winner_label, sub_text)

func _stop_all_actions_for_game_over() -> void:
    GameStateCoordinator.stop_actions_for_game_over(
        turrets,
        chambers,
        Callable(self, "_refresh_add_ball_button"),
        Callable(self, "_clear_bullets"),
        event_roulette_controller,
        event_roulette_view
    )

func _on_scores_changed(counts: Dictionary) -> void:
    current_score_counts = counts.duplicate()
    RuntimeHudController.update_top_bar(
        counts,
        top_bar_segments,
        top_bar_labels,
        top_bar_name_labels,
        top_bar_total_width,
        is_mobile_layout
    )
    RuntimeHudController.update_meta(timer_label, stage_label, leader_label, current_score_counts, game_elapsed_time)

func _show_center_banner(title_text: String, sub_text: String, accent: Color, auto_hide: bool) -> void:
    opening_banner = BannerController.show(self, ui_canvas, opening_banner, Vector2(VIEW_W, VIEW_H), current_layout, title_text, sub_text, accent, auto_hide)

func _sync_chamber_game_elapsed_time() -> void:
    for chamber in chambers.values():
        if chamber != null and is_instance_valid(chamber):
            chamber.set_game_elapsed_time(game_elapsed_time)
            chamber.queue_redraw()

func _toggle_pause() -> void:
    if GameStateCoordinator.should_ignore_pause(is_game_over, game_layer):
        return
    GameStateCoordinator.apply_pause_toggle(
        get_tree(),
        pause_overlay,
        pause_button,
        Callable(self, "_save_game_progress")
    )

func _save_and_exit_to_menu() -> void:
    if battlefield != null:
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
    menu_save_slot_buttons.clear()
    menu_status_label = null

func _cleanup_game_layer() -> void:
    GameStateCoordinator.reset_pause_and_winner_state(pause_overlay, pause_button, winner_label)
    if game_layer != null:
        game_layer.queue_free()
        game_layer = null
    battlefield = null
    bullet_container = null
    ui_canvas = null
    opening_banner = null
    pause_overlay = null
    pause_button = null
    exit_button = null
    winner_label = null
    game_title_label = null
    fps_label = null
    settings_button = null
    settings_panel = null
    leader_label = null
    timer_label = null
    stage_label = null
    event_info_label = null
    event_roulette_controller = null
    event_roulette_view = null
    pending_restore_bullets.clear()
    pending_restore_index = 0
    turrets.clear()
    chambers.clear()
    add_ball_buttons.clear()
    add_ball_button_base_positions.clear()
    top_bar_segments.clear()
    top_bar_labels.clear()
    top_bar_name_labels.clear()

func _get_save_path(slot_index: int) -> String:
    return SaveFlowController.get_save_path(slot_index, SAVE_PATH_TEMPLATE, SAVE_SLOT_COUNT)

func _has_save_file(slot_index: int = -1) -> bool:
    return SaveFlowController.has_save_file(
        slot_index,
        selected_save_slot,
        SAVE_SLOT_COUNT,
        SAVE_PATH_TEMPLATE,
        LEGACY_SAVE_PATH
    )

func _get_save_slot_summaries() -> Array:
    return SaveFlowController.build_save_slot_summaries(
        SAVE_SLOT_COUNT,
        Callable(self, "_load_saved_data")
    )

func _clear_bullets() -> void:
    if bullet_container == null:
        return
    if bullet_container.has_method("clear_active"):
        bullet_container.clear_active()
    else:
        for node in bullet_container.get_children():
            node.queue_free()

func _restore_bullet_states(states) -> void:
    if bullet_container == null or battlefield == null:
        return

    _clear_bullets()
    pending_restore_bullets.clear()
    pending_restore_index = 0

    if not (states is Array):
        return

    var restore_count: int = mini(states.size(), GameConfig.get_restore_bullet_limit())
    for i in range(restore_count):
        if states[i] is Dictionary:
            pending_restore_bullets.append(states[i])

func _process_pending_bullet_restore() -> void:
    if bullet_container == null or battlefield == null:
        pending_restore_bullets.clear()
        pending_restore_index = 0
        return

    var end_index: int = mini(pending_restore_index + GameConfig.get_restore_per_frame(), pending_restore_bullets.size())
    for i in range(pending_restore_index, end_index):
        var state = pending_restore_bullets[i]
        if not (state is Dictionary):
            continue

        var bullet
        if bullet_container.has_method("spawn_bullet_from_state"):
            bullet = bullet_container.spawn_bullet_from_state(state, battlefield, turrets)
        else:
            bullet = Bullet.new()
            bullet.restore_from_state(state, battlefield, turrets)
            bullet.activate()
            bullet_container.add_child(bullet)

    pending_restore_index = end_index
    if pending_restore_index >= pending_restore_bullets.size():
        pending_restore_bullets.clear()
        pending_restore_index = 0


func _save_game_progress() -> void:
    SaveFlowController.write_game_progress(
        selected_save_slot,
        SAVE_PATH_TEMPLATE,
        SAVE_SLOT_COUNT,
        chambers,
        turrets,
        battlefield,
        bullet_container,
        event_roulette_controller,
        game_elapsed_time,
        is_game_over,
        winner_label
    )

func _load_saved_data(slot_index: int = -1, allow_legacy: bool = true) -> Dictionary:
    return SaveFlowController.load_saved_data(
        slot_index,
        selected_save_slot,
        SAVE_SLOT_COUNT,
        SAVE_PATH_TEMPLATE,
        LEGACY_SAVE_PATH,
        allow_legacy
    )

func _select_save_slot(slot_index: int) -> void:
    selected_save_slot = SaveFlowController.normalize_slot(slot_index, selected_save_slot, SAVE_SLOT_COUNT)
    _show_menu_status(SaveFlowController.build_slot_selection_status(selected_save_slot, _has_save_file(selected_save_slot)))
    _refresh_menu_save_slots()

func _refresh_menu_save_slots() -> void:
    SaveFlowController.refresh_menu_slot_ui(
        menu_save_slot_buttons,
        selected_save_slot,
        _get_save_slot_summaries(),
        menu_continue_button,
        _has_save_file(selected_save_slot)
    )

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
        true
    )
    if not bool(prepared.get("ok", false)):
        _show_menu_status(str(prepared.get("error_message", "存档读取失败或存档已损坏")))
        var warning_message: String = str(prepared.get("warning_message", ""))
        if warning_message != "":
            push_warning(warning_message)
        return

    _continue_from_prepared_payload(prepared)

func _apply_saved_state(restore_input) -> void:
    if battlefield == null:
        return

    var restore_plan: RestorePlan = restore_input if restore_input is RestorePlan else RestorePlan.build_from_clean_data(restore_input if restore_input is Dictionary else {})
    var restore_data: Dictionary = restore_plan.to_restore_dictionary()

    SaveStateApplier.apply_owners(battlefield, restore_data, Callable(self, "_on_scores_changed"))
    SaveStateApplier.apply_factions(
        chambers,
        turrets,
        restore_plan.faction_states,
        func(chamber): chamber.set_locked(false),
        Callable(self, "_refresh_add_ball_button")
    )

    SaveStateApplier.apply_event_state(event_roulette_controller, {"event_state": restore_plan.event_state})

    _restore_bullet_states(restore_plan.bullet_states)

    is_game_over = SaveStateApplier.apply_game_over_state(restore_plan.game_over_state, winner_label)
    if is_game_over:
        _stop_all_actions_for_game_over()

func _continue_from_prepared_payload(prepared: Dictionary) -> void:
    var execution_plan: Dictionary = SaveFlowController.prepare_continue_start_plan(prepared.get("data", {}), selected_time_limit_minutes)
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

