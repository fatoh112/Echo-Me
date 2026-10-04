extends RefCounted
class_name PlayerBehaviorProfile

const TRAIT_NAMES: Array[String] = [
	"aggression", "empathy", "honesty", "generosity", "loyalty", "risk_taking", "sociability",
]
const LEARNING_RATE := 0.12
var traits: Dictionary = {}


func _init() -> void:
	for trait_name in TRAIT_NAMES:
		traits[trait_name] = 0.5


func apply_action(action: WorldAction) -> void:
	for trait_name: String in action.behavior_effects:
		if not traits.has(trait_name):
			continue
		var influence := clampf(DataUtils.number(action.behavior_effects[trait_name], 0.0), -1.0, 1.0)
		var goal := 1.0 if influence > 0.0 else 0.0
		var weight := LEARNING_RATE * absf(influence) * action.severity
		traits[trait_name] = clampf(lerpf(float(traits[trait_name]), goal, weight), 0.0, 1.0)


func to_dict() -> Dictionary:
	return traits.duplicate(true)


static func from_dict(data: Dictionary) -> PlayerBehaviorProfile:
	var profile := PlayerBehaviorProfile.new()
	for trait_name in TRAIT_NAMES:
		profile.traits[trait_name] = DataUtils.unit(data.get(trait_name, 0.5))
	return profile
