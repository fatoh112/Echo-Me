extends RefCounted
class_name ReputationSystem

const VALUE_NAMES: Array[String] = ["kindness", "danger", "trustworthiness"]
var values: Dictionary = {"kindness": 0.5, "danger": 0.2, "trustworthiness": 0.5}


func apply_action(action: WorldAction) -> void:
	var effects := DataUtils.dictionary(ActionCatalog.definition(action.action_type).get("reputation_effects", {}))
	for value_name in VALUE_NAMES:
		values[value_name] = clampf(float(values[value_name]) + DataUtils.number(effects.get(value_name, 0.0), 0.0) * action.severity, 0.0, 1.0)


func to_dict() -> Dictionary:
	return values.duplicate(true)


static func from_dict(data: Dictionary) -> ReputationSystem:
	var reputation := ReputationSystem.new()
	for value_name in VALUE_NAMES:
		reputation.values[value_name] = DataUtils.unit(data.get(value_name, reputation.values[value_name]))
	return reputation
