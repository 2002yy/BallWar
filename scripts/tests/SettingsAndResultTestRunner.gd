extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")
const SettingsScene = preload("res://scenes/ui/SettingsPanel.tscn")
const ResultScene = preload("res://scenes/ui/ResultPanel.tscn")
const PlayerSettingsStore = preload("res://scripts/PlayerSettingsStore.gd")
const RuntimeHudController = preload("res://scripts/RuntimeHudController.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[SettingsAndResultTest] v2.1.9")
	await process_frame

	_cleanup_settings_file()
	await _test_settings_persistence(t)
	await _flush()
	await _test_performance_toggle(t)
	await _flush()
	await _test_event_log_toggle(t)
	await _flush()
	await _test_result_panel(t)
	await _flush()

	t.report("[SettingsAndResultTest]")
	if t.failures.is_empty():
		quit(0)
	else:
		quit(1)


func _flush() -> void:
	await process_frame
	await process_frame


func _cleanup_settings_file() -> void:
	var path := ProjectSettings.globalize_path("user://player_settings.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# === P1: Settings persistence ===
func _test_settings_persistence(t: TestAssert) -> void:
	print("  [P1] settings persistence")

	var prefs := PlayerSettingsStore.default_settings()
	prefs["show_performance_info"] = false
	prefs["show_event_log"] = false
	prefs["low_effect_mode"] = true
	PlayerSettingsStore.save_settings(prefs)

	var loaded := PlayerSettingsStore.load_settings()
	t.eq(bool(loaded["show_performance_info"]), false, "persist: show_performance_info=false")
	t.eq(bool(loaded["show_event_log"]), false, "persist: show_event_log=false")
	t.eq(bool(loaded["low_effect_mode"]), true, "persist: low_effect_mode=true")

	var panel = SettingsScene.instantiate()
	get_root().add_child(panel)
	await process_frame

	var perf_cb: CheckButton = panel.get_node("PanelMargin/MainVBox/PerformanceCheck")
	var log_cb: CheckButton = panel.get_node("PanelMargin/MainVBox/EventLogCheck")
	t.that(not perf_cb.button_pressed, "panel loads show_perf=false")
	t.that(not log_cb.button_pressed, "panel loads show_log=false")
	var emissions: Array = []
	panel.settings_changed.connect(func(_settings): emissions.append(true))
	prefs["show_performance_info"] = true
	PlayerSettingsStore.save_settings(prefs)
	panel.show_panel()
	t.eq(emissions.size(), 0, "refreshing panel does not emit a user change")
	t.eq(PlayerSettingsStore.load_settings(), prefs, "refresh does not clobber other saved choices")

	panel.queue_free()
	await process_frame


# === P2: Performance setting through the real panel ===
func _test_performance_toggle(t: TestAssert) -> void:
	print("  [P2] performance panel -> persisted setting -> runtime HUD")
	var prefs := PlayerSettingsStore.default_settings()
	prefs["show_performance_info"] = false
	PlayerSettingsStore.save_settings(prefs)
	var main = load("res://scripts/Main.gd").new()
	get_root().add_child(main)
	main.selected_save_slot = 9
	main._start_game(20, true, false)
	await _flush()
	t.that(not RuntimeHudController.performance_visible, "saved performance=false applied at startup")
	t.eq(RuntimeHudController.get_perf_debug_text(null, null, 10, {}), "", "hidden performance text is empty")
	t.that(not main.runtime.hud_ref("fps_label").visible, "performance label hidden")
	t.that(not main.runtime.hud_ref("fps_bg").visible, "performance background hidden")
	main._toggle_settings_panel()
	var panel = main.runtime.hud_ref("settings_panel")
	t.that(panel.visible, "settings button opens the real panel")
	var checkbox: CheckButton = panel.get_node("PanelMargin/MainVBox/PerformanceCheck")
	t.that(not checkbox.button_pressed, "panel reloads saved preference")
	checkbox.button_pressed = true
	t.that(RuntimeHudController.performance_visible, "panel signal applies performance=true")
	t.that(main.runtime.hud_ref("fps_label").visible, "performance label visible after toggle")
	t.that(bool(PlayerSettingsStore.load_settings()["show_performance_info"]), "panel choice persisted")
	main.queue_free()
	await _flush()


# === P3: Hide the event log without deleting event evidence ===
func _test_event_log_toggle(t: TestAssert) -> void:
	print("  [P3] event log visibility preserves history")
	var prefs := PlayerSettingsStore.default_settings()
	prefs["show_event_log"] = false
	PlayerSettingsStore.save_settings(prefs)
	var main = load("res://scripts/Main.gd").new()
	get_root().add_child(main)
	main.selected_save_slot = 9
	main._start_game(20, true, false)
	await _flush()
	var ec = main.runtime.event_controller
	t.that(ec != null, "real game creates event controller")
	if ec != null:
		t.eq(ec.get("event_log_visible"), false, "saved event visibility applied")
		t.eq(ec.get_event_log_text(), "", "hidden event log text not exposed")
		t.that(not main.runtime.hud_ref("event_log_label").visible, "log label hidden")
		var history_before: int = ec.event_history.size()
		ec._finish_event_round({
			"faction_id": GameConfig.Faction.BLUE,
			"faction_name": "蓝方",
			"final_effect": EventRouletteController.EFFECT_BONUS_10,
			"result_text": "蓝方：本次 +10！",
		})
		t.that(ec.event_history.size() > history_before, "hidden events still recorded")
		var recorded: int = ec.event_history.size()
		main._toggle_settings_panel()
		var panel = main.runtime.hud_ref("settings_panel")
		var checkbox: CheckButton = panel.get_node("PanelMargin/MainVBox/EventLogCheck")
		checkbox.button_pressed = true
		t.eq(ec.get("event_log_visible"), true, "panel signal enables event log")
		t.that(not ec.get_event_log_text().is_empty(), "recorded history visible after enable")
		t.that(main.runtime.hud_ref("event_log_label").visible, "event label visible")
		t.eq(ec.event_history.size(), recorded, "visibility toggle does not alter history")
		t.that(bool(PlayerSettingsStore.load_settings()["show_event_log"]), "event visibility persisted")
		var log_label = main.runtime.hud_ref("event_log_label")
		var log_toggle = main.runtime.hud_ref("event_log_toggle_btn")
		log_toggle.pressed.emit()
		t.that(not log_label.visible, "HUD toggle collapses enabled event log")
		var perf: CheckButton = panel.get_node("PanelMargin/MainVBox/PerformanceCheck")
		perf.button_pressed = not perf.button_pressed
		t.that(not log_label.visible, "performance preference preserves manual collapse")
		var low: CheckButton = panel.get_node("PanelMargin/MainVBox/LowEffectCheck")
		low.button_pressed = not low.button_pressed
		t.that(not log_label.visible, "low-effect preference preserves manual collapse")
		t.eq(ec.get("event_log_visible"), true, "manual collapse does not disable event history")
		checkbox.button_pressed = false
		checkbox.button_pressed = true
		t.that(log_label.visible, "explicit event preference change shows the log again")
		t.eq(ec.event_history.size(), recorded, "collapse and preference edits preserve history")
	_cleanup_save_slot(9)
	main.queue_free()
	await _flush()


# === P4: Result panel ===
func _test_result_panel(t: TestAssert) -> void:
	print("  [P4] result panel")

	var panel = ResultScene.instantiate()
	get_root().add_child(panel)
	await process_frame

	t.that(not panel.visible, "starts hidden")

	panel.show_result({
		"winner_name": "海方",
		"winner_color": Color(0.2, 0.49, 1.0),
		"reason_text": "击败全部对手",
		"duration_seconds": 222.0,
		"occupation_rates": {
			GameConfig.Faction.BLUE: 0.48,
			GameConfig.Faction.RED: 0.22,
			GameConfig.Faction.GREEN: 0.18,
			GameConfig.Faction.YELLOW: 0.12,
		},
		"peak_active_bullets": 126,
		"event_count": 8,
	})

	t.that(panel.visible, "visible after show_result")
	t.that(panel.title_label.text.containsn("海方"), "title contains winner name")
	t.that(panel.reason_label.text.containsn("击败全部对手"), "reason label correct")
	t.that(panel.duration_label.text.containsn("03:42"), "duration formatted 03:42")
	t.that(panel.occupation_label.text.containsn("48%"), "occupation shows 48%")
	t.that(panel.stats_label.text.containsn("126"), "stats shows peak bullets")
	t.that(panel.stats_label.text.containsn("8"), "stats shows event count")

	panel.queue_free()
	await process_frame


func _cleanup_save_slot(slot: int) -> void:
	for ext in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path("user://ballwar_save_slot_%d.save%s" % [slot, ext])
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
