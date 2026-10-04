extends RefCounted
class_name WorldState

var player_profile := PlayerBehaviorProfile.new()
var echo_profile: EchoBehaviorProfile
var echo_seed := 94721
var npcs: Dictionary = {}
var locations: Dictionary = {}
var reputation := ReputationSystem.new()
var game_minutes := 600.0
var player_position := Vector3(0, 0, 8)
var last_player_location := "player_area"
var echo_location_id := "street"
var echo_turn_index := 0
var event_history: Array[WorldAction] = []
var last_offline_events: Array[WorldAction] = []
var last_decisions: Array[Dictionary] = []


func _init(save_seed: int = 94721) -> void:
	echo_seed = save_seed
	locations = DataUtils.dictionary(DataUtils.read_json("res://data/neighborhood.json"))
	var definitions: Variant = DataUtils.read_json("res://data/npcs/neighbors.json")
	if definitions is Array:
		for definition: Dictionary in definitions:
			var npc := NPCData.from_definition(definition)
			npcs[npc.id] = npc
	refresh_echo()
	update_schedules()


func refresh_echo() -> void:
	echo_profile = EchoBehaviorProfile.from_player(player_profile, echo_seed)


func update_schedules() -> void:
	var minute := fmod(game_minutes, 1440.0)
	for npc: NPCData in npcs.values():
		var selected: Dictionary = {}
		for entry: Dictionary in npc.schedule:
			if minute >= DataUtils.number(entry.get("start_minute", 0), 0.0):
				selected = entry
		if not selected.is_empty():
			npc.current_state["location_id"] = str(selected.get("location_id", npc.home_location_id))
			npc.current_state["activity"] = str(selected.get("activity", "relaxing"))


func location_position(location_id: String) -> Vector3:
	var location := DataUtils.dictionary(locations.get(location_id, {}))
	var position_data: Variant = location.get("position", [0, 0, 0])
	if position_data is Array and position_data.size() == 3:
		return Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	return Vector3.ZERO


func npc_position(npc: NPCData) -> Vector3:
	return location_position(str(npc.current_state["location_id"])) + npc.slot_offset


func closest_location(position: Vector3) -> String:
	var nearest := "street"
	var distance := INF
	for location_id: String in locations:
		var candidate := position.distance_squared_to(location_position(location_id))
		if candidate < distance:
			distance = candidate
			nearest = location_id
	return nearest


func to_dict() -> Dictionary:
	var npc_rows: Dictionary = {}
	for npc_id: String in npcs:
		npc_rows[npc_id] = (npcs[npc_id] as NPCData).to_dict()
	var history: Array[Dictionary] = []
	for action in event_history:
		history.append(action.to_dict())
	var offline: Array[Dictionary] = []
	for action in last_offline_events:
		offline.append(action.to_dict())
	return {
		"save_version": 2, "echo_seed": echo_seed,
		"player_traits": player_profile.to_dict(), "echo_profile": echo_profile.to_dict(),
		"npcs": npc_rows, "reputation": reputation.to_dict(),
		"world_state": {
			"game_minutes": game_minutes,
			"player_position": [player_position.x, player_position.y, player_position.z],
			"last_player_location": last_player_location, "echo_location_id": echo_location_id,
			"echo_turn_index": echo_turn_index,
		},
		"event_history": history, "last_offline_events": offline,
		"last_decisions": last_decisions.duplicate(true),
	}


static func from_dict(data: Dictionary) -> WorldState:
	var world := WorldState.new(int(DataUtils.number(data.get("echo_seed", 94721), 94721.0)))
	world.player_profile = PlayerBehaviorProfile.from_dict(DataUtils.dictionary(data.get("player_traits", {})))
	world.reputation = ReputationSystem.from_dict(DataUtils.dictionary(data.get("reputation", {})))
	var npc_rows := DataUtils.dictionary(data.get("npcs", {}))
	for npc_id: String in npc_rows:
		if world.npcs.has(npc_id):
			(world.npcs[npc_id] as NPCData).restore(DataUtils.dictionary(npc_rows[npc_id]))
	var state := DataUtils.dictionary(data.get("world_state", {}))
	world.game_minutes = maxf(0.0, DataUtils.number(state.get("game_minutes", 600.0), 600.0))
	world.last_player_location = str(state.get("last_player_location", "player_area"))
	world.echo_location_id = str(state.get("echo_location_id", "street"))
	world.echo_turn_index = maxi(0, int(DataUtils.number(state.get("echo_turn_index", 0), 0.0)))
	var position_data: Variant = state.get("player_position", [0, 0, 8])
	if position_data is Array and position_data.size() == 3:
		world.player_position = Vector3(DataUtils.number(position_data[0], 0.0), DataUtils.number(position_data[1], 0.0), DataUtils.number(position_data[2], 8.0))
	var rows: Variant = data.get("event_history", [])
	if rows is Array:
		for row: Variant in rows:
			if row is Dictionary:
				world.event_history.append(WorldAction.from_dict(row))
	rows = data.get("last_offline_events", [])
	if rows is Array:
		for row: Variant in rows:
			if row is Dictionary:
				world.last_offline_events.append(WorldAction.from_dict(row))
	rows = data.get("last_decisions", [])
	if rows is Array:
		for row: Variant in rows:
			if row is Dictionary:
				world.last_decisions.append(row.duplicate(true))
	world.refresh_echo()
	return world
