extends Node2D

var battlefield: Battlefield
var bullet_container: Node2D
var turrets: Dictionary = {}
var score_label: Label

func _ready() -> void:
	randomize()
	_create_background()
	_create_battlefield()
	_create_turrets()
	_create_control_chambers()
	_create_ui()

func _create_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1,0.11,0.13)
	bg.size = Vector2(1200, 820)
	bg.z_index = -100
	add_child(bg)

func _create_battlefield() -> void:
	battlefield = Battlefield.new()
	battlefield.position = GameConfig.BATTLEFIELD_ORIGIN
	battlefield.scores_changed.connect(_on_scores_changed)
	add_child(battlefield)
	bullet_container = Node2D.new()
	bullet_container.name = "BulletContainer"
	add_child(bullet_container)

func _create_turrets() -> void:
	var s := GameConfig.GRID_SIZE * GameConfig.CELL_SIZE
	var m := 30.0
	var positions := {
		GameConfig.Faction.BLUE: GameConfig.BATTLEFIELD_ORIGIN + Vector2(m, m),
		GameConfig.Faction.RED: GameConfig.BATTLEFIELD_ORIGIN + Vector2(s - m, m),
		GameConfig.Faction.GREEN: GameConfig.BATTLEFIELD_ORIGIN + Vector2(m, s - m),
		GameConfig.Faction.YELLOW: GameConfig.BATTLEFIELD_ORIGIN + Vector2(s - m, s - m),
	}
	for fid in positions.keys():
		var t := Turret.new()
		t.setup(fid, positions[fid], battlefield, bullet_container)
		t.name = "Turret_%s" % GameConfig.faction_name(fid)
		add_child(t)
		turrets[fid] = t

func _create_control_chambers() -> void:
	var positions := {
		GameConfig.Faction.BLUE: Vector2(60, 70),
		GameConfig.Faction.RED: Vector2(990, 70),
		GameConfig.Faction.GREEN: Vector2(60, 530),
		GameConfig.Faction.YELLOW: Vector2(990, 530),
	}
	for fid in positions.keys():
		var c := ControlChamber.new()
		c.setup(fid, positions[fid])
		c.name = "Chamber_%s" % GameConfig.faction_name(fid)
		c.release_requested.connect(_on_chamber_release_requested)
		add_child(c)

func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	score_label = Label.new()
	score_label.position = Vector2(360, 20)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(score_label)
	var title := Label.new()
	title.position = Vector2(360, 52)
	title.text = "Marble Dominion MVP - external chambers trigger turret bursts"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.85,0.85,0.85))
	canvas.add_child(title)
	_on_scores_changed(battlefield.count_cells_by_team())

func _on_chamber_release_requested(faction_id: int, bullet_count: int) -> void:
	if turrets.has(faction_id): turrets[faction_id].fire_burst(bullet_count)

func _on_scores_changed(counts: Dictionary) -> void:
	if score_label == null: return
	var parts: Array[String] = []
	for fid in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		parts.append("%s: %d" % [GameConfig.faction_name(fid), counts.get(fid, 0)])
	score_label.text = " | ".join(parts)
