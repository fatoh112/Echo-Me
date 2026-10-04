extends RefCounted
class_name WorldAction

const ACTION_DEFINITIONS: Dictionary = {
	"help": {
		"past_tense": "helped Alex",
		"memory_phrase": "helped them",
		"trait_delta": {"empathy": 0.10, "generosity": 0.04, "loyalty": 0.02},
		"relationship_delta": {"trust": 0.12, "fear": -0.05, "respect": 0.08, "affection": 0.05},
	},
	"give": {
		"past_tense": "gave Alex a small gift",
		"memory_phrase": "gave them a small gift",
		"trait_delta": {"generosity": 0.12, "empathy": 0.05},
		"relationship_delta": {"trust": 0.08, "fear": -0.02, "respect": 0.04, "affection": 0.13},
	},
	"insult": {
		"past_tense": "insulted Alex",
		"memory_phrase": "insulted them",
		"trait_delta": {"aggression": 0.12, "empathy": -0.08},
		"relationship_delta": {"trust": -0.10, "fear": 0.13, "respect": -0.08, "affection": -0.12},
	},
	"steal": {
		"past_tense": "stole something from Alex",
		"memory_phrase": "stole something from them",
		"trait_delta": {"honesty": -0.15, "risk_taking": 0.12, "aggression": 0.04},
		"relationship_delta": {"trust": -0.20, "fear": 0.03, "respect": -0.04, "affection": -0.10},
	},
}

var action_id: String = ""
var action_type: String = ""
var actor_source: String = "PLAYER"
var attributed_actor: String = "PLAYER"
var target_id: String = "alex"
var timestamp_unix: float = 0.0
var trait_delta: Dictionary = {}
var relationship_delta: Dictionary = {}


static func create(
	action_kind: String,
	source: String = "PLAYER",
	claimed_actor: String = "PLAYER",
	target: String = "alex"
) -> WorldAction:
	if not ACTION_DEFINITIONS.has(action_kind):
		push_error("Unknown WorldAction kind: %s" % action_kind)
		return null

	var definition: Dictionary = ACTION_DEFINITIONS[action_kind]
	var action := WorldAction.new()
	action.action_id = "%s-%s" % [source.to_lower(), Time.get_ticks_usec()]
	action.action_type = action_kind
	action.actor_source = source
	action.attributed_actor = claimed_actor
	action.target_id = target
	action.timestamp_unix = Time.get_unix_time_from_system()
	action.trait_delta = (definition["trait_delta"] as Dictionary).duplicate(true)
	action.relationship_delta = (definition["relationship_delta"] as Dictionary).duplicate(true)
	return action


func get_past_tense() -> String:
	return str(ACTION_DEFINITIONS.get(action_type, {}).get("past_tense", "acted near Alex"))


func get_memory_phrase() -> String:
	return str(ACTION_DEFINITIONS.get(action_type, {}).get("memory_phrase", "acted near them"))


func to_dict() -> Dictionary:
	return {
		"action_id": action_id,
		"action_type": action_type,
		"actor_source": actor_source,
		"attributed_actor": attributed_actor,
		"target_id": target_id,
		"timestamp_unix": timestamp_unix,
		"trait_delta": trait_delta.duplicate(true),
		"relationship_delta": relationship_delta.duplicate(true),
	}


static func from_dict(data: Dictionary) -> WorldAction:
	var action := WorldAction.new()
	action.action_id = str(data.get("action_id", ""))
	action.action_type = str(data.get("action_type", ""))
	action.actor_source = str(data.get("actor_source", "PLAYER"))
	action.attributed_actor = str(data.get("attributed_actor", "PLAYER"))
	action.target_id = str(data.get("target_id", "alex"))
	action.timestamp_unix = float(data.get("timestamp_unix", 0.0))
	var trait_values: Variant = data.get("trait_delta", {})
	var relationship_values: Variant = data.get("relationship_delta", {})
	action.trait_delta = trait_values.duplicate(true) if trait_values is Dictionary else {}
	action.relationship_delta = relationship_values.duplicate(true) if relationship_values is Dictionary else {}
	return action
