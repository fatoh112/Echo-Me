extends RefCounted
class_name UtilityAI


func decide(world: WorldState, turn: int, at_time: float) -> Dictionary:
	var target_rows: Array[Dictionary] = []
	var best: Dictionary = {}
	var best_score := -INF
	var npc_ids: Array = world.npcs.keys()
	npc_ids.sort()
	for npc_id: String in npc_ids:
		var npc: NPCData = world.npcs[npc_id]
		var actions := score_actions(world, npc, turn, at_time)
		var best_action: Dictionary = actions[0]
		var target_repeat := 0
		var recent_player := false
		var start := maxi(0, world.event_history.size() - 8)
		for index in range(start, world.event_history.size()):
			var event: WorldAction = world.event_history[index]
			if event.target_id == npc_id:
				if event.actual_source == "ECHO" and index >= world.event_history.size() - 3:
					target_repeat += 1
				if event.actual_source == "PLAYER":
					recent_player = true
		var distance := world.location_position(world.echo_location_id).distance_to(world.npc_position(npc))
		var relationship := npc.relationship.values
		var significance := absf(float(relationship["trust"]) - 0.5) + absf(float(relationship["affection"]) - 0.5)
		var target_score := float(best_action["score"]) * 0.35
		target_score += npc.relationship_importance * 0.15 + significance * 0.06
		target_score += maxf(0.0, 1.0 - distance / 45.0) * 0.08
		target_score += 0.07 if recent_player else 0.0
		target_score += 0.08 if target_repeat == 0 else -0.18 * target_repeat
		target_score += float(npc.needs["social"]) * float(world.echo_profile.traits["sociability"]) * 0.04
		target_score += _variation(world.echo_seed, turn, npc_id, "TARGET")
		var row: Dictionary = {
			"target_id": npc_id, "target_name": npc.display_name,
			"target_score": target_score, "action_type": best_action["action_type"],
			"action_score": best_action["score"], "actions": actions,
		}
		target_rows.append(row)
		if target_score > best_score:
			best_score = target_score
			best = row
	return {
		"turn": turn, "target_id": best.get("target_id", ""),
		"action_type": best.get("action_type", "IGNORE"),
		"selected_score": best.get("action_score", 0.0),
		"action_scores": best.get("actions", []), "target_scores": target_rows,
	}


func score_actions(world: WorldState, npc: NPCData, turn: int, at_time: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var traits := world.echo_profile.traits
	var location := DataUtils.dictionary(world.locations.get(str(npc.current_state["location_id"]), {}))
	var opportunities := DataUtils.dictionary(location.get("opportunities", {}))
	for action_type in ActionCatalog.PRIMARY_ACTIONS:
		var definition := ActionCatalog.definition(action_type)
		var fit_weights := DataUtils.dictionary(definition.get("personality_fit", {}))
		var fit := 0.0
		var total_weight := 0.0
		for trait_name: String in fit_weights:
			var weight := float(fit_weights[trait_name])
			var value := float(traits.get(trait_name, 0.5))
			fit += (value if weight > 0.0 else 1.0 - value) * absf(weight)
			total_weight += absf(weight)
		fit /= maxf(total_weight, 0.001)
		var valence := float(DataUtils.dictionary(definition["memory_effects"])["emotional_valence"])
		var positive := valence > 0.0
		var trust := float(npc.relationship.values["trust"])
		var affection := float(npc.relationship.values["affection"])
		var relationship_context := (affection * 0.04 + (1.0 - trust) * 0.03) if positive else (1.0 - trust) * 0.07
		if action_type == "BETRAY":
			relationship_context += (trust + affection) * 0.055
		var target_fit := float(npc.personality["empathy"]) * 0.04 if positive else (1.0 - float(npc.personality["courage"])) * 0.035
		if action_type == "GIVE":
			target_fit += float(npc.personality["greed"]) * 0.04 + float(npc.needs["resources"]) * 0.025
		var opportunity := float(opportunities.get(action_type, 0.45)) * 0.08
		if str(npc.current_state["activity"]) == "working" and action_type == "HELP":
			opportunity += 0.025
		var repeats := 0.0
		var context := 0.0
		var first := maxi(0, npc.memories.size() - 5)
		for index in range(first, npc.memories.size()):
			var memory: NPCMemory = npc.memories[index]
			if memory.perceived_actor_id != "PLAYER":
				continue
			var weight := MemorySystem.context_weight(memory, at_time)
			if memory.action_type == action_type:
				repeats += weight
			if positive:
				context += maxf(0.0, -memory.emotional_valence) * weight * float(traits["empathy"]) * 0.008
			else:
				context += maxf(0.0, memory.emotional_valence) * weight * (1.0 - float(traits["loyalty"])) * 0.008
		var novelty := 0.035 if repeats < 0.01 else 0.0
		var repetition_penalty := minf(0.50, repeats * 0.15)
		var risk := float(definition.get("risk", 0.0)) * (1.0 - float(traits["risk_taking"])) * 0.16
		risk += float(npc.personality["courage"]) * 0.035 if not positive else 0.0
		var reputation_context := float(world.reputation.values["danger"]) * 0.015 if not positive else float(world.reputation.values["kindness"]) * 0.012
		if npc.id == "noah" and not positive:
			risk += float(world.reputation.values["danger"]) * 0.04
		var variation := _variation(world.echo_seed, turn, npc.id, action_type)
		var score := fit + relationship_context + target_fit + opportunity + context + novelty + reputation_context - repetition_penalty - risk + variation
		rows.append({
			"action_type": action_type, "score": score,
			"factors": {
				"personality_fit": fit, "relationship": relationship_context,
				"target_personality": target_fit, "opportunity": opportunity,
				"memory_context": context, "novelty": novelty,
				"repetition_penalty": repetition_penalty, "risk": risk,
				"reputation": reputation_context, "seeded_variation": variation,
			},
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["score"]), float(b["score"])):
			return str(a["action_type"]) < str(b["action_type"])
		return float(a["score"]) > float(b["score"])
	)
	return rows


func _variation(save_seed: int, turn: int, npc_id: String, action_type: String) -> float:
	var random := RandomNumberGenerator.new()
	random.seed = save_seed + turn * 1009 + int((npc_id + ":" + action_type).hash())
	return random.randf_range(-0.012, 0.012)
