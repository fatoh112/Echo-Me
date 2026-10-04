extends Node
class_name SaveManager

const SAVE_PATH := "user://echo_me_save.json"
var logout_timestamp := 0.0
var last_load_notice := ""
var write_blocked := false


func load_world(path: String = SAVE_PATH, fallback_seed: int = 94721) -> WorldState:
	logout_timestamp = 0.0
	last_load_notice = ""
	write_blocked = false
	if not FileAccess.file_exists(path):
		return WorldState.new(fallback_seed)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_load_notice = "Save could not be opened; original preserved."
		write_blocked = true
		return WorldState.new(fallback_seed)
	var original := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_error := parser.parse(original)
	if parse_error != OK or not parser.data is Dictionary:
		if not _backup_text(path + ".corrupt.backup.json", original):
			write_blocked = true
		last_load_notice = "Invalid save preserved as a backup; using defaults."
		return WorldState.new(fallback_seed)
	var data: Dictionary = parser.data
	var version := int(DataUtils.number(data.get("save_version", 1), 1.0))
	if version > 2:
		last_load_notice = "This save uses a newer version; saving is disabled to protect it."
		write_blocked = true
		return WorldState.new(fallback_seed)
	logout_timestamp = DataUtils.number(data.get("logout_timestamp", 0.0), 0.0)
	if version < 2:
		if not _backup_text(path + ".v1.backup.json", original):
			write_blocked = true
		data = _migrate_day_one(data)
		last_load_notice = "Day 1 save migrated; Alex's history and traits preserved."
	return WorldState.from_dict(data)


func save_world(world: WorldState, at_time: float = -1.0, path: String = SAVE_PATH) -> bool:
	if write_blocked:
		push_warning("Saving blocked to preserve the original unreadable/unsupported save.")
		return false
	var payload := world.to_dict()
	payload["logout_timestamp"] = Time.get_unix_time_from_system() if at_time < 0.0 else at_time
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t", true, true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Save write failed: %s" % write_error)
		return false
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".previous.json"))
		if backup_error != OK:
			push_error("Cannot preserve previous save: %s" % backup_error)
			return false
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		push_error("Atomic save replacement failed: %s" % rename_error)
		return false
	return true


func _backup_text(path: String, original: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	var backup := FileAccess.open(path, FileAccess.WRITE)
	if backup == null:
		return false
	backup.store_string(original)
	backup.flush()
	var result := backup.get_error() == OK
	backup.close()
	return result


func _migrate_day_one(old: Dictionary) -> Dictionary:
	var seed_value := int(DataUtils.number(old.get("logout_timestamp", 94721.0), 94721.0)) % 2147483647
	var world := WorldState.new(seed_value)
	world.player_profile = PlayerBehaviorProfile.from_dict(DataUtils.dictionary(old.get("player_traits", {})))
	var alex: NPCData = world.npcs["alex"]
	alex.relationship = NPCRelationship.from_dict(DataUtils.dictionary(old.get("alex_relationship", {})))
	var memories: Variant = old.get("alex_memories", [])
	if memories is Array:
		for row: Variant in memories:
			if row is Dictionary:
				alex.memories.append(NPCMemory.from_dict(row, "alex"))
	MemorySystem.evaluate(alex, logout_timestamp)
	world.refresh_echo()
	var migrated := world.to_dict()
	migrated["logout_timestamp"] = logout_timestamp
	return migrated
