extends RefCounted
class_name PlayerBehaviorProfile

const TRAIT_NAMES: Array[String] = [
	"aggression",
	"empathy",
	"honesty",
	"generosity",
	"loyalty",
	"risk_taking",
]
const DEFAULT_TRAIT_VALUE := 0.5

var traits: Dictionary = {}


func _init() -> void:
	for trait_name: String in TRAIT_NAMES:
		traits[trait_name] = DEFAULT_TRAIT_VALUE


func apply_action(action: WorldAction) -> void:
	for trait_name: String in action.trait_delta:
		if traits.has(trait_name):
			traits[trait_name] = clampf(float(traits[trait_name]) + float(action.trait_delta[trait_name]), 0.0, 1.0)


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for trait_name: String in TRAIT_NAMES:
		result[trait_name] = clampf(float(traits.get(trait_name, DEFAULT_TRAIT_VALUE)), 0.0, 1.0)
	return result


static func from_dict(data: Dictionary) -> PlayerBehaviorProfile:
	var profile := PlayerBehaviorProfile.new()
	for trait_name: String in TRAIT_NAMES:
		profile.traits[trait_name] = clampf(float(data.get(trait_name, DEFAULT_TRAIT_VALUE)), 0.0, 1.0)
	return profile
