extends Node
class_name EventRouletteController

signal event_round_started(payload)
signal event_round_finished(payload)

const EFFECT_REROLL: String = "reroll"
const EFFECT_BONUS_10: String = "bonus_10"
const EFFECT_X2: String = "x2"
const EFFECT_X3: String = "x3"
const EFFECT_ADD_BALL: String = "add_ball"
const EFFECT_JAM: String = "jam"

const JAM_DURATION: float = 5.0
const JAM_REFUND_RATIO: float = 0.25
const OCCUPATION_SPEEDUP_PERCENT: int = 65
const MAX_REROLL_COUNT: int = 2

var main_ref = null
var battlefield = null
var chambers: Dictionary = {}
var turrets: Dictionary = {}
var event_label = null
var view_ref = null

var event_roulette_enabled: bool = true
var next_event_time_left: float = 0.0
var current_event_interval: float = 0.0
var last_event_faction: int = -1
var last_event_effect: String = ""
var reroll_count: int = 0
var is_presenting_event: bool = false

var _pending_payload: Dictionary = {}

func setup(new_main_ref, new_battlefield, new_chambers: Dictionary, new_turrets: Dictionary, new_event_label, new_view_ref) -> void:
	main_ref = new_main_ref
	battlefield = new_battlefield
	chambers = new_chambers
	turrets = new_turrets
	event_label = new_event_label
	view_ref = new_view_ref
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if view_ref != null and is_instance_valid(view_ref):
		var finished_callable: Callable = Callable(self, "_on_view_presentation_finished")
		if not view_ref.presentation_finished.is_connected(finished_callable):
			view_ref.presentation_finished.connect(finished_callable)

	reset_for_new_game()

func reset_for_new_game() -> void:
	event_roulette_enabled = true
	next_event_time_left = _compute_initial_delay()
	current_event_interval = _compute_current_interval()
	last_event_faction = -1
	last_event_effect = ""
	reroll_count = 0
	is_presenting_event = false
	_pending_payload.clear()
	_update_event_label()

func _process(delta: float) -> void:
	if not event_roulette_enabled:
		_update_event_label()
		return
	if main_ref == null or battlefield == null or main_ref.is_game_over:
		_update_event_label()
		return
	if is_presenting_event:
		_update_event_label()
		return

	next_event_time_left = maxf(0.0, next_event_time_left - delta)
	if next_event_time_left <= 0.0:
		_start_event_round()
	_update_event_label()

func export_save_state() -> Dictionary:
	return {
		"event_roulette_enabled": event_roulette_enabled,
		"next_event_time_left": next_event_time_left,
		"current_event_interval": current_event_interval,
		"last_event_faction": last_event_faction,
		"last_event_effect": last_event_effect,
		"reroll_count": reroll_count,
	}

func import_save_state(data: Dictionary) -> void:
	event_roulette_enabled = bool(data.get("event_roulette_enabled", true))
	next_event_time_left = maxf(0.1, float(data.get("next_event_time_left", _compute_initial_delay())))
	current_event_interval = maxf(0.0, float(data.get("current_event_interval", _compute_current_interval())))
	last_event_faction = int(data.get("last_event_faction", -1))
	last_event_effect = str(data.get("last_event_effect", ""))
	reroll_count = clampi(int(data.get("reroll_count", 0)), 0, MAX_REROLL_COUNT)
	is_presenting_event = false
	_pending_payload.clear()
	_update_event_label()

func _start_event_round() -> void:
	var resolved: Dictionary = _resolve_event_result()
	if resolved.is_empty():
		_schedule_next_event()
		return

	_pending_payload = resolved
	is_presenting_event = true
	event_round_started.emit(resolved)

	if view_ref != null and is_instance_valid(view_ref):
		view_ref.play_event(resolved)
	else:
		_apply_resolved_event(resolved)
		_finish_event_round(resolved)

func _resolve_event_result() -> Dictionary:
	var effect_sequence: Array = []
	var final_effect: String = _roll_effect_sequence(effect_sequence)
	if final_effect == "":
		return {}

	var faction_id: int = _choose_faction_for_effect(final_effect)
	if faction_id == -1:
		return {}

	return {
		"faction_id": faction_id,
		"faction_name": _faction_display_name(faction_id),
		"faction_items": ["蓝方", "红方", "绿方", "黄方"],
		"faction_color": GameConfig.faction_color(faction_id),
		"effect_sequence": effect_sequence,
		"effect_items": ["重转", "本次 +10", "本次 x2", "本次 x3", "加 1 球", "控制仓短路"],
		"final_effect": final_effect,
		"final_effect_index": _effect_item_index(final_effect),
		"final_effect_name": _effect_display_name(final_effect),
		"result_text": _result_display_text(faction_id, final_effect),
		"grid_size": main_ref.selected_grid_size if main_ref != null else 40,
	}

