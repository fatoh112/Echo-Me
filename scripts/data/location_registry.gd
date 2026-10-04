extends RefCounted
class_name LocationRegistry

# Day 1/2 save identities stay readable; all new events use official town IDs.
const LEGACY: Dictionary = {
	"player_area": "PLAYER_QUARTERS", "street": "TOWN_SQUARE",
	"shop": "MERCHANT_SHOP", "cafe": "TAVERN", "park": "TOWN_SQUARE",
	"residential": "RESIDENTIAL_ROW", "alley": "BACK_ALLEY",
}
const IDS: Array[String] = [
	"PLAYER_QUARTERS", "TOWN_SQUARE", "MERCHANT_SHOP", "TAVERN",
	"RESIDENTIAL_ROW", "BACK_ALLEY", "WATCH_POST",
]

static func canonical(value: String, fallback: String = "TOWN_SQUARE") -> String:
	if value in IDS:
		return value
	return str(LEGACY.get(value, fallback))

static func rethemed_role(npc_id: String, saved_role: String, current_role: String) -> String:
	if npc_id.is_empty():
		return current_role
	var old_roles: Array[String] = [
		"Shopkeeper", "Close friend", "Neighbor", "Cafe worker",
		"Café worker", "Troublemaker", "Neighborhood watch",
	]
	if saved_role in old_roles or saved_role.is_empty():
		return current_role
	return saved_role
