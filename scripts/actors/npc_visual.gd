extends Node3D
class_name NPCVisual

const NPC_MODELS: Dictionary = {
	"alex": preload("res://assets/characters/npcs/medieval_people/Free Medieval 3D People Low Poly Pack/fbx/unral_better_export/rich_citizens_2.fbx"),
	"sarah": preload("res://assets/characters/npcs/medieval_people/Free Medieval 3D People Low Poly Pack/fbx/unral_better_export/peasant_2.fbx"),
	"mike": preload("res://assets/characters/npcs/medieval_people/Free Medieval 3D People Low Poly Pack/fbx/unral_better_export/city_dwellers_1.fbx"),
	"emma": preload("res://assets/characters/npcs/medieval_people/Free Medieval 3D People Low Poly Pack/fbx/unral_better_export/peasant_5.fbx"),
	"david": preload("res://assets/characters/npcs/medieval_people/Free Medieval 3D People Low Poly Pack/fbx/unral_better_export/rich_citizens_3.fbx"),
	"noah": preload("res://assets/characters/npcs/medieval_people/Free Medieval 3D People Low Poly Pack/fbx/unral_better_export/king.fbx"),
}

var piece_count := 0
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var _humanoid: Node3D
@export var humanoid_scene: PackedScene
var _animation_active := false
var _npc_id := ""
var locomotion_state := "IDLE"
const NPC_LOCOMOTION: AnimationLibrary = preload("res://assets/animations/npcs/npc_locomotion.res")

# Optional model presentation hooks. NPCController knows only this interface.
func replace_model(scene: PackedScene) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_humanoid = scene.instantiate() as Node3D
	if _humanoid == null:
		push_error("NPC visual scene root must be Node3D")
		return
	add_child(_humanoid)
	_fit_model()
	_prepare_imported_materials(_humanoid)
	_set_dynamic_gi(_humanoid)
	var skeleton := _humanoid.find_child("Skeleton3D", true, false) as Skeleton3D
	animation_player = _humanoid.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation_tree = _humanoid.find_child("AnimationTree", true, false) as AnimationTree
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		animation_player.root_node = NodePath("..")
		_humanoid.add_child(animation_player)
	if skeleton != null:
		if animation_player.has_animation_library("locomotion"):
			animation_player.remove_animation_library("locomotion")
		animation_player.add_animation_library("locomotion", NPC_LOCOMOTION)
		animation_player.animation_finished.connect(_on_animation_finished)
	piece_count = 0
	set_animation_active(_animation_active)
	play_locomotion("IDLE")

func set_animation_active(active: bool) -> void:
	_animation_active = active
	# Only an ACTIVE NPC may evaluate a future humanoid animation system.
	if _humanoid != null:
		_humanoid.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if animation_tree != null:
		animation_tree.active = active
	if animation_player != null:
		animation_player.active = active

func play_locomotion(state: String, playback_rate: float = 1.0) -> bool:
	var clip := "locomotion/" + state.to_upper()
	if animation_player == null or not animation_player.has_animation(clip):
		return false
	if locomotion_state != state.to_upper() or animation_player.current_animation != clip:
		animation_player.play(clip, 0.24)
		locomotion_state = state.to_upper()
	animation_player.speed_scale = clampf(playback_rate, 0.5, 2.0)
	return true

func _on_animation_finished(animation_name: StringName) -> void:
	if str(animation_name).ends_with("/JUMP") and locomotion_state == "JUMP":
		play_locomotion("IDLE")

func play_optional_animation(clip: StringName) -> bool:
	if animation_player == null or not animation_player.has_animation(clip):
		return false
	animation_player.play(clip, 0.18)
	return true

func build(npc_id: String) -> void:
	_npc_id = npc_id
	if humanoid_scene == null:
		humanoid_scene = NPC_MODELS.get(npc_id) as PackedScene
	if humanoid_scene != null and _humanoid == null:
		replace_model(humanoid_scene)
	if _humanoid != null:
		return
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
	for instance: GeometryInstance3D in get_node("Props").find_children("*", "GeometryInstance3D", true, false):
		instance.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	piece_count = builder.instance_count

func _fit_model() -> void:
	if _humanoid == null:
		return
	var bounds := _measure_bounds(_humanoid, _humanoid)
	if bounds.size.y <= 0.01:
		return
	var style: Dictionary = WorldVisualConfig.NPC_STYLE.get(_npc_id, WorldVisualConfig.NPC_STYLE["mike"])
	var desired_height := float(style.get("height", 1.74))
	var scale_factor := desired_height / bounds.size.y
	_humanoid.scale = Vector3.ONE * scale_factor
	_humanoid.position.y = -bounds.position.y * scale_factor

func _measure_bounds(root_node: Node3D, node: Node) -> AABB:
	var result := AABB()
	var found := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_instance := node as MeshInstance3D
		var local_transform := root_node.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var transformed := local_transform * mesh_bounds.get_endpoint(corner_index)
			if not found:
				result = AABB(transformed, Vector3.ZERO)
				found = true
			else:
				result = result.expand(transformed)
	for child in node.get_children():
		var child_bounds := _measure_bounds(root_node, child)
		if child_bounds.size.length_squared() > 0.000001:
			if not found:
				result = child_bounds
				found = true
			else:
				result = result.merge(child_bounds)
	return result

func _set_dynamic_gi(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	for child: Node in node.get_children():
		_set_dynamic_gi(child)

func _prepare_imported_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var source_material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				if source_material == null:
					continue
				var material := source_material.duplicate() as StandardMaterial3D
				# The supplied FBXs use all-black vertex-color channels for cloth regions;
				# multiplying those into the shared atlas erases the authored diffuse map.
				material.vertex_color_use_as_albedo = false
				mesh_instance.set_surface_override_material(surface_index, material)
	for child: Node in node.get_children():
		_prepare_imported_materials(child)
