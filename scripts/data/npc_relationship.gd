extends RefCounted
class_name NPCRelationship

const VALUE_NAMES: Array[String] = ["trust", "fear", "respect", "affection"]
const DEFAULT_VALUE := 0.5

var values: Dictionary = {}


func _init() -> void:
	for value_name: String in VALUE_NAMES:
		values[value_name] = DEFAULT_VALUE


func apply_action(action: WorldAction) -> void:
	for value_name: String in action.relationship_delta:
		if values.has(value_name):
			values[value_name] = clampf(float(values[value_name]) + float(action.relationship_delta[value_name]), 0.0, 1.0)


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for value_name: String in VALUE_NAMES:
		result[value_name] = clampf(float(values.get(value_name, DEFAULT_VALUE)), 0.0, 1.0)
	return result


static func from_dict(data: Dictionary) -> NPCRelationship:
	var relationship := NPCRelationship.new()
	for value_name: String in VALUE_NAMES:
		relationship.values[value_name] = clampf(float(data.get(value_name, DEFAULT_VALUE)), 0.0, 1.0)
	return relationship
