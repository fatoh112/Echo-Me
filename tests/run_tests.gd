extends SceneTree

var failures := 0
var checks := 0
var scratch_paths: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _event(world: WorldState, kind: String, target: String, source: String, time_value: float) -> WorldAction:
	var npc: NPCData = world.npcs[target]
	var action := WorldAction.create(kind, target, str(npc.current_state["location_id"]), source, time_value, "%s-%s-%d" % [source, kind, int(time_value)])
	_check(ActionSystem.apply(world, action), "Action applies: " + kind)
	return action


func _run() -> void:
	var world := WorldState.new(12345)
	var sarah: NPCData = world.npcs["sarah"]
	var original_trust := float(sarah.relationship.values["trust"])
	for index in range(8):
		_event(world, "HELP", "sarah", "PLAYER", 1000000.0 + index)
	_check(float(world.player_profile.traits["empathy"]) > 0.7, "A: repeated HELP raises player empathy gradually")
	_check(float(sarah.relationship.values["trust"]) > original_trust, "A: Sarah trust rises independently")
	_check((world.npcs["alex"] as NPCData).memories.is_empty(), "A: Alex history is independent")
	var first_change := PlayerBehaviorProfile.new()
	first_change.apply_action(WorldAction.create("GIVE", "sarah", "RESIDENTIAL_ROW"))
	_check(float(first_change.traits["generosity"]) <= 0.561, "Profile EMA avoids giant jumps")
	for trait_name in PlayerBehaviorProfile.TRAIT_NAMES:
		_check(absf(float(world.echo_profile.traits[trait_name]) - (1.0 - float(world.player_profile.traits[trait_name]))) <= EchoBehaviorProfile.MAX_DISTORTION + 0.00001, "Bounded inverse: " + trait_name)

	var hostile_world := WorldState.new(12345)
	hostile_world.player_profile.traits["empathy"] = 0.95
	hostile_world.player_profile.traits["generosity"] = 0.95
	hostile_world.player_profile.traits["honesty"] = 0.95
	hostile_world.player_profile.traits["loyalty"] = 0.90
	hostile_world.player_profile.traits["aggression"] = 0.05
	hostile_world.refresh_echo()
	_check(float(hostile_world.echo_profile.traits["empathy"]) < 0.09, "B: high empathy gives low-empathy Echo")
	var ranked := UtilityAI.new().score_actions(hostile_world, hostile_world.npcs["sarah"], 1, 1000000.0)
	var selected_definition := ActionCatalog.definition(str(ranked[0]["action_type"]))
	_check(float(DataUtils.dictionary(selected_definition["memory_effects"])["emotional_valence"]) < 0.0, "B: inverse Echo favors hostile/selfish action")

	var positive_ids: Array[String] = []
	for memory in sarah.memories:
		positive_ids.append(memory.id)
	var profile_before := world.player_profile.to_dict()
	_event(world, "BETRAY", "sarah", "ECHO", 1000010.0)
	var betrayal: NPCMemory = sarah.memories.back()
	_check(betrayal.perceived_actor_id == "PLAYER" and betrayal.actual_source == "ECHO", "C: Echo betrayal is perceived PLAYER, internally ECHO")
	_check(world.player_profile.to_dict() == profile_before, "C: Echo does not train actual player profile")
	_check(sarah.memories.size() == 9, "D: positive history retained alongside betrayal")
	for index in range(8):
		_check(sarah.memories[index].id == positive_ids[index], "D: old positive memory preserved")
	_check(sarah.collision_state == "STRONG", "D: contradictory important memories produce STRONG collision")
	_check(str(sarah.current_state["mood"]) == "CONFUSED", "D: collision drives CONFUSED mood")
	_check(MemorySystem.unresolved_accusation(sarah, 1000011.0) == betrayal, "Accusation selects unaddressed hostile PLAYER memory")
	var same_npc := NPCData.from_definition({"id": "sarah"})
	same_npc.restore(sarah.to_dict())
	for memory in same_npc.memories:
		memory.actual_source = "PLAYER"
	MemorySystem.evaluate(same_npc, 1000010.0)
	_check(same_npc.collision_state == sarah.collision_state and same_npc.current_state["mood"] == sarah.current_state["mood"], "NPC reasoning cannot distinguish PLAYER/ECHO sources")

	var manager := SaveManager.new()
	var save_path := "user://echo_me_self_test_%d.json" % Time.get_ticks_usec()
	scratch_paths.append(save_path)
	world.game_minutes = 777.0
	world.player_position = Vector3(3, 0, 7)
	world.last_player_location = "RESIDENTIAL_ROW"
	_check(manager.save_world(world, 1000011.0, save_path), "E: save succeeds")
	var loaded := manager.load_world(save_path)
	_check(_same_data(world.to_dict(), loaded.to_dict()), "E: complete traits/relationships/memories/reputation/world-state round trip")
	_check(manager.logout_timestamp == 1000011.0, "E: logout timestamp persists")
	_check(manager.save_world(loaded, 1000012.0, save_path), "E: atomic replacement succeeds")
	_check(FileAccess.file_exists(save_path + ".previous.json"), "E: previous good save backed up")

	_test_migration(manager)
	_test_offline(manager)
	_test_catalog()
	_check(NPCManager.activity_level_for(3) == "ACTIVE" and NPCManager.activity_level_for(20) == "BACKGROUND" and NPCManager.activity_level_for(40) == "LOGICAL", "Distance activity LOD")
	var scheduled_world := WorldState.new()
	scheduled_world.game_minutes = 1200
	scheduled_world.update_schedules()
	_check(str((scheduled_world.npcs["alex"] as NPCData).current_state["location_id"]) == "RESIDENTIAL_ROW", "Alex evening schedule")
	_check(str((scheduled_world.npcs["emma"] as NPCData).current_state["location_id"]) == "RESIDENTIAL_ROW", "Emma evening schedule")
	await _test_scene()
	manager.free()
	_cleanup()
	print("ECHO ME SELF TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_migration(manager: SaveManager) -> void:
	var legacy_path := "user://echo_me_self_test_legacy_%d.json" % Time.get_ticks_usec()
	scratch_paths.append(legacy_path)
	var legacy: Dictionary = {
		"save_version": 1, "logout_timestamp": 1000000.0,
		"player_traits": {"empathy": 0.9, "generosity": 0.85},
		"alex_relationship": {"trust": 0.2, "fear": 0.7, "respect": 0.4, "affection": 0.3},
		"alex_memories": [
			{"memory_id": "positive", "timestamp_unix": 999900.0, "attributed_actor": "PLAYER", "actual_source": "PLAYER", "description": "Alex remembers that the player helped them."},
			{"memory_id": "negative", "timestamp_unix": 999950.0, "attributed_actor": "PLAYER", "actual_source": "ECHO", "description": "Alex remembers that the player insulted them."},
		],
	}
	var original := JSON.stringify(legacy)
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var migrated := manager.load_world(legacy_path)
	var alex: NPCData = migrated.npcs["alex"]
	_check(migrated.npcs.size() == 6 and float(migrated.player_profile.traits["sociability"]) == 0.5, "Legacy migration supplies six NPCs and new trait")
	_check(is_equal_approx(float(migrated.player_profile.traits["empathy"]), 0.9) and is_equal_approx(float(alex.relationship.values["trust"]), 0.2), "Legacy profile/relationship values retained")
	_check(alex.memories.size() == 2 and alex.memories[1].actual_source == "ECHO", "Legacy memories and hidden source retained")
	_check(alex.memories[0].action_type == "HELP" and alex.memories[1].action_type == "INSULT", "Legacy memory meaning recovered")
	_check(FileAccess.file_exists(legacy_path + ".v1.backup.json"), "Legacy backup created before migration")
	var backup := FileAccess.open(legacy_path + ".v1.backup.json", FileAccess.READ)
	_check(backup.get_as_text() == original, "Legacy backup is exact")
	backup.close()
	_check(manager.save_world(migrated, 1000010.0, legacy_path), "Migrated v2 save can replace v1 safely")
	var parsed := DataUtils.dictionary(DataUtils.read_json(legacy_path))
	_check(int(parsed["save_version"]) == 2, "Saved schema is version 2")
	var defaults := WorldState.from_dict({"save_version": 2})
	_check(defaults.npcs.size() == 6 and defaults.player_profile.traits.size() == 7, "Missing v2 fields handled with defaults")


func _test_offline(manager: SaveManager) -> void:
	var simulator := OfflineEchoSimulator.new()
	var durations: Array[float] = [59.9, 60, 299, 300, 899, 900, 3600, 7200, 10800, 14400, 1000000000]
	var counts: Array[int] = [0, 1, 1, 2, 2, 3, 4, 5, 6, 8, 8]
	for index in range(durations.size()):
		_check(OfflineEchoSimulator.turn_count(durations[index]) == counts[index], "Offline bucket/cap: %.1f" % durations[index])
	var seed_world := WorldState.new(321)
	var saved := seed_world.to_dict()
	var first := WorldState.from_dict(saved)
	var second := WorldState.from_dict(saved)
	simulator.simulate_elapsed(601, first, 1000000)
	simulator.simulate_elapsed(899, second, 1000000)
	_check(JSON.stringify(first.to_dict()) == JSON.stringify(second.to_dict()), "Same save/seed/elapsed bucket produces identical result")
	var many := WorldState.from_dict(saved)
	var simulation_start := Time.get_ticks_usec()
	var events := simulator.simulate_elapsed(86400, many, 1000000)
	var simulation_ms := (Time.get_ticks_usec() - simulation_start) / 1000.0
	_check(events.size() == 8 and many.last_decisions.size() == 8, "F: bounded multiple turns and utility traces")
	var targets: Dictionary = {}
	var action_kinds: Dictionary = {}
	var no_repeated_pair := true
	var previous_pair := ""
	for action in events:
		targets[action.target_id] = true
		action_kinds[action.action_type] = true
		var pair := action.target_id + ":" + action.action_type
		if pair == previous_pair:
			no_repeated_pair = false
		previous_pair = pair
		var npc: NPCData = many.npcs[action.target_id]
		var memory: NPCMemory = npc.memories.back()
		_check(memory.perceived_actor_id == "PLAYER" and memory.actual_source == "ECHO", "F: offline memory identity")
	_check(targets.size() >= 3, "F: Echo targets multiple NPCs instead of always Alex")
	_check(no_repeated_pair and action_kinds.size() >= 2, "F: action/target repetition penalties create variety")
	print("Offline cap: %d events, %d targets, %d action kinds, %.2f ms" % [events.size(), targets.size(), action_kinds.size(), simulation_ms])
	_check(many.reputation.to_dict() != seed_world.reputation.to_dict(), "Offline actions affect reputation")
	for decision: Dictionary in many.last_decisions:
		_check((decision["action_scores"] as Array).size() == 10 and (decision["target_scores"] as Array).size() == 6, "Utility scores all actions and targets")
	var path := "user://echo_me_self_test_offline_%d.json" % Time.get_ticks_usec()
	scratch_paths.append(path)
	_check(manager.save_world(many, 1000100.0, path), "Offline world can be saved")
	_check(_same_data(many.to_dict(), manager.load_world(path).to_dict()), "Offline events and utility traces survive reload")


func _test_catalog() -> void:
	for action_type in ActionCatalog.PRIMARY_ACTIONS:
		var world := WorldState.new(123)
		var before := world.player_profile.to_dict()
		var npc: NPCData = world.npcs["emma"]
		var relation_before := npc.relationship.to_dict()
		_event(world, action_type, "emma", "PLAYER", 2000000)
		_check(world.player_profile.to_dict() != before, action_type + " trains behavioral evidence")
		_check(npc.relationship.to_dict() != relation_before and npc.memories.size() == 1, action_type + " changes target relationship and memory")
		for trait_name in PlayerBehaviorProfile.TRAIT_NAMES:
			var trait_value := float(world.player_profile.traits[trait_name])
			_check(trait_value >= 0.0 and trait_value <= 1.0, action_type + " normalized player trait")


func _test_scene() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "Main packed scene loads")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(game.npc_manager.entities.size() == 6, "Live scene creates all six reusable NPCs")
	var start_position: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	for _frame in range(30):
		await physics_frame
	Input.action_release("move_forward")
	_check(game.player.global_position.distance_to(start_position) > 1.5, "Live CharacterBody3D movement")
	_check(game.player.is_on_floor(), "Live ground collision")
	var query := PhysicsRayQueryParameters3D.create(Vector3(-10, 2, -5), Vector3(-10, 2, -12))
	var building_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	_check(not building_hit.is_empty(), "Neighborhood buildings have working collision")
	var sarah: NPCData = game.world.npcs["sarah"]
	game.player.global_position = game.world.npc_position(sarah) + Vector3(0, 0, 2)
	game.npc_manager.update_entities(game.player.global_position)
	game._update_proximity()
	_check(game.nearby != null and game.nearby.id == "sarah", "Generic nearby interaction selects Sarah")
	var interact_key := InputEventKey.new()
	interact_key.keycode = KEY_E
	interact_key.physical_keycode = KEY_E
	interact_key.pressed = true
	root.push_input(interact_key)
	await process_frame
	_check(game.interaction_ui.is_modal(), "E input opens generic nearby NPC menu")
	_check(game.interaction_ui.action_grid.get_child_count() == 10, "Generic menu exposes all ten actions")
	var empathy_before: float = game.world.player_profile.traits["empathy"]
	var enter_key := InputEventKey.new()
	enter_key.keycode = KEY_ENTER
	enter_key.pressed = true
	root.push_input(enter_key)
	await process_frame
	enter_key.pressed = false
	root.push_input(enter_key)
	_check(not game.interaction_ui.is_modal() and sarah.memories.size() == 1, "Menu action runs pipeline and closes")
	_check(float(game.world.player_profile.traits["empathy"]) > empathy_before, "Live UI action trains profile")
	var betrayal := _event(game.world, "BETRAY", "sarah", "ECHO", Time.get_unix_time_from_system())
	game.interaction_ui.open_for_npc(sarah)
	_check(game.interaction_ui.action_grid.get_child_count() == 4, "Echo accusation exposes four responses")
	empathy_before = float(game.world.player_profile.traits["empathy"])
	(game.interaction_ui.action_grid.get_child(1) as Button).pressed.emit()
	_check(sarah.memories[1].addressed and sarah.memories.back().action_type == "APOLOGIZE", "Response addresses accusation and creates new memory/action")
	_check(float(game.world.player_profile.traits["empathy"]) > empathy_before, "Apology is behavioral evidence")
	var events: Array[WorldAction] = [betrayal]
	game.interaction_ui.show_offline_summary(game.world, events)
	_check(game.interaction_ui.is_modal() and not game.player.controls_enabled, "Summary locks movement and enables menu")
	_check(not game.interaction_ui.summary_debug_scroll.visible and not "BETRAY" in game.interaction_ui.summary_text.text, "Player summary conceals exact Echo action")
	_check("ECHO" in game.interaction_ui.summary_debug.text, "Internal events available in development section")
	game.interaction_ui.close_all()
	_check(game.player.controls_enabled, "Closing summary restores controls")
	await preload("res://tests/visual_checks.gd").new().run(game, _check)
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F3
	toggle.pressed = true
	game.debug_ui._input(toggle)
	_check(game.debug_ui.panel.visible, "F3 reveals debug panel")
	game.npc_manager.update_entities(Vector3(25, 0, 25))
	await process_frame
	var noah: NPCController = game.npc_manager.entities["noah"]
	_check(noah.level == "LOGICAL" and not noah.visible and noah.collider.disabled, "Logical NPC hides geometry/collision with no movement processing")
	game.queue_free()
	await process_frame


func _cleanup() -> void:
	for path in scratch_paths:
		for suffix in ["", ".tmp", ".previous.json", ".v1.backup.json", ".corrupt.backup.json"]:
			var absolute := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(absolute):
				DirAccess.remove_absolute(absolute)


func _same_data(first: Variant, second: Variant) -> bool:
	# JSON decimal parsing can differ by ~1e-17; compare numbers, identities, and schema.
	if (first is float or first is int) and (second is float or second is int):
		return absf(float(first) - float(second)) <= 0.0000000001
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size():
			return false
		for key: Variant in first:
			if not second.has(key) or not _same_data(first[key], second[key]):
				return false
		return true
	if first is Array and second is Array:
		if first.size() != second.size():
			return false
		for index in range(first.size()):
			if not _same_data(first[index], second[index]):
				return false
		return true
	return first == second
