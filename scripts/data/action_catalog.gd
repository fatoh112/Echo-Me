extends RefCounted
class_name ActionCatalog

const PRIMARY_ACTIONS: Array[String] = [
	"HELP", "GIVE", "INSULT", "STEAL", "THREATEN", "LIE",
	"DEFEND", "BEFRIEND", "BETRAY", "IGNORE",
]
const RESPONSES: Array[String] = ["DENY", "APOLOGIZE", "THREATEN", "DISMISS"]
static var _definitions: Dictionary = {}


static func definition(action_type: String) -> Dictionary:
	if _definitions.is_empty():
		_definitions = DataUtils.dictionary(DataUtils.read_json("res://data/actions/actions.json"))
	return DataUtils.dictionary(_definitions.get(action_type.to_upper(), {}))


static func label(action_type: String) -> String:
	return str(definition(action_type).get("label", action_type.capitalize()))
