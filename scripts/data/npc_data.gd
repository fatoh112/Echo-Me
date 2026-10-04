extends RefCounted
class_name NPCData

const PERSONALITY_NAMES: Array[String] = [
	"aggression", "empathy", "honesty", "greed", "courage", "sociability", "forgiveness",
]
var id := ""
var display_name := ""
var role := ""
var personality: Dictionary = {}
var relationship := NPCRelationship.new()
var current_state: Dictionary = {"location_id": "TOWN_SQUARE", "activity": "relaxing", "mood": "NEUTRAL"}
var memories: Array[NPCMemory] = []
var home_location_id := "RESIDENTIAL_ROW"
var schedule: Array = []
var needs: Dictionary = {"social": 0.5, "security": 0.5, "resources": 0.5}
var relationship_importance := 0.5
var collision_state := "NONE"
var collision_strength := 0.0
var slot_offset := Vector3.ZERO
var color := Color(0.6, 0.6, 0.6)
var activity_level := "LOGICAL"


static func from_definition(definition: Dictionary) -> NPCData:
	var npc := NPCData.new()
	npc.id = str(definition.get("id", "unknown"))
	npc.display_name = str(definition.get("display_name", npc.id.capitalize()))
	npc.role = str(definition.get("role", "Neighbor"))
	npc.home_location_id = LocationRegistry.canonical(str(definition.get("home_location_id", "RESIDENTIAL_ROW")))
	npc.current_state["location_id"] = LocationRegistry.canonical(str(definition.get("initial_location_id", npc.home_location_id)))
	var traits := DataUtils.dictionary(definition.get("personality", {}))
	for trait_name in PERSONALITY_NAMES:
		npc.personality[trait_name] = DataUtils.unit(traits.get(trait_name, 0.5))
	npc.relationship = NPCRelationship.from_dict(DataUtils.dictionary(definition.get("relationship_to_player", {})))
	npc.relationship_importance = DataUtils.unit(definition.get("relationship_importance", 0.5))
	var initial_needs := DataUtils.dictionary(definition.get("needs", {}))
	for need_name: String in npc.needs:
		npc.needs[need_name] = DataUtils.unit(initial_needs.get(need_name, 0.5))
	var schedule_data: Variant = definition.get("schedule", [])
	if schedule_data is Array:
		npc.schedule = schedule_data.duplicate(true)
	var offset: Variant = definition.get("slot_offset", [0, 0, 0])
	if offset is Array and offset.size() == 3:
		npc.slot_offset = Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
	var tint: Variant = definition.get("color", [0.6, 0.6, 0.6])
	if tint is Array and tint.size() == 3:
		npc.color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	return npc


func restore(data: Dictionary) -> void:
	display_name = str(data.get("display_name", display_name))
	role = LocationRegistry.rethemed_role(id, str(data.get("role", role)), role)
	home_location_id = LocationRegistry.canonical(str(data.get("home_location_id", home_location_id)))
	var saved_personality := DataUtils.dictionary(data.get("personality", {}))
	for trait_name in PERSONALITY_NAMES:
		personality[trait_name] = DataUtils.unit(saved_personality.get(trait_name, personality.get(trait_name, 0.5)))
	relationship = NPCRelationship.from_dict(DataUtils.dictionary(data.get("relationship_to_player", relationship.to_dict())))
	var state := DataUtils.dictionary(data.get("current_state", {}))
	for state_key in ["location_id", "activity", "mood"]:
		current_state[state_key] = str(state.get(state_key, current_state[state_key]))
	current_state["location_id"] = LocationRegistry.canonical(str(current_state["location_id"]))
	var saved_needs := DataUtils.dictionary(data.get("needs", {}))
	for need_name: String in needs:
		needs[need_name] = DataUtils.unit(saved_needs.get(need_name, needs[need_name]))
	collision_state = str(data.get("collision_state", "NONE"))
	collision_strength = DataUtils.unit(data.get("collision_strength", 0.0), 0.0)
	var rows: Variant = data.get("memories", [])
	memories.clear()
	if rows is Array:
		for row: Variant in rows:
			if row is Dictionary:
				memories.append(NPCMemory.from_dict(row, id))


func to_dict() -> Dictionary:
	var rows: Array[Dictionary] = []
	for memory in memories:
		rows.append(memory.to_dict())
	return {
		"id": id, "display_name": display_name, "role": role,
		"personality": personality.duplicate(true),
		"relationship_to_player": relationship.to_dict(),
		"current_state": current_state.duplicate(true), "home_location_id": home_location_id,
		"memories": rows, "needs": needs.duplicate(true),
		"collision_state": collision_state, "collision_strength": collision_strength,
	}
