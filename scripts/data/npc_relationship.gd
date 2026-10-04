extends RefCounted
class_name NPCRelationship

const VALUE_NAMES: Array[String] = ["trust", "fear", "respect", "affection"]
var values: Dictionary = {"trust": 0.5, "fear": 0.15, "respect": 0.5, "affection": 0.5}


func apply_effects(effects: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	for value_name in VALUE_NAMES:
		var before := float(values[value_name])
		values[value_name] = clampf(before + DataUtils.number(effects.get(value_name, 0.0), 0.0), 0.0, 1.0)
		applied[value_name] = float(values[value_name]) - before
	return applied


func to_dict() -> Dictionary:
	return values.duplicate(true)


static func from_dict(data: Dictionary) -> NPCRelationship:
	var relationship := NPCRelationship.new()
	for value_name in VALUE_NAMES:
		relationship.values[value_name] = DataUtils.unit(data.get(value_name, relationship.values[value_name]))
	return relationship
