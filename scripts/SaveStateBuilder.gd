extends RefCounted
class_name SaveStateBuilder

static func build_faction_states(chambers: Dictionary, turrets: Dictionary) -> Array:
	var factions: Array = []
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var chamber = chambers.get(faction_id)
		var turret = turrets.get(faction_id)
		factions.append({
			"faction_id": faction_id,
			"chamber_pending_count": chamber.pending_count if chamber != null else 1,
			"chamber_locked_remaining": chamber.locked_remaining if chamber != null else 0,
			"chamber_is_locked": chamber.is_locked if chamber != null else false,
			"chamber_is_damaged": chamber.is_damaged if chamber != null else false,
			"chamber_ball_count": chamber.get_ball_count() if chamber != null else 0,
			"chamber_release_ball_index": SaveGameCodec.get_release_ball_index(chamber),
			"chamber_jammed_time_left": chamber.get_jammed_time_left() if chamber != null else 0.0,
			"queued_round_modifiers": chamber.get_queued_round_modifiers() if chamber != null else [],
			"control_balls": SaveGameCodec.collect_control_ball_states(chamber),
			"turret_health": turret.health if turret != null else GameConfig.TURRET_MAX_HEALTH,
			"turret_destroyed": turret.is_destroyed if turret != null else false,
			"turret_sweep_phase": turret.sweep_phase if turret != null else 0.0,
			"turret_rotation": turret.rotation if turret != null else 0.0,
			"turret_burst_remaining": turret.burst_remaining if turret != null else 0,
			"turret_burst_total": turret.burst_total if turret != null else 0,
			"turret_burst_index": turret.burst_index if turret != null else 0,
			"turret_burst_timer": turret.burst_timer if turret != null else 0.0,
			"turret_burst_locked": turret.burst_locked if turret != null else false,
		})
	return factions

static func build_save_payload(chambers: Dictionary, turrets: Dictionary, battlefield, bullet_container, event_roulette_controller, game_elapsed_time: float, is_game_over: bool, selected_save_slot: int, winner_label) -> Dictionary:
	return {
		"save_version": SaveGameCodec.get_current_save_version(),
		"save_slot": selected_save_slot,
		"grid_size": battlefield.grid_size,
		"palette_name": GameConfig.get_palette_name(),
		"quality_name": GameConfig.get_quality_name(),
		"game_mode_name": GameConfig.get_game_mode_name(),
		"time_limit_minutes": GameConfig.get_time_limit_minutes(),
		"owners": battlefield.owners,
		"game_elapsed_time": game_elapsed_time,
		"is_game_over": is_game_over,
		"factions": build_faction_states(chambers, turrets),
		"bullets": SaveGameCodec.collect_bullet_states(bullet_container),
		"winner_text": winner_label.text if winner_label != null else "",
		"event_state": event_roulette_controller.export_save_state() if event_roulette_controller != null else {},
	}
