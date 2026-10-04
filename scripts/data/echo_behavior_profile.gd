extends RefCounted
class_name EchoBehaviorProfile

const MAX_DISTORTION := 0.035
var traits: Dictionary = {}
var seed := 0


static func from_player(player_profile: PlayerBehaviorProfile, save_seed: int = 94721) -> EchoBehaviorProfile:
	var profile := EchoBehaviorProfile.new()
	profile.seed = save_seed
	var random := RandomNumberGenerator.new()
	random.seed = save_seed
	for trait_name in PlayerBehaviorProfile.TRAIT_NAMES:
		var inverse := 1.0 - float(player_profile.traits.get(trait_name, 0.5))
		profile.traits[trait_name] = clampf(inverse + random.randf_range(-MAX_DISTORTION, MAX_DISTORTION), 0.0, 1.0)
	return profile


func to_dict() -> Dictionary:
	return {"traits": traits.duplicate(true), "seed": seed}
