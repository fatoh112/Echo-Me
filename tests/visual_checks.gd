extends RefCounted
## Retained player-rendering, animation-state, and legacy-save checks after the environment rebuild.

func run(game: Node3D, check: Callable) -> void:
	var visual := game.player.get_node("Body/VisualRoot") as PlayerVisual
	check.call(visual != null and visual.model != null, "Visual: official Kachujin model remains under authoritative player body")
	check.call(visual.skeleton != null and visual.skeleton.get_bone_count() == 75, "Visual: original player skeleton remains intact")
	check.call(visual.skeleton.find_bone("mixamorig_Hips") >= 0 and visual.skeleton.find_bone("mixamorig_LeftFoot") >= 0, "Visual: expected player bone names")
	check.call(is_equal_approx(visual.normalized_bounds.size.y, 1.82), "Visual: player remains normalized to 1.82 m")
	check.call(absf(visual.normalized_bounds.position.y) < 0.01, "Visual: player feet stay aligned to the movement origin")
	check.call(visual.transform.basis.z.normalized().dot(Vector3.FORWARD) > 0.99, "Visual: player forward axis stays corrected for the controller")
	check.call(visual.model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Visual: imported player model adds no gameplay collision")
	check.call(visual.model.find_children("*", "Camera3D", true, false).is_empty(), "Visual: imported player model adds no camera")
	check.call(visual.model.find_children("*", "Light3D", true, false).is_empty(), "Visual: imported player model adds no lights")
	var capsule := game.player.get_node("CollisionShape3D").shape as CapsuleShape3D
	check.call(capsule != null and is_equal_approx(capsule.radius, 0.38) and is_equal_approx(capsule.height, 1.8), "Visual: original player collision stays authoritative")
	var camera := game.player.get_node("CameraPivot/Camera3D") as Camera3D
	var arm := game.player.get_node("CameraPivot") as SpringArm3D
	check.call(arm != null and arm.shape != null, "Visual: third-person camera keeps sphere collision")
	check.call(camera.fov >= 60 and camera.fov <= 75, "Visual: exploration camera keeps the third-person FOV")
	check.call(visual.animation_player != null and visual.animation_tree.tree_root is AnimationNodeStateMachine, "Visual: original animation architecture remains loaded")
	var machine := visual.animation_tree.tree_root as AnimationNodeStateMachine
	for state: String in ["IDLE", "WALK", "RUN"]:
		check.call(machine.has_node(state), "Visual: locomotion state remains available " + state)
	check.call(PlayerVisual.LocomotionState.has("INTERACT") and PlayerVisual.LocomotionState.has("TALK") and PlayerVisual.LocomotionState.has("SIT"), "Visual: interaction, talk, and preview states remain available")
	check.call(visual.idle_clip in visual.usable_clips and visual.animation_player.get_animation(visual.idle_clip).length > 3.0, "Visual: supplied multi-frame idle clip remains available")
	var all_clips := visual.idle_clip in visual.usable_clips and visual.walk_clip in visual.usable_clips and visual.run_clip in visual.usable_clips
	check.call(visual.animation_tree.active == all_clips, "Visual: animation tree runs only when source locomotion clips exist")
	for mesh_instance: MeshInstance3D in visual.model.find_children("*", "MeshInstance3D", true, false):
		check.call(mesh_instance.gi_mode == GeometryInstance3D.GI_MODE_DYNAMIC, "Visual: moving player meshes receive dynamic lighting")
		check.call(mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() == 2, "Visual: both player material surfaces remain")
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
			check.call(material != null and material.albedo_texture != null and material.albedo_texture.get_width() <= 1024, "Visual: player PBR material remains imported within texture budget")
	var saved_position: Vector3 = game.player.global_position
	var old_profile: Dictionary = game.world.player_profile.to_dict()
	game.player.global_position = Vector3(0, 0, 11)
	check.call(PlayerSpawnResolver.place(game.player, game.world), "Visual: legacy Day 1 spawn relocates into the village")
	check.call(game.world.player_profile.to_dict() == old_profile, "Visual: spawn migration preserves behavior history")
	var migrated_position: Vector3 = game.player.global_position
	check.call(migrated_position.distance_to(game.world.location_position("PLAYER_QUARTERS")) < 0.1, "Visual: legacy spawn resolves to the safe player house")
	game.player.global_position = Vector3(12.45, 1.4, -81.0)
	game.player.velocity = Vector3.ZERO
	arm.rotation = Vector3(-0.16, 0, 0)
	game.player.controls_enabled = true
	Input.action_press("move_forward")
	for _frame in range(7):
		await game.get_tree().physics_frame
	await game.get_tree().process_frame
	Input.action_release("move_forward")
	check.call(visual.locomotion_state == PlayerVisual.LocomotionState.WALK, "Visual: movement still drives the original walk animation state")
	check.call(game.player.global_position.z < -81.0, "Visual: indoor movement does not replace player authority")
	game.player.velocity = Vector3.ZERO
	game.player.global_position = saved_position
	game.world.player_position = saved_position
	_test_old_world(check)

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
	check.call(migrated.player_profile.to_dict() == baseline.player_profile.to_dict(), "Retheme: Day 2 traits survive the visual rebuild")
	check.call(migrated.reputation.to_dict() == baseline.reputation.to_dict(), "Retheme: local reputation survives the visual rebuild")
	check.call(migrated.echo_seed == baseline.echo_seed, "Retheme: saved Echo seed survives")
	check.call(migrated.last_player_location == "PLAYER_QUARTERS" and migrated.echo_location_id == "TOWN_SQUARE", "Retheme: saved world aliases map to official locations")
	for npc_id: String in baseline.npcs:
		var before: NPCData = baseline.npcs[npc_id]
		var after: NPCData = migrated.npcs[npc_id]
		check.call(after.id == before.id and after.relationship.to_dict() == before.relationship.to_dict(), "Retheme: NPC identity and relationship retained " + npc_id)
		check.call(after.role == before.role and after.home_location_id == "RESIDENTIAL_ROW", "Retheme: old role and home data migrates " + npc_id)
		check.call(after.memories.size() == before.memories.size(), "Retheme: memory count retained " + npc_id)
		for index in range(before.memories.size()):
			var old_memory: NPCMemory = before.memories[index]
			var new_memory: NPCMemory = after.memories[index]
			check.call(new_memory.id == old_memory.id and new_memory.summary == old_memory.summary and new_memory.actual_source == old_memory.actual_source, "Retheme: memory identity, text, and source retained")
			check.call(new_memory.location_id in LocationRegistry.IDS, "Retheme: memory location is canonical")
	for event in migrated.event_history:
		check.call(event.location_id in LocationRegistry.IDS, "Retheme: action-history location is canonical")
	for legacy_id: String in LocationRegistry.LEGACY:
		check.call(LocationRegistry.canonical(legacy_id) in LocationRegistry.IDS, "Retheme: legacy alias remains readable " + legacy_id)
