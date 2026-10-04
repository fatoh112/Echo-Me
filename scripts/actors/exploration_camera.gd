extends SpringArm3D

func _ready() -> void:
	var player := get_parent() as CollisionObject3D
	if player != null:
		add_excluded_object(player.get_rid())
