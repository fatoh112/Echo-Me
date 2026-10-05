extends CharacterBody3D
class_name NPCController

@onready var body_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var visual_root: NPCVisual = get_node_or_null("VisualRoot")
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var name_label: Label3D = $NameLabel
var data: NPCData
var level := "LOGICAL"
var talking := false
var locomotion_override := ""
var path_router: NPCPathRouter
var player_body: CharacterBody3D
var route_rng := RandomNumberGenerator.new()
var route_nodes: Dictionary = {}
var current_waypoint_id := ""
var next_waypoint_id := ""
var previous_waypoint_id := ""
var route_moving := false
var route_pause_seconds := 0.0
var route_stalled_seconds := 0.0
var route_walk_speed := 1.12
var _last_location_id := ""
var _has_representation := false
var _route_build_failed := false


func configure(npc_data: NPCData) -> void:
	data = npc_data
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(48.0)
	name_label.text = data.display_name
	body_mesh.visible = false
	if visual_root == null:
		visual_root = NPCVisual.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	visual_root.build(data.id)
	var style: Dictionary = WorldVisualConfig.NPC_STYLE.get(data.id, WorldVisualConfig.NPC_STYLE["mike"])
	name_label.position.y = float(style["height"]) + 0.10
	name_label.font_size = 28
	name_label.outline_size = 2
	name_label.modulate = Color(0.93, 0.88, 0.77, 0.88)
	_set_activity_animation()
	set_process(false)
	set_physics_process(false)


func set_walkway_router(router: NPCPathRouter, save_seed: int, player: CharacterBody3D = null) -> void:
	path_router = router
	player_body = player
	route_rng.seed = absi(save_seed + int((data.id + ":walkway").hash()))


func debug_route() -> String:
	if not next_waypoint_id.is_empty():
		return "%s → %s" % [current_waypoint_id, next_waypoint_id]
	return current_waypoint_id if not current_waypoint_id.is_empty() else "waiting"


func update_representation(world_position: Vector3, activity_level: String, force_position: bool = false) -> void:
	var location_id := str(data.current_state.get("location_id", "")) if data != null else ""
	var reset_route := force_position or not _has_representation or location_id != _last_location_id
	var was_relevant := level != "LOGICAL"
	level = activity_level
	if data != null:
		data.activity_level = level
	var relevant := level != "LOGICAL"
	visible = relevant
	visual_root.set_animation_active(level == "ACTIVE")
	collider.set_deferred("disabled", not relevant)
	set_physics_process(level == "ACTIVE")
	if relevant and (reset_route or not was_relevant):
		global_position = world_position
		velocity = Vector3.ZERO
		if level == "ACTIVE":
			_begin_random_route()
	elif level == "ACTIVE" and next_waypoint_id.is_empty() and not _route_build_failed:
		_begin_random_route()
	if reset_route:
		_last_location_id = location_id
	_has_representation = true
	if relevant:
		if not talking:
			_set_activity_animation()


func set_talking(active: bool) -> void:
	talking = active
	if visual_root == null:
		return
	if talking:
		route_moving = false
		visual_root.play_locomotion("TALK")
	else:
		_set_activity_animation()


func play_locomotion(state: String, playback_rate: float = 1.0) -> bool:
	return visual_root != null and visual_root.play_locomotion(state, playback_rate)


func set_locomotion_override(state: String) -> bool:
	locomotion_override = state.to_upper()
	return play_locomotion(locomotion_override)


func clear_locomotion_override() -> void:
	locomotion_override = ""
	_set_activity_animation()


func _set_activity_animation() -> void:
	if data == null or visual_root == null:
		return
	var activity := str(data.current_state.get("activity", "idle")).to_lower()
	var state := locomotion_override if not locomotion_override.is_empty() else "IDLE"
	if not locomotion_override.is_empty():
		visual_root.play_locomotion(state)
		return
	if route_moving:
		state = "WALK"
	elif activity.contains("rest") or activity.contains("relax") or activity.contains("sleep"):
		state = "SIT"
	elif activity.contains("patrol") or activity.contains("meeting friends"):
		state = "WALK"
	elif activity.contains("looking for trouble"):
		state = "JOG"
	visual_root.play_locomotion(state)


func _begin_random_route() -> void:
	route_moving = false
	route_stalled_seconds = 0.0
	route_nodes.clear()
	if path_router == null or not path_router.ready:
		_route_build_failed = true
		return
	var exclusions: Array[RID] = [get_rid()]
	if player_body != null and is_instance_valid(player_body):
		exclusions.append(player_body.get_rid())
	var graph := path_router.build_local_graph(get_world_3d(), global_position, collider.shape, exclusions)
	route_nodes = graph.get("nodes", {}) as Dictionary
	current_waypoint_id = str(graph.get("start_id", ""))
	if current_waypoint_id.is_empty() or route_nodes.size() < 2:
		_route_build_failed = true
		return
	_route_build_failed = false
	var safe_start := path_router.waypoint_position(route_nodes, current_waypoint_id)
	if global_position.distance_to(safe_start) > 1.75:
		route_nodes.clear()
		current_waypoint_id = ""
		_route_build_failed = true
		return
	global_position = safe_start
	previous_waypoint_id = ""
	_choose_next_waypoint()
	route_pause_seconds = route_rng.randf_range(0.25, 0.75)


func _choose_next_waypoint() -> void:
	if path_router == null:
		next_waypoint_id = ""
		return
	next_waypoint_id = path_router.choose_next(route_nodes, current_waypoint_id, previous_waypoint_id, route_rng)
	route_walk_speed = route_rng.randf_range(0.92, 1.22)
	route_pause_seconds = route_rng.randf_range(path_router.pause_min_seconds, path_router.pause_max_seconds) if route_rng.randf() < path_router.pause_chance else route_rng.randf_range(0.04, 0.18)


func _physics_process(delta: float) -> void:
	if level != "ACTIVE":
		return
	if talking or not locomotion_override.is_empty() or next_waypoint_id.is_empty():
		route_moving = false
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	if route_pause_seconds > 0.0:
		route_pause_seconds = maxf(0.0, route_pause_seconds - delta)
		route_moving = false
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		_set_activity_animation()
		return
	var target := path_router.waypoint_position(route_nodes, next_waypoint_id)
	var offset := target - global_position
	var horizontal_offset := Vector2(offset.x, offset.z)
	if horizontal_offset.length() <= 0.42:
		previous_waypoint_id = current_waypoint_id
		current_waypoint_id = next_waypoint_id
		if path_router.node_is_patch_edge(route_nodes, current_waypoint_id):
			_begin_random_route()
			return
		_choose_next_waypoint()
		route_moving = false
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		_set_activity_animation()
		return
	var direction := Vector3(horizontal_offset.x, 0.0, horizontal_offset.y).normalized()
	var before := horizontal_offset.length()
	velocity.x = direction.x * route_walk_speed
	velocity.z = direction.z * route_walk_speed
	_apply_gravity(delta)
	move_and_slide()
	var remaining := Vector2(target.x - global_position.x, target.z - global_position.z).length()
	if before - remaining < 0.006:
		route_stalled_seconds += delta
	else:
		route_stalled_seconds = 0.0
	if route_stalled_seconds > 1.35:
		_begin_random_route()
	else:
		route_moving = true
		var heading := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, heading, minf(1.0, delta * 6.0))
	_set_activity_animation()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, -0.15)
	else:
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta
