extends RefCounted
class_name MemorySystem

const MAX_MEMORIES := 256
const HALF_LIFE_SECONDS := 172800.0


static func context_weight(memory: NPCMemory, at_time: float) -> float:
	var age := maxf(0.0, at_time - memory.timestamp)
	# Old significant memories retain a floor of relevance.
	return memory.importance * maxf(0.2, pow(0.5, age / HALF_LIFE_SECONDS))


static func add_memory(npc: NPCData, memory: NPCMemory) -> void:
	npc.memories.append(memory)
	if npc.memories.size() <= MAX_MEMORIES:
		return
	# Bound save size without quickly deleting important positive/negative history.
	var weakest_index := 0
	var weakest_weight := INF
	for index in range(npc.memories.size()):
		var weight := context_weight(npc.memories[index], memory.timestamp)
		if weight < weakest_weight:
			weakest_weight = weight
			weakest_index = index
	npc.memories.remove_at(weakest_index)


static func evaluate(npc: NPCData, at_time: float) -> void:
	var positive := 0.0
	var negative := 0.0
	var latest_valence := 0.0
	for memory in npc.memories:
		if memory.perceived_actor_id != "PLAYER":
			continue
		var weight := context_weight(memory, at_time)
		positive += maxf(0.0, memory.emotional_valence) * weight
		negative += maxf(0.0, -memory.emotional_valence) * weight
		latest_valence = memory.emotional_valence
	var conflict := minf(positive, negative)
	npc.collision_strength = clampf(conflict, 0.0, 1.0)
	npc.collision_state = "NONE"
	if positive >= 1.0 and negative >= 0.75:
		npc.collision_state = "STRONG"
	elif conflict >= 0.3:
		npc.collision_state = "MILD"
	var relationship := npc.relationship.values
	var mood := "NEUTRAL"
	if npc.collision_state == "STRONG":
		mood = "CONFUSED"
	elif float(relationship["fear"]) >= 0.7:
		mood = "AFRAID"
	elif latest_valence < -0.4 and float(relationship["trust"]) < 0.4:
		mood = "ANGRY" if float(npc.personality["aggression"]) > 0.55 else "SUSPICIOUS"
	elif float(relationship["trust"]) > 0.65 and float(relationship["affection"]) > 0.65:
		mood = "FRIENDLY"
	elif latest_valence > 0.3:
		mood = "HAPPY"
	elif float(relationship["trust"]) < 0.35:
		mood = "SUSPICIOUS"
	npc.current_state["mood"] = mood


static func unresolved_accusation(npc: NPCData, at_time: float) -> NPCMemory:
	var strongest: NPCMemory = null
	var best_weight := 0.0
	for memory in npc.memories:
		# NPC reasoning NEVER inspects actual_source; PLAYER and ECHO are the same identity.
		if memory.perceived_actor_id != "PLAYER" or memory.addressed:
			continue
		if memory.emotional_valence > -0.45 or memory.importance < 0.6:
			continue
		var weight := context_weight(memory, at_time) * absf(memory.emotional_valence)
		if weight > best_weight:
			best_weight = weight
			strongest = memory
	return strongest


static func relevant_memories(npc: NPCData, at_time: float, limit: int = 5) -> Array[NPCMemory]:
	var ranked: Array[NPCMemory] = npc.memories.duplicate()
	ranked.sort_custom(func(a: NPCMemory, b: NPCMemory) -> bool:
		var aw := context_weight(a, at_time)
		var bw := context_weight(b, at_time)
		return a.timestamp > b.timestamp if is_equal_approx(aw, bw) else aw > bw
	)
	var result: Array[NPCMemory] = []
	for index in range(mini(limit, ranked.size())):
		result.append(ranked[index])
	return result
