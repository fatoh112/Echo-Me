extends RefCounted
class_name PlayerSpawnResolver

static func place(player: CharacterBody3D, world: WorldState) -> bool:
	var original := player.global_position
	var candidate := original
	if _is_in_village(candidate) and is_clear(player, candidate):
		player.global_position = candidate
		return false
	# Presentation changed, so an old saved position may now be inside a house.
	# Move only position; preserve the complete profile, relationships, and history.
	var anchors: Array[String] = ["PLAYER_QUARTERS", world.closest_location(candidate)]
	anchors.append_array(LocationRegistry.IDS)
	for location_id in anchors:
		var anchor := world.location_position(location_id)
		if is_clear(player, anchor):
			player.global_position = anchor
			player.velocity = Vector3.ZERO
			world.player_position = anchor
			return true
	return false

static func _is_in_village(position_value: Vector3) -> bool:
	return position_value.x >= 7.0 and position_value.x <= 48.0 and position_value.z >= -108.0 and position_value.z <= -38.0 and position_value.y >= 0.6 and position_value.y <= 8.0

static func is_clear(player: CharacterBody3D, position_value: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = (player.get_node("CollisionShape3D") as CollisionShape3D).shape
	query.transform = Transform3D(Basis.IDENTITY, position_value + Vector3(0, 0.94, 0))
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
