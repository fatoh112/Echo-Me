extends Node3D

@onready var player: PlayerController = $Player
@onready var neighborhood: Neighborhood = $Neighborhood
@onready var npc_manager: NPCManager = $NPCManager
@onready var save_manager: SaveManager = $SaveManager
@onready var interaction_ui: InteractionUI = $InteractionUI
@onready var debug_ui: DebugUI = $DebugUI

var world: WorldState
var simulator := OfflineEchoSimulator.new()
var nearby: NPCData
var _proximity_elapsed := 0.0
var _logical_elapsed := 0.0
var _saved_on_shutdown := false
var _validation_mode := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_validation_mode = "--echo-validation" in OS.get_cmdline_user_args()
	world = WorldState.new(94721) if _validation_mode else save_manager.load_world(SaveManager.SAVE_PATH, randi_range(1, 2147483647))
	neighborhood.build(world.locations)
	player.global_position = Vector3(clampf(world.player_position.x, -28, 28), 0, clampf(world.player_position.z, -28, 28))
	npc_manager.setup(world, player.global_position)
	interaction_ui.action_requested.connect(_on_action_requested)
	interaction_ui.modal_changed.connect(_on_modal_changed)
	debug_ui.setup(world)
	var events: Array[WorldAction] = []
	if not _validation_mode and save_manager.logout_timestamp > 0.0:
		var elapsed := maxf(0.0, Time.get_unix_time_from_system() - save_manager.logout_timestamp)
		events = simulator.simulate_elapsed(elapsed, world, save_manager.logout_timestamp)
	if not events.is_empty():
		npc_manager.update_entities(player.global_position)
		interaction_ui.show_offline_summary(world, events)
		# Commit the consumed offline result immediately so a crash cannot replay it.
		save_manager.save_world(world)
	if not save_manager.last_load_notice.is_empty():
		interaction_ui.show_toast(save_manager.last_load_notice)
	interaction_ui.update_clock(world)
	debug_ui.refresh()
	_update_proximity()


func _process(delta: float) -> void:
	if world == null:
		return
	_proximity_elapsed += delta
	_logical_elapsed += delta
	if player.global_position.y < -10.0:
		player.global_position = Vector3(0, 0, 8)
		player.velocity = Vector3.ZERO
	if _proximity_elapsed >= 0.15:
		_proximity_elapsed = 0.0
		_update_proximity()
	if _logical_elapsed >= 1.0:
		world.game_minutes += _logical_elapsed * 2.0
		_logical_elapsed = 0.0
		world.update_schedules()
		world.player_position = player.global_position
		world.last_player_location = world.closest_location(player.global_position)
		npc_manager.update_entities(player.global_position)
		interaction_ui.update_clock(world)
		debug_ui.refresh()


func _input(event: InputEvent) -> void:
	if interaction_ui == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and interaction_ui.is_modal():
			interaction_ui.close_all()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F10:
			_save_game()
			get_tree().quit()
			get_viewport().set_input_as_handled()
		elif world != null and nearby != null and not interaction_ui.is_modal() and event.is_action_pressed("interact"):
			interaction_ui.open_for_npc(nearby)
			get_viewport().set_input_as_handled()


func _update_proximity() -> void:
	nearby = npc_manager.nearest_npc(player.global_position)
	interaction_ui.set_nearby(nearby)
	if nearby != null:
		debug_ui.refresh(nearby.id)
	if not interaction_ui.menu_target_id.is_empty():
		var entity: NPCController = npc_manager.entities.get(interaction_ui.menu_target_id)
		if entity == null or entity.level != "ACTIVE" or entity.global_position.distance_to(player.global_position) > 4.0:
			interaction_ui.close_menu()


func _on_action_requested(action_type: String, target_id: String, response_to: String) -> void:
	if not world.npcs.has(target_id):
		return
	var npc: NPCData = world.npcs[target_id]
	var action := WorldAction.create(action_type, target_id, str(npc.current_state["location_id"]))
	if not response_to.is_empty():
		action.metadata["response_to_memory_id"] = response_to
		for memory in npc.memories:
			if memory.id == response_to:
				action.metadata["denial_truthful"] = memory.actual_source == "ECHO"
	if ActionSystem.apply(world, action):
		interaction_ui.show_toast("%s: %s" % [npc.display_name, DialogueResolver.reaction(npc, action)])
		debug_ui.refresh(npc.id)


func _on_modal_changed(open: bool) -> void:
	player.controls_enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()


func _exit_tree() -> void:
	_save_game()


func _save_game() -> void:
	if _saved_on_shutdown or _validation_mode or world == null or not is_instance_valid(save_manager):
		return
	world.player_position = player.global_position
	_saved_on_shutdown = save_manager.save_world(world)
