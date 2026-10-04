extends RefCounted
class_name NPCMemory

var memory_id: String = ""
var timestamp_unix: float = 0.0
var attributed_actor: String = "PLAYER"
var actual_source: String = "PLAYER"
var description: String = ""


static func from_action(action: WorldAction) -> NPCMemory:
	var memory := NPCMemory.new()
	memory.memory_id = action.action_id
	memory.timestamp_unix = action.timestamp_unix
	memory.attributed_actor = action.attributed_actor
	memory.actual_source = action.actor_source
	var actor_label := "the player" if action.attributed_actor == "PLAYER" else action.attributed_actor
	memory.description = "Alex remembers that %s %s." % [actor_label, action.get_memory_phrase()]
	return memory


func to_dict() -> Dictionary:
	return {
		"memory_id": memory_id,
		"timestamp_unix": timestamp_unix,
		"attributed_actor": attributed_actor,
		"actual_source": actual_source,
		"description": description,
	}


static func from_dict(data: Dictionary) -> NPCMemory:
	var memory := NPCMemory.new()
	memory.memory_id = str(data.get("memory_id", ""))
	memory.timestamp_unix = float(data.get("timestamp_unix", 0.0))
	memory.attributed_actor = str(data.get("attributed_actor", "PLAYER"))
	memory.actual_source = str(data.get("actual_source", "PLAYER"))
	memory.description = str(data.get("description", ""))
	return memory
