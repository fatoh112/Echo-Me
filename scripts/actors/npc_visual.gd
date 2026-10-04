extends Node3D
class_name NPCVisual

var piece_count := 0

func build(npc_id: String) -> void:
	var style: Dictionary = WorldVisualConfig.NPC_STYLE.get(npc_id, WorldVisualConfig.NPC_STYLE["mike"])
	var height := float(style["height"])
	var width := float(style["width"])
	var coat := str(style["coat"])
	var trim := str(style["trim"])
	var builder := TownGeometry.new(self)
	for side in [-1.0, 1.0]:
		var leg_x: float = side * (0.14 if npc_id != "david" else 0.19)
		builder.box(Vector3(leg_x, 0.09, 0.04), Vector3(0.20, 0.18, 0.33), "wood")
		builder.cylinder(Vector3(leg_x, height * 0.26, 0), 0.18, height * 0.36, "charcoal")
	builder.cylinder(Vector3(0, height * 0.51, 0), width * 1.1, height * 0.24, coat)
	builder.box(Vector3(0, height * 0.66, 0), Vector3(width, height * 0.31, 0.32), coat)
	builder.box(Vector3(0, height * 0.53, 0.18), Vector3(width * 1.08, 0.09, 0.05), "wood")
	for side in [-1.0, 1.0]:
		builder.beam(Vector3(side * width * 0.55, height * 0.77, 0), Vector3(side * (width * 0.64 + 0.04), height * 0.47, 0.035), 0.16, coat)
		builder.sphere(Vector3(side * (width * 0.64 + 0.04), height * 0.43, 0.035), Vector3(0.14, 0.18, 0.14), "skin")
	builder.cylinder(Vector3(0, height * 0.81, 0), 0.12, 0.15, "skin")
	builder.sphere(Vector3(0, height * 0.91, 0), Vector3(0.27, height * 0.18, 0.28), "skin")
	builder.sphere(Vector3(0, height * 0.91, 0.145), Vector3(0.055, 0.07, 0.05), "skin")
	for side in [-1.0, 1.0]:
		builder.box(Vector3(side * 0.054, height * 0.94, 0.13), Vector3(0.035, 0.025, 0.025), "charcoal")
	if bool(style.get("apron", false)):
		builder.box(Vector3(0, height * 0.55, 0.195), Vector3(width * 0.68, height * 0.38, 0.025), trim)
	if bool(style.get("skirt", false)):
		builder.cylinder(Vector3(0, height * 0.35, 0), width * 1.13, height * 0.30, coat)
	if bool(style.get("hat", false)):
		builder.cylinder(Vector3(0, height * 0.997, 0), 0.39, 0.055, trim)
		builder.cylinder(Vector3(0, height * 1.04, 0), 0.27, 0.14, coat)
	if bool(style.get("hair", false)):
		builder.sphere(Vector3(0, height * 0.965, -0.045), Vector3(0.30, 0.19, 0.24), "wood")
	if bool(style.get("hood", false)):
		builder.sphere(Vector3(0, height * 0.97, -0.07), Vector3(0.36, 0.27, 0.30), "charcoal")
		builder.box(Vector3(0, height * 0.7, -0.20), Vector3(width * 1.2, height * 0.44, 0.06), trim)
	if bool(style.get("guard", false)):
		builder.box(Vector3(0, height * 0.69, 0.18), Vector3(width * 0.72, height * 0.22, 0.06), trim)
		builder.cylinder(Vector3(0, height * 1.005, 0), 0.32, 0.19, "metal")
		builder.box(Vector3(0, height * 0.72, 0.22), Vector3(0.05, height * 0.20, 0.025), "cream")
	builder.flush()
	piece_count = builder.instance_count
