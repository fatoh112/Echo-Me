extends RefCounted
class_name OfflineEchoSimulator

var utility := UtilityAI.new()


static func turn_count(elapsed_seconds: float) -> int:
	if elapsed_seconds < 60.0:
		return 0
	if elapsed_seconds < 300.0:
		return 1
	if elapsed_seconds < 900.0:
		return 2
	if elapsed_seconds < 3600.0:
		return 3
	if elapsed_seconds < 7200.0:
		return 4
	if elapsed_seconds < 10800.0:
		return 5
	if elapsed_seconds < 14400.0:
		return 6
	return 8


func simulate_elapsed(elapsed_seconds: float, world: WorldState, logout_timestamp: float) -> Array[WorldAction]:
	var actions: Array[WorldAction] = []
	var count := turn_count(elapsed_seconds)
	if count == 0:
		return actions
	world.last_offline_events.clear()
	world.last_decisions.clear()
	world.refresh_echo()
	for index in range(count):
		world.game_minutes += 30.0
		world.update_schedules()
		world.echo_turn_index += 1
		# Canonical times depend on saved state + bucket, never the precise launch second.
		var at_time := logout_timestamp + (index + 1) * 60.0
		var decision := utility.decide(world, world.echo_turn_index, at_time)
		var target_id := str(decision["target_id"])
		if not world.npcs.has(target_id):
			continue
		var npc: NPCData = world.npcs[target_id]
		var event_id := "echo-%d-%d-%d" % [world.echo_seed, int(logout_timestamp), world.echo_turn_index]
		var action := WorldAction.create(str(decision["action_type"]), npc.id, str(npc.current_state["location_id"]), "ECHO", at_time, event_id)
		action.metadata["utility_score"] = decision["selected_score"]
		if ActionSystem.apply(world, action):
			actions.append(action)
			world.last_offline_events.append(action)
			world.last_decisions.append(decision)
			world.echo_location_id = action.location_id
	return actions
