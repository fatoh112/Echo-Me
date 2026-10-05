extends Node3D
class_name NPCManager

const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const ACTIVE_DISTANCE := 12.0
const BACKGROUND_DISTANCE := 28.0
const INTERACTION_DISTANCE := 3.2
var world: WorldState
var player_body: CharacterBody3D
var entities: Dictionary = {}
var _tick := 0
var path_router := NPCPathRouter.new()


func setup(world_state: WorldState, player_position: Vector3, player_controller: CharacterBody3D = null) -> void:
	world = world_state
	player_body = player_controller
	if not path_router.load_walkways():
		push_error("NPC walkway routing settings are missing or invalid: " + NPCPathRouter.DATA_PATH)
	for npc: NPCData in world.npcs.values():
		var entity: NPCController = NPC_SCENE.instantiate()
		entity.name = npc.display_name
		add_child(entity)
		entity.configure(npc)
		entity.set_walkway_router(path_router, world.echo_seed, player_body)
		entities[npc.id] = entity
	update_entities(player_position)


func update_entities(player_position: Vector3) -> void:
	_tick += 1
	for npc_id: String in entities:
		var npc: NPCData = world.npcs[npc_id]
		var entity: NPCController = entities[npc_id]
		var position := world.npc_position(npc)
		var activity_position := entity.global_position if entity._has_representation and entity.level != "LOGICAL" else position
		var distance := player_position.distance_to(activity_position)
		var level := activity_level_for(distance)
		if level == "ACTIVE" or level != entity.level or _tick % 5 == 0:
			entity.update_representation(position, level)
		npc.activity_level = level


static func activity_level_for(distance: float) -> String:
	if distance <= ACTIVE_DISTANCE:
		return "ACTIVE"
	if distance <= BACKGROUND_DISTANCE:
		return "BACKGROUND"
	return "LOGICAL"


func nearest_npc(player_position: Vector3) -> NPCData:
	var nearest: NPCData = null
	var best_distance := INTERACTION_DISTANCE
	for npc_id: String in entities:
		var entity: NPCController = entities[npc_id]
		if entity.level != "ACTIVE":
			continue
		var distance := player_position.distance_to(entity.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = world.npcs[npc_id]
	return nearest
