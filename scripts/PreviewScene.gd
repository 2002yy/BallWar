extends Node2D
class_name PreviewSceneView

# 主菜单预览的阵营注入点。
#
# 角落由节点名决定，阵营 ID 由 LayoutCoordinator.corner_factions() 提供，
# 颜色由各渲染器在 _draw() 里实时调用 GameConfig.faction_color(id) 取得。
# 这样预览与正式战斗共享「阵营 ID / 角落映射 / 调色板」同一份数据定义，
# 但不共享渲染实现（本批不强制复用 A1 renderer）。
#
# 没有本地颜色表，也没有颜色缓存：切换调色板后调用 apply_faction_ids()
# 触发重绘就会跟随。M01-I2 之前的版本把四种颜色硬编码在 .tscn 里，
# 导致预览四角排成 红/黄/绿/蓝，与战斗的 蓝/红/绿/黄 不一致。

const CORNER_NODES := {
	"top_left": ["ChamberTopLeft", "TurretTopLeft"],
	"top_right": ["ChamberTopRight", "TurretTopRight"],
	"bottom_left": ["ChamberBottomLeft", "TurretBottomLeft"],
	"bottom_right": ["ChamberBottomRight", "TurretBottomRight"],
}


func _ready() -> void:
	apply_faction_ids()


func apply_faction_ids() -> void:
	var factions := LayoutCoordinator.corner_factions()
	for key in LayoutCoordinator.CORNER_KEYS:
		var faction_id: int = int(factions[key])
		for node_name in CORNER_NODES[key]:
			var part: Node = get_node_or_null(NodePath(str(node_name)))
			if part == null:
				continue
			part.set("faction_id", faction_id)
			if part is CanvasItem:
				(part as CanvasItem).queue_redraw()
	var order := LayoutCoordinator.corner_faction_order()
	for part_name in ["Board", "Chassis"]:
		var part: Node = get_node_or_null(part_name)
		if part == null:
			continue
		part.set("corner_faction_ids", order.duplicate())
		if part is CanvasItem:
			(part as CanvasItem).queue_redraw()
