extends Node
class_name SaveManager

const SAVE_PATH := "user://echo_me_save.json"


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open local save file for reading.")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Local save file is invalid; starting with default prototype data.")
		return {}
	return parsed


func save_game(
	player_profile: PlayerBehaviorProfile,
	relationship: NPCRelationship,
	memories: Array[NPCMemory]
) -> bool:
	var memory_rows: Array[Dictionary] = []
	for memory: NPCMemory in memories:
		memory_rows.append(memory.to_dict())
	var payload: Dictionary = {
		"save_version": 1,
		"logout_timestamp": Time.get_unix_time_from_system(),
		"player_traits": player_profile.to_dict(),
		"alex_relationship": relationship.to_dict(),
		"alex_memories": memory_rows,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open local save file for writing: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true
