extends RefCounted
class_name DialogueResolver

static var _templates: Dictionary = {}


static func templates() -> Dictionary:
	if _templates.is_empty():
		_templates = DataUtils.dictionary(DataUtils.read_json("res://data/dialogue/reactions.json"))
	return _templates


static func reaction(npc: NPCData, action: WorldAction) -> String:
	var data := templates()
	for rule: Dictionary in data.get("rules", []):
		if rule.has("collision") and str(rule["collision"]) != npc.collision_state:
			continue
		if rule.has("mood") and str(rule["mood"]) != str(npc.current_state["mood"]):
			continue
		if rule.has("action") and str(rule["action"]) != action.action_type:
			continue
		if rule.has("max_trust") and float(npc.relationship.values["trust"]) > float(rule["max_trust"]):
			continue
		if rule.has("min_forgiveness") and float(npc.personality["forgiveness"]) < float(rule["min_forgiveness"]):
			continue
		return str(rule["text"])
	return str(DataUtils.dictionary(data.get("actions", {})).get(action.action_type, "I will remember that."))


static func greeting(npc: NPCData) -> String:
	return str(DataUtils.dictionary(templates().get("greetings", {})).get(str(npc.current_state["mood"]), "Hello."))


static func accusation(npc: NPCData, memory: NPCMemory) -> String:
	if npc.collision_state == "STRONG":
		return "I don't understand you anymore. " + str(DataUtils.dictionary(templates().get("accusations", {})).get(memory.action_type, "Why did you do that to me?"))
	return str(DataUtils.dictionary(templates().get("accusations", {})).get(memory.action_type, "I remember what you did. Explain yourself."))
