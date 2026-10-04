extends Node3D
class_name NPCController

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var visual_root: NPCVisual = get_node_or_null("VisualRoot")
@onready var collider: CollisionShape3D = $Body/CollisionShape3D
@onready var name_label: Label3D = $NameLabel
var data: NPCData
var level := "LOGICAL"


func configure(npc_data: NPCData) -> void:
	data = npc_data
	name_label.text = data.display_name
	body_mesh.visible = false
	if visual_root == null:
		visual_root = NPCVisual.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	visual_root.build(data.id)
	var style: Dictionary = WorldVisualConfig.NPC_STYLE.get(data.id, WorldVisualConfig.NPC_STYLE["mike"])
	name_label.position.y = float(style["height"]) + 0.5
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
