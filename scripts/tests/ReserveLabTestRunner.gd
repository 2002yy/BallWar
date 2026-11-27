extends SceneTree

class LabMain extends "res://scripts/Main.gd":
	func _reserve_lab_requested() -> bool:
		return true

const BLUE := GameConfig.Faction.BLUE
const RED := GameConfig.Faction.RED

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := TestAssert.new()
	var flag := PackedStringArray(["--reserve-lab"])
	t.that(ReserveLab.is_requested(true, flag), "debug build honors the explicit launch flag")
	t.that(not ReserveLab.is_requested(false, flag), "release build ignores the launch flag")
	t.that(not ReserveLab.is_requested(true, PackedStringArray()), "debug defaults to the ordinary entry")
	var original_files := _profile_hashes()
	var main := LabMain.new()
	root.add_child(main)
	main.audio_manager.set_enabled(false)
	t.eq(main.menu_layer, null, "experiment enters battle directly")
	t.eq(main.match_seed, 7341, "default experiment seed is reproducible")
	t.that(not main._hud_ref("settings_button").visible, "experiment exposes no settings writer")
	t.eq(main._hud_ref("settings_panel"), null, "experiment never instantiates the player settings panel")
	var economy: ReserveEconomy = main.runtime.reserve_economy
	var lab: ReserveLab = main.game_layer.get_node("ReserveLab")
	var control_ball: Button = lab.find_child("BuyBall", true, false)
	var blast: Button = lab.find_child("BuyBlast", true, false)
	var drop: Button = lab.find_child("DropFixture", true, false)
	t.that(control_ball.disabled and blast.disabled and not drop.disabled, "empty reserve disables both purchases")

	drop.pressed.emit()
	t.eq(economy.balance(BLUE), 0, "fixture queues a landing without directly crediting reserve")
	await physics_frame
	await physics_frame
	lab._refresh()
	t.eq(economy.balance(BLUE), 200, "real physics step credits reserve through the gate")
	t.that("200" in lab._balances.text, "readout displays the credited reserve")
	t.that(not control_ball.disabled and not blast.disabled, "balance enables affordable items")
	var chamber: ControlChamber = main.runtime.chambers[BLUE]
	control_ball.pressed.emit()
	t.eq(chamber.get_ball_count(), 2, "buy button applies the real add-ball effect")
	t.eq(economy.balance(BLUE), 100, "buying a ball debits 100")
	t.that(blast.disabled, "blast becomes unaffordable")
	drop.pressed.emit()
	await physics_frame
	await physics_frame
	lab._refresh()
	t.eq(economy.balance(BLUE), 300, "second gate landing makes blast affordable")
	var field: Battlefield = main.runtime.battlefield
	var owned_before: int = field.count_cells_by_team()[BLUE]
	blast.pressed.emit()
	t.that(field.count_cells_by_team()[BLUE] > owned_before, "blast button applies the real territory effect")
	t.eq(economy.balance(BLUE), 100, "blast debits 200")

	var factions: OptionButton = lab.find_child("Faction", true, false)
	var index := factions.get_item_index(RED)
	factions.select(index)
	factions.item_selected.emit(index)
	drop.pressed.emit()
	await physics_frame
	await physics_frame
	t.eq(economy.balance(RED), 200, "faction selector routes fixture to the selected faction")
	t.eq(economy.balance(BLUE), 100, "other faction balance is separate")

	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F8
	toggle.pressed = true
	lab._input(toggle)
	t.that(not lab._panel.visible, "F8 hides the panel")
	lab._input(toggle)
	t.that(lab._panel.visible, "F8 restores the panel")
	main._toggle_pause()
	lab._refresh()
	t.that(paused and control_ball.disabled and blast.disabled and drop.disabled, "pause freezes experiment tools")
	t.eq(_profile_hashes(), original_files, "experiment pause preserves the selected slot and both settings files")
	main._toggle_pause()

	var restart: Button = lab.find_child("Restart", true, false)
	restart.pressed.emit()
	await process_frame
	await process_frame
	t.that(main.runtime.reserve_economy != economy, "restart replaces the ledger")
	t.eq(main.runtime.reserve_economy.balance(BLUE), 0, "restart clears reserve")
	t.eq(main.runtime.chambers[BLUE].get_ball_count(), 1, "restart recreates control balls")
	t.eq(main.runtime.battlefield.count_cells_by_team()[BLUE], owned_before, "restart restores the initial territory")
	t.eq(_profile_hashes(), original_files, "restart preserves the selected slot and both settings files")
	main.queue_free()
	await process_frame
	t.report("ReserveLabTestRunner")
	quit(0 if t.failures.is_empty() else 1)

func _profile_hashes() -> Dictionary:
	var hashes := {}
	for path in ["user://ballwar_save_slot_1.save", "user://player_settings.json", "user://menu_preferences.json"]:
		hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	return hashes
