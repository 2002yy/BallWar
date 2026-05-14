extends RefCounted
class_name RestorePlan

var source_data: Dictionary = {}
var owners_data: Array = []
var faction_states: Array = []
var event_state: Dictionary = {}
var bullet_states: Array = []
var game_over_state: Dictionary = {}

static func build_from_clean_data(data: Dictionary) -> RestorePlan:
	var plan := RestorePlan.new()
	plan.source_data = data.duplicate(true)

	var owners = data.get("owners", [])
	plan.owners_data = owners.duplicate(true) if owners is Array else []

	var factions = data.get("factions", [])
	plan.faction_states = factions.duplicate(true) if factions is Array else []

	var event_data = data.get("event_state", {})
	plan.event_state = event_data.duplicate(true) if event_data is Dictionary else {}

	var bullets = data.get("bullets", [])
	plan.bullet_states = bullets.duplicate(true) if bullets is Array else []

	plan.game_over_state = {
		"is_game_over": bool(data.get("is_game_over", false)),
		"winner_text": str(data.get("winner_text", "")),
	}
	return plan

func to_restore_dictionary() -> Dictionary:
	var data: Dictionary = source_data.duplicate(true)
	data["owners"] = owners_data.duplicate(true)
	data["factions"] = faction_states.duplicate(true)
	data["event_state"] = event_state.duplicate(true)
	data["bullets"] = bullet_states.duplicate(true)
	data["is_game_over"] = bool(game_over_state.get("is_game_over", false))
	data["winner_text"] = str(game_over_state.get("winner_text", ""))
	return data
