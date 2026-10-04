extends Node3D
class_name NPCController

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var collider: CollisionShape3D = $Body/CollisionShape3D
@onready var name_label: Label3D = $NameLabel
var data: NPCData
var level := "LOGICAL"


func configure(npc_data: NPCData) -> void:
	data = npc_data
	name_label.text = "%s\n%s" % [data.display_name, data.role]
	var material := StandardMaterial3D.new()
	material.albedo_color = data.color
	material.roughness = 1.0
	body_mesh.material_override = material
	set_process(false)
	set_physics_process(false)


func update_representation(world_position: Vector3, activity_level: String) -> void:
	level = activity_level
	if data != null:
		data.activity_level = level
	var relevant := level != "LOGICAL"
	visible = relevant
	collider.set_deferred("disabled", not relevant)
	if relevant:
		global_position = world_position