func _roll_effect_sequence(out_sequence: Array) -> String:
	reroll_count = 0
	out_sequence.clear()

	while true:
		var effect_name: String = _random_effect()
		out_sequence.append(effect_name)
		if effect_name != EFFECT_REROLL:
			return effect_name

		reroll_count += 1
		if reroll_count > MAX_REROLL_COUNT:
			out_sequence.append(EFFECT_BONUS_10)
			return EFFECT_BONUS_10

	return EFFECT_BONUS_10

func _apply_resolved_event(payload: Dictionary) -> void:
	var faction_id: int = int(payload.get("faction_id", -1))
	var final_effect: String = str(payload.get("final_effect", ""))
	if faction_id == -1 or final_effect == "":
		return

	var chamber = chambers.get(faction_id, null)
	if chamber == null or not is_instance_valid(chamber):
		return

	match final_effect:
		EFFECT_BONUS_10:
			_apply_positive_modifier(chamber, {"type": EFFECT_BONUS_10, "amount": 10})
		EFFECT_X2:
			_apply_positive_modifier(chamber, {"type": EFFECT_X2, "multiplier": 2})
		EFFECT_X3:
			_apply_positive_modifier(chamber, {"type": EFFECT_X3, "multiplier": 3})
		EFFECT_ADD_BALL:
			_apply_positive_modifier(chamber, {"type": EFFECT_ADD_BALL})
		EFFECT_JAM:
			chamber.cancel_current_burst_with_refund(JAM_REFUND_RATIO)
			chamber.apply_jammed(JAM_DURATION)

	last_event_faction = faction_id
	last_event_effect = final_effect

	if main_ref != null:
		var banner_title: String = "控制仓短路" if final_effect == EFFECT_JAM else "事件转盘"
		main_ref._show_center_banner(
			banner_title,
			_result_display_text(faction_id, final_effect),
			GameConfig.faction_color(faction_id).lightened(0.28),
			true
		)
		for candidate_id in chambers.keys():
			main_ref._refresh_add_ball_button(int(candidate_id))

func _apply_positive_modifier(chamber, modifier: Dictionary) -> void:
	if chamber == null:
		return
	if chamber.is_locked:
		chamber.queue_next_round_modifier(modifier)
		return

	var modifier_type: String = str(modifier.get("type", ""))
	if modifier_type == EFFECT_BONUS_10:
		chamber.apply_pending_bonus(int(modifier.get("amount", 10)))
	elif modifier_type == EFFECT_X2 or modifier_type == EFFECT_X3:
		chamber.apply_pending_multiplier(int(modifier.get("multiplier", 1)))
	elif modifier_type == EFFECT_ADD_BALL:
		chamber.add_control_ball_from_event()

func _finish_event_round(payload: Dictionary) -> void:
	is_presenting_event = false
	_pending_payload.clear()
	_schedule_next_event()
	event_round_finished.emit(payload)
	_update_event_label()

func _schedule_next_event() -> void:
	current_event_interval = _compute_current_interval()
	next_event_time_left = current_event_interval

func _compute_initial_delay() -> float:
	var mode_name: String = GameConfig.get_game_mode_name()
	if mode_name == GameConfig.GAME_MODE_BASIC:
		return 60.0
	if mode_name == GameConfig.GAME_MODE_OCCUPATION:
		return 30.0
	if mode_name == GameConfig.GAME_MODE_TIMED:
		return 30.0
	if mode_name == GameConfig.GAME_MODE_WILD:
		return 20.0
	return 45.0

func _compute_current_interval() -> float:
	var mode_name: String = GameConfig.get_game_mode_name()
	if mode_name == GameConfig.GAME_MODE_BASIC:
		return 60.0
	if mode_name == GameConfig.GAME_MODE_OCCUPATION:
		return 30.0 if _current_leader_percent() >= OCCUPATION_SPEEDUP_PERCENT else 40.0
	if mode_name == GameConfig.GAME_MODE_TIMED:
		var remain: float = maxf(0.0, GameConfig.get_time_limit_seconds() - _elapsed_time())
		if remain <= 60.0:
			return 20.0
		if remain <= 120.0:
			return 30.0
		return 45.0
	if mode_name == GameConfig.GAME_MODE_WILD:
		return randf_range(20.0, 30.0)
	return 45.0

