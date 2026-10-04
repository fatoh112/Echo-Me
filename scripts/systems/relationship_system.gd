extends RefCounted
class_name RelationshipSystem


static func apply(npc: NPCData, action: WorldAction, reputation: ReputationSystem) -> Dictionary:
	var scaled: Dictionary = {}
	for value_name: String in action.relationship_effects:
		var effect := DataUtils.number(action.relationship_effects[value_name], 0.0) * action.severity
		var multiplier := 1.0
		if value_name == "fear":
			multiplier = 0.55 + (1.0 - float(npc.personality["courage"])) * 0.8
		elif effect < 0.0:
			multiplier = 1.20 - float(npc.personality["forgiveness"]) * 0.4
		else:
			multiplier = 0.85 + float(npc.personality["empathy"]) * 0.3
		if action.action_type == "GIVE" and effect > 0.0:
			multiplier += float(npc.personality["greed"]) * 0.2
		if npc.role == "Neighborhood watch" and action.action_type in ["STEAL", "THREATEN", "BETRAY", "INSULT"]:
			multiplier *= 1.35
			if value_name == "trust":
				var repeated := 0
				for memory in npc.memories:
					if memory.emotional_valence < -0.4 and memory.perceived_actor_id == "PLAYER":
						repeated += 1
				multiplier += mini(repeated, 4) * 0.08 + float(reputation.values["danger"]) * 0.15
		scaled[value_name] = effect * multiplier
	return npc.relationship.apply_effects(scaled)
