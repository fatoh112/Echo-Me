extends RefCounted

func run(game: Node3D, check: Callable) -> void:
	var visual := game.player.get_node("Body/VisualRoot") as PlayerVisual
	check.call(visual != null and visual.model != null, "Visual: official FBX instanced under authoritative body")
	check.call(visual.skeleton != null and visual.skeleton.get_bone_count() == 75, "Visual: 75-bone Mixamo skeleton")
	check.call(visual.skeleton.find_bone("mixamorig_Hips") >= 0 and visual.skeleton.find_bone("mixamorig_LeftFoot") >= 0, "Visual: expected bone names")
	check.call(is_equal_approx(visual.normalized_bounds.size.y, 1.82), "Visual: model normalized to 1.82 m")
	check.call(absf(visual.normalized_bounds.position.y) < 0.01, "Visual: feet aligned to body ground origin")
	check.call(visual.transform.basis.z.normalized().dot(Vector3.FORWARD) > 0.99, "Visual: Mixamo +Z corrected to controller -Z")
	check.call(visual.model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Visual: no imported physics body")
	check.call(visual.model.find_children("*", "Camera3D", true, false).is_empty(), "Visual: no imported camera")
	check.call(visual.model.find_children("*", "Light3D", true, false).is_empty(), "Visual: no imported light")
	var shape := game.player.get_node("CollisionShape3D").shape as CapsuleShape3D
	check.call(shape != null and is_equal_approx(shape.radius, 0.38) and is_equal_approx(shape.height, 1.8), "Visual: original player collision retained")
	var camera := game.player.get_node("CameraPivot/Camera3D") as Camera3D
	var arm := game.player.get_node("CameraPivot") as SpringArm3D
	check.call(arm != null and arm.shape != null, "Visual: camera uses sphere sweep SpringArm")
	check.call(camera.fov >= 60 and camera.fov <= 75, "Visual: normal exploration FOV")
	check.call(visual.animation_player != null and visual.animation_tree.tree_root is AnimationNodeStateMachine, "Visual: animation architecture exists")
	var machine := visual.animation_tree.tree_root as AnimationNodeStateMachine
	for state in ["IDLE", "WALK", "RUN"]:
		check.call(machine.has_node(state), "Visual: locomotion state " + state)
	check.call(PlayerVisual.LocomotionState.has("INTERACT") and PlayerVisual.LocomotionState.has("TALK") and PlayerVisual.LocomotionState.has("SIT"), "Visual: INTERACT TALK SIT states retained")
	check.call(visual.idle_clip in visual.usable_clips, "Visual: supplied matching Idle clip is usable")
	check.call(visual.animation_player.get_animation(visual.idle_clip).length > 3.0, "Visual: real multi-frame Idle clip")
	var all_clips := visual.idle_clip in visual.usable_clips and visual.walk_clip in visual.usable_clips and visual.run_clip in visual.usable_clips
	check.call(visual.animation_tree.active == all_clips, "Visual: tree remains inactive when locomotion clips are missing")
	# Mesh/material inputs are valid and capped for the target GPU.
	for node: MeshInstance3D in visual.model.find_children("*", "MeshInstance3D", true, false):
		check.call(node.mesh != null and node.mesh.get_surface_count() == 2, "Visual: both imported material surfaces retained")
		for index in range(node.mesh.get_surface_count()):
			var material := node.get_surface_override_material(index) as StandardMaterial3D
			check.call(material != null, "Visual: material override is valid")
			check.call(material.albedo_texture != null and material.albedo_texture.get_width() <= 1024, "Visual: player texture import capped to 1K")
	check.call(game.neighborhood.visual_batch_count <= 40 and game.neighborhood.visual_instance_count > 1000, "Visual: dense geometry uses bounded MultiMesh batches")
	var roof_arrays: Array = game.neighborhood.builder._mesh("roof").surface_get_arrays(0)
	var roof_vertices: PackedVector3Array = roof_arrays[Mesh.ARRAY_VERTEX]
	var roof_normals: PackedVector3Array = roof_arrays[Mesh.ARRAY_NORMAL]
	for index in range(roof_vertices.size()):
		if roof_vertices[index].y > 0.9 and absf(roof_normals[index].z) < 0.8:
			check.call(roof_normals[index].y > 0, "Visual: roof slope normals face upward")
	check.call(game.neighborhood.get_node("Environment").find_children("*", "DirectionalLight3D", true, false).size() == 1, "Visual: one primary sun")
	check.call(game.neighborhood.get_node("Environment").find_children("*", "OmniLight3D", true, false).size() == 2, "Visual: only two local lamps")
	for light: Light3D in game.neighborhood.get_node("Environment").find_children("*", "Light3D", true, false):
		check.call(not light.shadow_enabled, "Visual: no shadow-casting local lights")
	for zone in LocationRegistry.IDS:
		check.call(game.world.locations.has(zone) and game.neighborhood.locations_root.has_node(zone), "Visual: official zone marker " + zone)
		check.call(game.world.closest_location(game.world.location_position(zone)) == zone, "Visual: zone bounds contain official anchor " + zone)
	for npc_id: String in game.npc_manager.entities:
		var entity: NPCController = game.npc_manager.entities[npc_id]
		check.call(entity.visual_root.piece_count >= 16 and not entity.body_mesh.visible, "Visual: distinct primitive silhouette " + npc_id)
	var exclude: Array[RID] = [game.player.get_rid()]
	for entity: NPCController in game.npc_manager.entities.values():
		exclude.append((entity.get_node("Body") as StaticBody3D).get_rid())
	for npc: NPCData in game.world.npcs.values():
		check.call(_clear(game, game.world.npc_position(npc), exclude), "Visual: scheduled NPC clear of buildings " + npc.id)
	# Sample connected walking routes at half-meter intervals around the fountain.
	var hub := Vector3(4, 0, 7)
	var route: Array[Vector3] = [Vector3(0, 0, 11), hub, Vector3(4, 0, -6), Vector3(0, 0, -5), Vector3(0, 0, -18)]
	for index in range(route.size() - 1):
		check.call(_route_clear(game, route[index], route[index + 1], exclude), "Visual: connected main street segment " + str(index))
	for destination: Vector3 in [Vector3(-10, 0, -6), Vector3(10, 0, -6), Vector3(10, 0, 9), Vector3(-10, 0, 9)]:
		var origin := Vector3(4, 0, -6) if destination.z < 0 else hub
		check.call(_route_clear(game, origin, destination, exclude), "Visual: accessible zone route " + str(destination))
	var original_position: Vector3 = game.player.global_position
	var original_pivot: Vector3 = arm.rotation
	var profile_before: Dictionary = game.world.player_profile.to_dict()
	game.player.global_position = Vector3(0, 0, 15)
	arm.rotation = Vector3(-0.16, 0, 0)
	for _index in range(4):
		await game.get_tree().physics_frame
	check.call(arm.get_hit_length() < arm.spring_length - 1.0 and arm.get_hit_length() > 0.5, "Visual: camera retracts ahead of house wall")
	game.player.global_position = Vector3(11, 0, -13)
	check.call(PlayerSpawnResolver.place(game.player, game.world), "Visual: blocked legacy spawn recovered")
	check.call(PlayerSpawnResolver.is_clear(game.player, game.player.global_position), "Visual: recovered spawn is walkable")
	check.call(game.world.player_profile.to_dict() == profile_before, "Visual: spawn recovery preserves behavior profile")
	game.player.global_position = Vector3(4, 0, 7)
	game.player.controls_enabled = true
	game.player.velocity = Vector3.ZERO
	arm.rotation = Vector3(-0.16, 0, 0)
	Input.action_press("move_forward")
	for _index in range(5):
		await game.get_tree().physics_frame
	await game.get_tree().process_frame
	check.call(visual.locomotion_state == PlayerVisual.LocomotionState.WALK, "Visual: locomotion observes walking controller velocity")
	check.call(game.player.global_position.z < 7, "Visual: missing animations never block authoritative movement")
	Input.action_release("move_forward")
	game.player.velocity = Vector3.ZERO
	game.player.global_position = original_position
	arm.rotation = original_pivot
	game.world.player_position = original_position
	_test_old_world(check)
	print("TOWN VISUALS: ", game.neighborhood.visual_instance_count, " instances in ", game.neighborhood.visual_batch_count, " batches; clips ", visual.usable_clips)

func _clear(game: Node3D, position_value: Vector3, exclude: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = game.player.get_node("CollisionShape3D").shape
	query.transform = Transform3D(Basis.IDENTITY, position_value + Vector3(0, 0.94, 0))
	query.exclude = exclude
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _route_clear(game: Node3D, first: Vector3, second: Vector3, exclude: Array[RID]) -> bool:
	var steps := ceili(first.distance_to(second) * 2)
	for index in range(steps + 1):
		if not _clear(game, first.lerp(second, float(index) / maxf(steps, 1)), exclude):
			return false
	return true

func _test_old_world(check: Callable) -> void:
	var baseline := WorldState.new(7731)
	var action := WorldAction.create("HELP", "alex", "MERCHANT_SHOP", "PLAYER", 100000, "old-help")
	ActionSystem.apply(baseline, action)
	action = WorldAction.create("BETRAY", "sarah", "RESIDENTIAL_ROW", "ECHO", 100001, "old-echo")
	ActionSystem.apply(baseline, action)
	var old := baseline.to_dict()
	var old_roles := {"alex": "Shopkeeper", "sarah": "Close friend", "mike": "Neighbor", "emma": "Cafe worker", "david": "Troublemaker", "noah": "Neighborhood watch"}
	for npc_id: String in old["npcs"]:
		var npc: Dictionary = old["npcs"][npc_id]
		npc["role"] = old_roles[npc_id]
		npc["home_location_id"] = "residential"
		npc["current_state"]["location_id"] = "cafe" if npc_id == "emma" else "residential"
		for memory: Dictionary in npc["memories"]:
			memory["location_id"] = "shop" if npc_id == "alex" else "park"
	old["world_state"]["last_player_location"] = "player_area"
	old["world_state"]["echo_location_id"] = "street"
	for event: Dictionary in old["event_history"]:
		event["location_id"] = "shop" if event["target_id"] == "alex" else "park"
	var migrated := WorldState.from_dict(old)
	check.call(migrated.player_profile.to_dict() == baseline.player_profile.to_dict(), "Retheme: Day 2 traits preserved")
	check.call(migrated.reputation.to_dict() == baseline.reputation.to_dict(), "Retheme: Day 2 reputation preserved")
	check.call(migrated.echo_seed == baseline.echo_seed, "Retheme: seed preserved")
	check.call(migrated.last_player_location == "PLAYER_QUARTERS" and migrated.echo_location_id == "TOWN_SQUARE", "Retheme: saved world aliases mapped")
	for npc_id: String in baseline.npcs:
		var before: NPCData = baseline.npcs[npc_id]
		var after: NPCData = migrated.npcs[npc_id]
		check.call(after.id == before.id and after.relationship.to_dict() == before.relationship.to_dict(), "Retheme: NPC identity/relationship preserved " + npc_id)
		check.call(after.role == before.role and after.home_location_id == "RESIDENTIAL_ROW", "Retheme: legacy role/home rethemed " + npc_id)
		check.call(after.memories.size() == before.memories.size(), "Retheme: memory count preserved " + npc_id)
		for index in range(before.memories.size()):
			var old_memory: NPCMemory = before.memories[index]
			var new_memory: NPCMemory = after.memories[index]
			check.call(new_memory.id == old_memory.id and new_memory.summary == old_memory.summary and new_memory.actual_source == old_memory.actual_source, "Retheme: memory identity/text/source preserved")
			check.call(new_memory.location_id in LocationRegistry.IDS, "Retheme: memory location is valid")
	for event in migrated.event_history:
		check.call(event.location_id in LocationRegistry.IDS, "Retheme: historical action location is valid")
	for legacy_id: String in LocationRegistry.LEGACY:
		check.call(LocationRegistry.canonical(legacy_id) in LocationRegistry.IDS, "Retheme: legacy alias " + legacy_id)
