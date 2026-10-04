extends RefCounted
## Day 4 regression: real resources, all schedules, continuous capsule routes,
## level ground and the imported watch staircase without changing locomotion.
const STEP := 0.75
var _open: Dictionary = {}
var _reached: Dictionary = {}
var _exclude: Array[RID] = []

func run(game: Node3D, check: Callable) -> void:
	var town: Neighborhood = game.neighborhood
	check.call(town.assets.sources.size() >= 30, "Environment: diverse real source meshes in the town")
	check.call(town.assets.vertex_count < 1000000 and town.bakeable_vertex_count >= town.assets.vertex_count, "Environment: static lightmap geometry remains within vertex budget")
	check.call(town.builder.instance_count < 120, "Environment: primitives limited to small signs and lanterns")
	check.call(town.assets.geometry.get_child_count() == town.assets.batch_count, "Environment: one render node per shared mesh")
	check.call(not town.assets.geometry.is_processing() and not town.assets.geometry.is_physics_processing(), "Environment: decoration has no frame scripts")
	var atlas := preload("res://assets/environment/slavic_town/materials/slavic_atlas.tres")
	for path: String in town.assets.sources:
		check.call(FileAccess.file_exists(path) and ResourceLoader.exists(path), "Environment: source and import exist " + path.get_file())
	for batch: MeshInstance3D in town.assets.geometry.get_children():
		var mesh := batch.mesh
		check.call(batch.gi_mode == GeometryInstance3D.GI_MODE_STATIC, "Environment: imported spatial chunk participates in baked indirect light")
		var uv2: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		check.call(uv2.size() == mesh.surface_get_array_len(0), "Environment: imported mesh UV2 covers its complete vertex buffer")
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			check.call(material != null and material.albedo_texture == atlas.albedo_texture, "Environment: original colorsheet texture remains shared across PBR variants")
		check.call(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON or batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Environment: large landmark shadow roles are explicit")
	check.call(town.assets.geometry.find_children("*", "MeshInstance3D", false, false).size() == town.assets.batch_count, "Environment: one static render node per bake chunk")
	var shadow_chunks := 0
	for batch: MeshInstance3D in town.assets.geometry.get_children():
		if batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			shadow_chunks += 1
	check.call(shadow_chunks >= 5 and shadow_chunks <= 45 and shadow_chunks < town.assets.batch_count, "Environment: shadow casting is limited to landmarks")
	var lightmap := town.get_node("LightmapGI") as LightmapGI
	check.call(lightmap.light_data != null and lightmap.light_data.resource_path == "res://scenes/world/town_lighting.lmbake", "Environment: local LightmapGI bake target is configured")
	for node: CollisionShape3D in town.assets.collision.get_children():
		check.call(node.shape is BoxShape3D or node.shape is CylinderShape3D, "Environment: simple authored collision")
	_exclude.append(game.player.get_rid())
	for entity: NPCController in game.npc_manager.entities.values():
		_exclude.append((entity.get_node("Body") as StaticBody3D).get_rid())
	var spawn := Vector3(0, 0, 11)
	check.call(_clear(game, spawn), "Environment: player spawn clear")
	_build_reachability(game, spawn)
	for zone: String in LocationRegistry.IDS:
		check.call(town.locations_root.has_node(zone) and game.world.locations.has(zone), "Environment: logical zone preserved " + zone)
		check.call(_reachable(game, game.world.location_position(zone)), "Environment: connected zone " + zone)
	var scheduled := WorldState.new(94721)
	for minute in [0, 480, 720, 840, 1020, 1080, 1140]:
		scheduled.game_minutes = minute
		scheduled.update_schedules()
		for npc: NPCData in scheduled.npcs.values():
			var point := scheduled.npc_position(npc)
			check.call(_clear(game, point), "Environment: NPC capsule clear " + npc.id + " at " + str(minute))
			check.call(_reachable(game, point), "Environment: NPC reachable " + npc.id + " at " + str(minute))
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0.5, 0), point - Vector3(0, 0.2, 0))
			ray.exclude = _exclude
			var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
			check.call(not hit.is_empty() and absf(hit.position.y) < 0.01, "Environment: NPC on level ground " + npc.id + " at " + str(minute))
	await _watch_stairs(game, check)
	print("ENVIRONMENT: ", town.assets.sources.size(), " sources; ", town.assets.vertex_count, " submitted vertices; ", _reached.size(), " connected capsule-grid cells")

func _clear(game: Node3D, point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 0.94, 0))
	query.exclude = _exclude
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _build_reachability(game: Node3D, spawn: Vector3) -> void:
	for z in range(-36, 37):
		for x in range(-36, 37):
			var cell := Vector2i(x, z)
			if _clear(game, _point(cell)):
				_open[cell] = true
	var first := _cell(spawn)
	var pending: Array[Vector2i] = [first]
	_reached[first] = true
	var head := 0
	while head < pending.size():
		var cell := pending[head]
		head += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + offset
			if _open.has(next) and not _reached.has(next) and _clear(game, (_point(cell) + _point(next)) * 0.5):
				_reached[next] = true
				pending.append(next)

func _reachable(game: Node3D, point: Vector3) -> bool:
	var cell := _cell(point)
	for z in range(-2, 3):
		for x in range(-2, 3):
			var candidate := cell + Vector2i(x, z)
			if not _reached.has(candidate):
				continue
			var clear := true
			for sample in range(7):
				clear = clear and _clear(game, point.lerp(_point(candidate), sample / 6.0))
			if clear:
				return true
	return false

func _point(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * STEP, 0, cell.y * STEP)

func _cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / STEP), roundi(point.z / STEP))

func _watch_stairs(game: Node3D, check: Callable) -> void:
	var player: PlayerController = game.player
	var old_position := player.global_position
	var old_pivot := player.camera_pivot.rotation
	player.global_position = Vector3(-11.7, 0, 5.02)
	player.velocity = Vector3.ZERO
	player.camera_pivot.rotation = Vector3(-0.16, 0, 0)
	player.visual.talk_seconds = 0
	player.controls_enabled = true
	for _frame in range(4):
		await game.get_tree().physics_frame
	Input.action_press("move_left")
	var maximum_height := 0.0
	for _frame in range(180):
		await game.get_tree().physics_frame
		maximum_height = maxf(maximum_height, player.global_position.y)
		if maximum_height > 3.45:
			break
	for _frame in range(18):
		await game.get_tree().physics_frame
	Input.action_release("move_left")
	print("STAIR PROBE: position ", player.global_position, "; maximum height ", maximum_height, "; floor ", player.is_on_floor(), "; animation ", player.visual.state_name())
	check.call(maximum_height > 3.45 and player.is_on_floor(), "Environment: normal Walk climbs watch stair ramp without jumping")
	check.call(absf(player.global_position.y - 3.49) < 0.07, "Environment: watch landing matches source model floor height")
	check.call(player.visual.state_name() == "STRAFE_LEFT", "Environment: stair ramp preserves existing strafe animation")
	player.global_position = old_position
	player.camera_pivot.rotation = old_pivot
	player.velocity = Vector3.ZERO
