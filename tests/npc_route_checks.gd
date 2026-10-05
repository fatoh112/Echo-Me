extends RefCounted

## Verifies that the imported collision produces usable local walk routes and
## that an ACTIVE NPC follows them without leaving the mapped village.

func run(game: Node3D, check: Callable) -> void:
	var player: PlayerController = game.player
	var old_player_position := player.global_position
	var old_player_controls := player.controls_enabled
	var old_game_process := game.is_processing()
	game.set_process(false)
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(200.0, 10.0, 200.0)

	var router: NPCPathRouter = game.npc_manager.path_router
	var entity: NPCController = game.npc_manager.entities["sarah"]
	var old_npc_position := entity.global_position
	var old_npc_level := entity.level
	var old_talking := entity.talking
	var old_npc_visible := entity.visible
	var old_collider_disabled := entity.collider.disabled
	var old_physics := entity.is_physics_processing()
	var exclusions: Array[RID] = [player.get_rid()]
	for other: NPCController in game.npc_manager.entities.values():
		exclusions.append(other.get_rid())
	for npc_id: String in game.npc_manager.entities:
		var scheduled_entity: NPCController = game.npc_manager.entities[npc_id]
		var scheduled_position: Vector3 = game.world.npc_position(game.world.npcs[npc_id])
		var scheduled_graph := router.build_local_graph(game.get_world_3d(), scheduled_position, scheduled_entity.collider.shape, exclusions)
		check.call((scheduled_graph.get("nodes", {}) as Dictionary).size() >= 2, "NPC navigation: schedule anchor has a walkable route for " + npc_id)

	var route_spot := Vector3.ZERO
	var built_graph: Dictionary = {}
	for candidate: Vector2 in [
		Vector2(14.1, -72.7), Vector2(15.3, -76.0),
		Vector2(21.7, -66.4), Vector2(14.0, -81.0),
		Vector2(40.5, -57.1), Vector2(36.7, -78.5),
	]:
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(candidate.x, 12.0, candidate.y),
			Vector3(candidate.x, -4.0, candidate.y)
		)
		ray.exclude = exclusions
		var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			continue
		var floor_position: Vector3 = hit.position + Vector3.UP * 0.035
		var graph := router.build_local_graph(game.get_world_3d(), floor_position, entity.collider.shape, exclusions)
		if (graph.get("nodes", {}) as Dictionary).size() >= 8:
			route_spot = floor_position
			built_graph = graph
			break

	check.call(not built_graph.is_empty(), "NPC navigation: nearby imported collision yields a connected random-walk patch")
	if built_graph.is_empty():
		_restore(game, player, old_player_position, old_player_controls, old_game_process, entity, old_npc_position, old_npc_level, old_talking, old_npc_visible, old_collider_disabled, old_physics)
		return

	entity.set_talking(false)
	entity.update_representation(route_spot, "ACTIVE", true)
	check.call(entity.route_nodes.size() >= 8 and not entity.next_waypoint_id.is_empty(), "NPC navigation: active NPC selects a safe connected waypoint")
	var branch_id := ""
	for id: String in entity.route_nodes:
		if (entity.route_nodes[id]["links"] as Array).size() >= 2:
			branch_id = id
			break
	var observed_choices: Dictionary = {}
	if not branch_id.is_empty():
		var choice_rng := RandomNumberGenerator.new()
		choice_rng.seed = 90125
		for _choice in range(24):
			observed_choices[router.choose_next(entity.route_nodes, branch_id, "", choice_rng)] = true
	check.call(observed_choices.size() >= 2, "NPC navigation: junctions offer varied random route choices")
	var start_position := entity.global_position
	entity.route_pause_seconds = 0.0
	for _frame in range(150):
		await game.get_tree().physics_frame
	var distance_walked := Vector2(entity.global_position.x - start_position.x, entity.global_position.z - start_position.z).length()
	check.call(distance_walked >= 0.65, "NPC navigation: random route moves the CharacterBody through the mapped area")
	var body_clear := router._capsule_clear(game.get_world_3d().direct_space_state, entity.collider.shape, exclusions, entity.global_position)
	check.call(entity.route_nodes.has(entity.current_waypoint_id) and body_clear, "NPC navigation: moving body stays inside the collision-checked route space")

	_restore(game, player, old_player_position, old_player_controls, old_game_process, entity, old_npc_position, old_npc_level, old_talking, old_npc_visible, old_collider_disabled, old_physics)
	await game.get_tree().physics_frame


func _restore(game: Node3D, player: PlayerController, player_position: Vector3, player_controls: bool, game_process: bool, entity: NPCController, npc_position: Vector3, npc_level: String, talking: bool, npc_visible: bool, collider_disabled: bool, physics_enabled: bool) -> void:
	game.set_process(game_process)
	player.global_position = player_position
	player.velocity = Vector3.ZERO
	player.controls_enabled = player_controls
	entity.global_position = npc_position
	entity.velocity = Vector3.ZERO
	entity.level = npc_level
	entity.visible = npc_visible
	entity.collider.set_deferred("disabled", collider_disabled)
	entity.set_physics_process(physics_enabled)
	entity.set_talking(talking)
