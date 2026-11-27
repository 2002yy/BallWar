extends SceneTree

# Coordinate semantics probe. Answers one question that decides the whole
# display-transform architecture: does a scaled Node2D parent change what a
# child reports as global_position, and does a CanvasLayer transform?
#
# Run: godot --headless --path . --script res://tools/tests/coord_semantics_probe.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== A. plain Node2D parent with scale 1.45, translated ===")
	var holder := Node2D.new()
	root.add_child(holder)
	holder.transform = Transform2D(0.0, Vector2(1.45, 1.45), 0.0, Vector2(80.0, 13.0))
	var child := Node2D.new()
	holder.add_child(child)
	child.position = Vector2(100.0, 100.0)
	print("  child.position        = ", child.position)
	print("  child.global_position = ", child.global_position)
	var moved := child.global_position + Vector2(3.0, 0.0)
	print("  +3 global px -> local displacement = ", (child.get_parent() as Node2D).to_local(moved) - child.position)

	print("=== B. CanvasLayer with the same transform, child Node2D inside ===")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.transform = Transform2D(0.0, Vector2(1.45, 1.45), 0.0, Vector2(80.0, 13.0))
	var child2 := Node2D.new()
	layer.add_child(child2)
	child2.position = Vector2(100.0, 100.0)
	print("  child.position        = ", child2.position)
	print("  child.global_position = ", child2.global_position)
	print("  child.global_transform.origin = ", child2.global_transform.origin)

	print("=== C. CanvasLayer child: does to_local of a sibling see the scale? ===")
	var bf := Node2D.new()
	layer.add_child(bf)
	bf.position = Vector2.ZERO
	var p := bf.to_local(child2.global_position)
	print("  battlefield.to_local(child.global_position) = ", p)

	quit(0)
