extends RefCounted
class_name ActionSystem


static func apply(world: WorldState, action: WorldAction) -> bool:
	if action == null or not world.npcs.has(action.target_id):
		return false
	var npc: NPCData = world.npcs[action.target_id]
	if action.actual_source == "PLAYER":
		if action.action_type == "DENY" and not bool(action.metadata.get("denial_truthful", true)):
			action.behavior_effects["honesty"] = -0.7
		world.player_profile.apply_action(action)
		world.last_player_location = action.location_id
		world.refresh_echo()
	action.relationship_effects = RelationshipSystem.apply(npc, action, world.reputation)
	var response_to := str(action.metadata.get("response_to_memory_id", ""))
	if not response_to.is_empty():
		for memory in npc.memories:
			if memory.id == response_to:
				memory.addressed = true
	MemorySystem.add_memory(npc, NPCMemory.from_action(action))
	var valence := DataUtils.number(action.memory_effects.get("emotional_valence", 0.0), 0.0)
	npc.needs["social"] = clampf(float(npc.needs["social"]) - maxf(0.0, valence) * 0.06, 0.0, 1.0)
	npc.needs["security"] = clampf(float(npc.needs["security"]) + maxf(0.0, -valence) * 0.05, 0.0, 1.0)
	if action.action_type == "GIVE":
		npc.needs["resources"] = clampf(float(npc.needs["resources"]) - 0.06, 0.0, 1.0)
	world.reputation.apply_action(action)
	MemorySystem.evaluate(npc, action.timestamp)
	world.event_history.append(action)
	while world.event_history.size() > 128:
		world.event_history.pop_front()
	return true
