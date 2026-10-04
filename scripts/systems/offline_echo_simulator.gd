extends RefCounted
class_name OfflineEchoSimulator

const MAX_ACTIONS_PER_OFFLINE_PERIOD := 8


func simulate_elapsed(
	elapsed_seconds: float,
	player_profile: PlayerBehaviorProfile,
	relationship: NPCRelationship
) -> Array[WorldAction]:
	var simulated_count := mini(
		MAX_ACTIONS_PER_OFFLINE_PERIOD,
		maxi(1, floori(elapsed_seconds / 60.0))
	)
	var actions: Array[WorldAction] = []
	for _index: int in range(simulated_count):
		var echo_profile := EchoBehaviorProfile.from_player(player_profile)
		var action_type := _choose_action(echo_profile, relationship)
		var action := WorldAction.create(action_type, "ECHO", "PLAYER", AlexController.NPC_ID)
		if action == null:
			continue
		relationship.apply_action(action)
		actions.append(action)
	return actions


func _choose_action(echo_profile: EchoBehaviorProfile, relationship: NPCRelationship) -> String:
	var traits: Dictionary = echo_profile.traits
	var trust: float = float(relationship.values.get("trust", 0.5))
	var scores: Dictionary = {
		"help": float(traits["empathy"]) * 0.45 + float(traits["generosity"]) * 0.35 + float(traits["loyalty"]) * 0.20,
		"give": float(traits["generosity"]) * 0.55 + float(traits["empathy"]) * 0.25 + float(traits["loyalty"]) * 0.20,
		"insult": float(traits["aggression"]) * 0.45 + (1.0 - float(traits["empathy"])) * 0.30 + float(traits["risk_taking"]) * 0.15 + (1.0 - trust) * 0.10,
		"steal": float(traits["risk_taking"]) * 0.40 + (1.0 - float(traits["honesty"])) * 0.35 + float(traits["aggression"]) * 0.15 + (1.0 - trust) * 0.10,
	}
	var best_action := "help"
	var best_score := -INF
	for action_type: String in ["help", "give", "insult", "steal"]:
		var score := float(scores[action_type])
		if score > best_score:
			best_score = score
			best_action = action_type
	return best_action