func _choose_faction_for_effect(effect_name: String) -> int:
	var candidate_factions: Array = []
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var chamber = chambers.get(faction_id, null)
		var turret = turrets.get(faction_id, null)
		if chamber == null or turret == null:
			continue
		if not is_instance_valid(chamber) or not is_instance_valid(turret):
			continue
		if chamber.is_damaged or turret.is_destroyed:
			continue
		candidate_factions.append(faction_id)

	if candidate_factions.is_empty():
		return -1

	var ranks: Dictionary = _rank_factions(candidate_factions)
	var total_weight: float = 0.0
	var weights: Array = []
	for faction_id in candidate_factions:
		var rank: int = int(ranks.get(faction_id, 2))
		var weight: float = _weight_for_effect_rank(effect_name, rank)
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0.0:
		return int(candidate_factions[0])

	var roll: float = randf() * total_weight
	for i in range(candidate_factions.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			return int(candidate_factions[i])
	return int(candidate_factions[candidate_factions.size() - 1])

func _rank_factions(candidate_factions: Array) -> Dictionary:
	var scored: Array = []
	for faction_id in candidate_factions:
		scored.append({
			"faction_id": int(faction_id),
			"score": int(main_ref.current_score_counts.get(faction_id, 0)),
		})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			return int(a.get("faction_id", 0)) < int(b.get("faction_id", 0))
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)

	var result: Dictionary = {}
	for i in range(scored.size()):
		result[int(scored[i].get("faction_id", 0))] = i + 1
	return result

func _weight_for_effect_rank(effect_name: String, rank: int) -> float:
	var positive_weights: Dictionary = {1: 0.8, 2: 1.0, 3: 1.15, 4: 1.3}
	var negative_weights: Dictionary = {1: 1.3, 2: 1.15, 3: 1.0, 4: 0.8}
	if effect_name == EFFECT_JAM:
		return float(negative_weights.get(rank, 1.0))
	if effect_name == EFFECT_REROLL:
		return 1.0
	return float(positive_weights.get(rank, 1.0))

func _effect_display_name(effect_name: String) -> String:
	match effect_name:
		EFFECT_REROLL:
			return "重转"
		EFFECT_BONUS_10:
			return "本次 +10"
		EFFECT_X2:
			return "本次 x2"
		EFFECT_X3:
			return "本次 x3"
		EFFECT_ADD_BALL:
			return "加 1 球"
		EFFECT_JAM:
			return "控制仓短路"
		_:
			return effect_name

func _effect_hud_short_text(effect_name: String) -> String:
	match effect_name:
		EFFECT_BONUS_10:
			return "+10"
		EFFECT_X2:
			return "x2"
		EFFECT_X3:
			return "x3"
		EFFECT_ADD_BALL:
			return "+1球"
		EFFECT_JAM:
			return "短路"
		EFFECT_REROLL:
			return "重转"
		_:
			return effect_name

func _result_display_text(faction_id: int, effect_name: String) -> String:
	var faction_name: String = _faction_display_name(faction_id)
	if effect_name == EFFECT_JAM:
		return "%s：控制仓短路 5 秒！" % faction_name
	return "%s：%s！" % [faction_name, _effect_display_name(effect_name)]

func _effect_item_index(effect_name: String) -> int:
	match effect_name:
		EFFECT_REROLL:
			return 0
		EFFECT_BONUS_10:
			return 1
		EFFECT_X2:
			return 2
		EFFECT_X3:
			return 3
		EFFECT_ADD_BALL:
			return 4
		EFFECT_JAM:
			return 5
		_:
			return 1

func _faction_display_name(faction_id: int) -> String:
	match faction_id:
		GameConfig.Faction.BLUE:
			return "蓝方"
		GameConfig.Faction.RED:
			return "红方"
		GameConfig.Faction.GREEN:
			return "绿方"
		GameConfig.Faction.YELLOW:
			return "黄方"
		_:
			return "未知"

func _random_effect() -> String:
	var effects: Array = [
		EFFECT_REROLL,
		EFFECT_BONUS_10,
		EFFECT_X2,
		EFFECT_X3,
		EFFECT_ADD_BALL,
		EFFECT_JAM,
	]
	return str(effects[randi() % effects.size()])

func _elapsed_time() -> float:
	if main_ref == null:
		return 0.0
	return maxf(0.0, float(main_ref.game_elapsed_time))

func _current_leader_percent() -> int:
	var total: int = 0
	var best_count: int = 0
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var count: int = int(main_ref.current_score_counts.get(faction_id, 0))
		total += count
		best_count = maxi(best_count, count)
	if total <= 0:
		return 0
	return int(round(float(best_count) * 100.0 / float(total)))

func _update_event_label() -> void:
	if event_label == null or not is_instance_valid(event_label):
		return

	var event_text: String = "无"
	if is_presenting_event and not _pending_payload.is_empty():
		event_text = "转盘中"
	elif last_event_faction != -1 and last_event_effect != "":
		event_text = "%s %s" % [_faction_display_name(last_event_faction), _effect_hud_short_text(last_event_effect)]

	event_label.text = "事件：%s | 下次 %s" % [
		event_text,
		"--:--" if is_presenting_event else RuntimeHudController.format_time_text(next_event_time_left),
	]

func _on_view_presentation_finished(_payload_from_view: Dictionary) -> void:
	if _pending_payload.is_empty():
		return
	_apply_resolved_event(_pending_payload)
	_finish_event_round(_pending_payload)
