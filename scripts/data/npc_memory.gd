extends RefCounted
class_name NPCMemory

var id := ""
var timestamp := 0.0
var perceived_actor_id := "PLAYER"
var actual_source := "PLAYER"
var action_type := ""
var target_id := ""
var location_id := ""
var emotional_valence := 0.0
var importance := 0.5
var trust_delta := 0.0
var fear_delta := 0.0
var respect_delta := 0.0
var affection_delta := 0.0
var summary := ""
var addressed := false


static func from_action(action: WorldAction) -> NPCMemory:
	var memory := NPCMemory.new()
	memory.id = action.id
	memory.timestamp = action.timestamp
	memory.perceived_actor_id = action.perceived_actor_id
	memory.actual_source = action.actual_source
	memory.action_type = action.action_type
	memory.target_id = action.target_id
	memory.location_id = action.location_id
	memory.emotional_valence = clampf(DataUtils.number(action.memory_effects.get("emotional_valence", 0.0), 0.0), -1.0, 1.0)
	memory.importance = DataUtils.unit(action.memory_effects.get("importance", 0.5))
	memory.trust_delta = DataUtils.number(action.relationship_effects.get("trust", 0.0), 0.0)
	memory.fear_delta = DataUtils.number(action.relationship_effects.get("fear", 0.0), 0.0)
	memory.respect_delta = DataUtils.number(action.relationship_effects.get("respect", 0.0), 0.0)
	memory.affection_delta = DataUtils.number(action.relationship_effects.get("affection", 0.0), 0.0)
	memory.summary = str(action.memory_effects.get("summary", "The player interacted with me."))
	return memory


func to_dict() -> Dictionary:
	return {
		"id": id, "timestamp": timestamp, "perceived_actor_id": perceived_actor_id,
		"actual_source": actual_source, "action_type": action_type,
		"target_id": target_id, "location_id": location_id,
		"emotional_valence": emotional_valence, "importance": importance,
		"trust_delta": trust_delta, "fear_delta": fear_delta,
		"respect_delta": respect_delta, "affection_delta": affection_delta,
		"summary": summary, "addressed": addressed,
	}


static func from_dict(data: Dictionary, fallback_target: String = "") -> NPCMemory:
	var memory := NPCMemory.new()
	memory.id = str(data.get("id", data.get("memory_id", "")))
	memory.timestamp = DataUtils.number(data.get("timestamp", data.get("timestamp_unix", 0.0)), 0.0)
	memory.perceived_actor_id = str(data.get("perceived_actor_id", data.get("attributed_actor", "PLAYER")))
	memory.actual_source = str(data.get("actual_source", "PLAYER"))
	memory.summary = str(data.get("summary", data.get("description", "A remembered interaction.")))
	memory.action_type = str(data.get("action_type", "")).to_upper()
	if memory.action_type.is_empty():
		var old_text := memory.summary.to_lower()
		if "help" in old_text:
			memory.action_type = "HELP"
		elif "gift" in old_text:
			memory.action_type = "GIVE"
		elif "insult" in old_text:
			memory.action_type = "INSULT"
		elif "stole" in old_text:
			memory.action_type = "STEAL"
		else:
			memory.action_type = "IGNORE"
	var defaults := DataUtils.dictionary(ActionCatalog.definition(memory.action_type).get("memory_effects", {}))
	memory.target_id = str(data.get("target_id", fallback_target))
	memory.location_id = str(data.get("location_id", "shop"))
	memory.emotional_valence = clampf(DataUtils.number(data.get("emotional_valence", defaults.get("emotional_valence", 0.0)), 0.0), -1.0, 1.0)
	memory.importance = DataUtils.unit(data.get("importance", defaults.get("importance", 0.5)))
	memory.trust_delta = DataUtils.number(data.get("trust_delta", 0.0), 0.0)
	memory.fear_delta = DataUtils.number(data.get("fear_delta", 0.0), 0.0)
	memory.respect_delta = DataUtils.number(data.get("respect_delta", 0.0), 0.0)
	memory.affection_delta = DataUtils.number(data.get("affection_delta", 0.0), 0.0)
	memory.addressed = bool(data.get("addressed", false))
	return memory
