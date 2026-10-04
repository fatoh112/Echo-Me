extends RefCounted
class_name WorldAction

var id := ""
var timestamp := 0.0
# Both actor fields describe the identity witnesses perceive.
var actor_id := "PLAYER"
var perceived_actor_id := "PLAYER"
var actual_source := "PLAYER"
var target_id := ""
var location_id := ""
var action_type := ""
var behavior_effects: Dictionary = {}
var relationship_effects: Dictionary = {}
var memory_effects: Dictionary = {}
var severity := 1.0
var metadata: Dictionary = {}


static func create(
	kind: String, target: String, location: String, source: String = "PLAYER",
	at_time: float = -1.0, event_id: String = ""
) -> WorldAction:
	var definition := ActionCatalog.definition(kind)
	if definition.is_empty():
		push_error("Unknown action: " + kind)
		return null
	var action := WorldAction.new()
	action.action_type = kind.to_upper()
	action.target_id = target
	action.location_id = location
	action.actual_source = source
	action.timestamp = Time.get_unix_time_from_system() if at_time < 0.0 else at_time
	action.id = "%s-%d-%d" % [source, int(action.timestamp), Time.get_ticks_usec()] if event_id.is_empty() else event_id
	action.behavior_effects = DataUtils.dictionary(definition.get("behavior_effects", {})).duplicate(true)
	action.relationship_effects = DataUtils.dictionary(definition.get("relationship_effects", {})).duplicate(true)
	action.memory_effects = DataUtils.dictionary(definition.get("memory_effects", {})).duplicate(true)
	return action


func to_dict() -> Dictionary:
	return {
		"id": id, "timestamp": timestamp, "actor_id": actor_id,
		"perceived_actor_id": perceived_actor_id, "actual_source": actual_source,
		"target_id": target_id, "location_id": location_id, "action_type": action_type,
		"behavior_effects": behavior_effects.duplicate(true),
		"relationship_effects": relationship_effects.duplicate(true),
		"memory_effects": memory_effects.duplicate(true),
		"severity": severity, "metadata": metadata.duplicate(true),
	}


static func from_dict(data: Dictionary) -> WorldAction:
	var action := WorldAction.new()
	action.id = str(data.get("id", data.get("action_id", "")))
	action.timestamp = DataUtils.number(data.get("timestamp", data.get("timestamp_unix", 0.0)), 0.0)
	action.actor_id = str(data.get("actor_id", "PLAYER"))
	action.perceived_actor_id = str(data.get("perceived_actor_id", "PLAYER"))
	action.actual_source = str(data.get("actual_source", data.get("actor_source", "PLAYER")))
	action.target_id = str(data.get("target_id", ""))
	action.location_id = str(data.get("location_id", "street"))
	action.action_type = str(data.get("action_type", "IGNORE")).to_upper()
	action.behavior_effects = DataUtils.dictionary(data.get("behavior_effects", {})).duplicate(true)
	action.relationship_effects = DataUtils.dictionary(data.get("relationship_effects", {})).duplicate(true)
	action.memory_effects = DataUtils.dictionary(data.get("memory_effects", {})).duplicate(true)
	action.severity = DataUtils.unit(data.get("severity", 1.0), 1.0)
	action.metadata = DataUtils.dictionary(data.get("metadata", {})).duplicate(true)
	return action
