extends RefCounted
class_name PlayerSpawnResolver

const LEGACY_START_RADIUS := 2.75
const FALLBACK_SPAWN_POSITION := Vector3(17.0, 1.303, -80.95)


static func place(player: CharacterBody3D, world: WorldState, force_default: bool = false) -> bool:
	var candidate := player.global_position
	var spawn_position := _default_spawn_position(player, world)
	var is_default_spawn := candidate.distance_to(spawn_position) <= 0.15
	if not force_default and not _is_legacy_home_start(candidate, world) and is_valid_position(player, candidate):
		if is_default_spawn:
			_face_town(player, _default_spawn_yaw(player, world, spawn_position))
		player.global_position = candidate
		return false
	if not is_valid_position(player, spawn_position):
		push_warning("Player exterior start is blocked or has no supporting ground.")
		return false
	player.global_position = spawn_position
	player.velocity = Vector3.ZERO
	world.player_position = spawn_position
	_face_town(player, _default_spawn_yaw(player, world, spawn_position))
	return true


static func is_valid_position(player: CharacterBody3D, position_value: Vector3) -> bool:
	return _is_in_village(position_value) and is_clear(player, position_value) and has_ground(player, position_value)


static func _is_legacy_home_start(position_value: Vector3, world: WorldState) -> bool:
	var offset := position_value - world.location_position("PLAYER_QUARTERS")
	offset.y = 0.0
	return offset.length() <= LEGACY_START_RADIUS


static func _default_spawn_position(player: CharacterBody3D, world: WorldState) -> Vector3:
	var marker := _spawn_marker(player)
	if marker != null:
		return marker.global_position
	var quarters := DataUtils.dictionary(world.locations.get("PLAYER_QUARTERS", {}))
	var coordinates: Variant = quarters.get("spawn_position", [])
	if coordinates is Array and coordinates.size() == 3:
		return Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
	return FALLBACK_SPAWN_POSITION


static func _default_spawn_yaw(player: CharacterBody3D, world: WorldState, spawn_position: Vector3) -> float:
	var marker := _spawn_marker(player)
	if marker != null:
		return marker.global_rotation.y
	var direction := world.location_position("TOWN_SQUARE") - spawn_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return PI
	return atan2(-direction.x, -direction.z)


static func _spawn_marker(player: CharacterBody3D) -> Marker3D:
	var main := player.get_parent()
	if main == null:
		return null
	return main.get_node_or_null("Neighborhood/PlayerStart") as Marker3D


static func _face_town(player: CharacterBody3D, yaw: float) -> void:
	var body := player.get_node_or_null("Body") as Node3D
	var camera := player.get_node_or_null("CameraPivot") as Node3D
	if body != null:
		body.rotation.y = yaw
	if camera != null:
		camera.rotation.y = yaw


static func _is_in_village(position_value: Vector3) -> bool:
	return position_value.x >= 7.0 and position_value.x <= 48.0 and position_value.z >= -108.0 and position_value.z <= -38.0 and position_value.y >= 0.6 and position_value.y <= 8.0


static func has_ground(player: CharacterBody3D, position_value: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		position_value + Vector3.UP * 0.6,
		position_value - Vector3.UP * 0.5
	)
	query.exclude = [player.get_rid()]
	query.collision_mask = player.collision_mask
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var ground_position: Vector3 = hit.get("position", Vector3.ZERO)
	return normal.y >= 0.65 and absf(ground_position.y - position_value.y) <= 0.35


static func is_clear(player: CharacterBody3D, position_value: Vector3) -> bool:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	var basis := player.global_transform.basis
	query.transform = Transform3D(basis, position_value + basis * collision_shape.position)
	query.exclude = [player.get_rid()]
	query.collision_mask = player.collision_mask
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
