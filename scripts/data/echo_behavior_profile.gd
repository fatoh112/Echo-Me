extends RefCounted
class_name EchoBehaviorProfile

var traits: Dictionary = {}


static func from_player(player_profile: PlayerBehaviorProfile) -> EchoBehaviorProfile:
	var profile := EchoBehaviorProfile.new()
	for trait_name: String in PlayerBehaviorProfile.TRAIT_NAMES:
		profile.traits[trait_name] = 1.0 - clampf(float(player_profile.traits.get(trait_name, 0.5)), 0.0, 1.0)
	return profile


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for trait_name: String in PlayerBehaviorProfile.TRAIT_NAMES:
		result[trait_name] = clampf(float(traits.get(trait_name, 0.5)), 0.0, 1.0)
	return result
