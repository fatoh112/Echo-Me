extends Node3D

const INTERACTION_RANGE := 3.0
const MAX_MEMORIES := 12
const DEBUG_MEMORY_COUNT := 5

@onready var player: PlayerController = $Player
@onready var alex: AlexController = $Alex
@onready var save_manager: SaveManager = $SaveManager

var player_profile := PlayerBehaviorProfile.new()
var echo_profile := EchoBehaviorProfile.new()
var alex_relationship := NPCRelationship.new()
var alex_memories: Array[NPCMemory] = []
var offline_simulator := OfflineEchoSimulator.new()

var debug_label: Label
var prompt_label: Label
var interaction_panel: PanelContainer
var away_message: Label
var away_timer: Timer
var _logout_timestamp := 0.0
var _saved_on_shutdown := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_create_greybox_world()
	_build_interface()
	_load_game_state()
	_apply_offline_simulation()
	_refresh_debug_panel()


func _process(_delta: float) -> void:
	var in_range := player.global_position.distance_to(alex.global_position) <= INTERACTION_RANGE
	prompt_label.visible = in_range and not interaction_panel.visible
	if interaction_panel.visible and not in_range:
		_close_interaction_menu()
	if in_range and not interaction_panel.visible and Input.is_action_just_pressed("interact"):
		_open_interaction_menu()


func _input(event: InputEvent) -> void:
	if interaction_panel != null and interaction_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_interaction_menu()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()


func _exit_tree() -> void:
	_save_game()


func _create_greybox_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.12, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.68, 0.70, 0.74)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key_light.light_color = Color(1.0, 0.92, 0.80)
	key_light.light_energy = 0.85
	key_light.shadow_enabled = false
	add_child(key_light)

	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.position.y = -0.1
	add_child(ground_body)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(80.0, 0.2, 80.0)
	ground_collision.shape = ground_shape
	ground_body.add_child(ground_collision)

	var ground_mesh := MeshInstance3D.new()
	ground_mesh.name = "GroundVisual"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground_mesh.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.34, 0.36, 0.38)
	ground_material.roughness = 1.0
	ground_mesh.material_override = ground_material
	ground_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground_mesh)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var debug_panel := PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.position = Vector2(14.0, 14.0)
	debug_panel.custom_minimum_size = Vector2(350.0, 0.0)
	canvas.add_child(debug_panel)
	debug_label = Label.new()
	debug_label.custom_minimum_size = Vector2(330.0, 0.0)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_panel.add_child(debug_label)

	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -280.0
	prompt_label.offset_top = -64.0
	prompt_label.offset_right = 280.0
	prompt_label.offset_bottom = -28.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.text = "Press E to interact with Alex"
	canvas.add_child(prompt_label)

	var menu_holder := CenterContainer.new()
	menu_holder.name = "InteractionMenuHolder"
	menu_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(menu_holder)
	interaction_panel = PanelContainer.new()
	interaction_panel.name = "InteractionMenu"
	interaction_panel.custom_minimum_size = Vector2(300.0, 0.0)
	interaction_panel.visible = false
	menu_holder.add_child(interaction_panel)
	var menu_content := VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 10)
	interaction_panel.add_child(menu_content)
	var menu_title := Label.new()
	menu_title.text = "Interact with Alex"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 20)
	menu_content.add_child(menu_title)
	for action_type: String in ["help", "give", "insult", "steal"]:
		var action_button := Button.new()
		action_button.text = action_type.capitalize()
		action_button.custom_minimum_size = Vector2(260.0, 40.0)
		action_button.pressed.connect(_on_action_selected.bind(action_type))
		menu_content.add_child(action_button)

	away_message = Label.new()
	away_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	away_message.offset_left = -320.0
	away_message.offset_top = 20.0
	away_message.offset_right = 320.0
	away_message.offset_bottom = 66.0
	away_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	away_message.add_theme_font_size_override("font_size", 18)
	away_message.visible = false
	canvas.add_child(away_message)

	away_timer = Timer.new()
	away_timer.one_shot = true
	away_timer.wait_time = 7.0
	away_timer.timeout.connect(_on_away_timer_timeout)
	add_child(away_timer)


func _load_game_state() -> void:
	var saved_state := save_manager.load_game()
	_logout_timestamp = float(saved_state.get("logout_timestamp", 0.0))
	if saved_state.is_empty():
		echo_profile = EchoBehaviorProfile.from_player(player_profile)
		return

	var saved_traits: Variant = saved_state.get("player_traits", {})
	if saved_traits is Dictionary:
		player_profile = PlayerBehaviorProfile.from_dict(saved_traits)
	var saved_relationship: Variant = saved_state.get("alex_relationship", {})
	if saved_relationship is Dictionary:
		alex_relationship = NPCRelationship.from_dict(saved_relationship)
	var saved_memories: Variant = saved_state.get("alex_memories", [])
	if saved_memories is Array:
		for memory_data: Variant in saved_memories:
			if memory_data is Dictionary:
				alex_memories.append(NPCMemory.from_dict(memory_data))
	_trim_memories()
	echo_profile = EchoBehaviorProfile.from_player(player_profile)


func _apply_offline_simulation() -> void:
	if _logout_timestamp <= 0.0:
		return
	var elapsed_seconds := Time.get_unix_time_from_system() - _logout_timestamp
	if elapsed_seconds < 60.0:
		return

	var actions := offline_simulator.simulate_elapsed(elapsed_seconds, player_profile, alex_relationship)
	if actions.is_empty():
		return
	for action: WorldAction in actions:
		alex_memories.append(NPCMemory.from_action(action))
	_trim_memories()
	echo_profile = EchoBehaviorProfile.from_player(player_profile)
	var latest_action: WorldAction = actions.back()
	away_message.text = "While You Were Gone: Alex remembers that the player %s." % latest_action.get_memory_phrase()
	away_message.visible = true
	away_timer.start()


func _on_action_selected(action_type: String) -> void:
	var action := WorldAction.create(action_type)
	if action == null:
		return
	player_profile.apply_action(action)
	alex_relationship.apply_action(action)
	alex_memories.append(NPCMemory.from_action(action))
	_trim_memories()
	echo_profile = EchoBehaviorProfile.from_player(player_profile)
	_refresh_debug_panel()
	_close_interaction_menu()


func _open_interaction_menu() -> void:
	interaction_panel.visible = true
	prompt_label.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_interaction_menu() -> void:
	if interaction_panel != null:
		interaction_panel.visible = false
	if is_instance_valid(player):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_debug_panel() -> void:
	if debug_label == null:
		return
	var lines: Array[String] = ["ECHO ME — DAY 1 DEBUG", "", "PLAYER TRAITS"]
	for trait_name: String in PlayerBehaviorProfile.TRAIT_NAMES:
		lines.append("  %s: %.2f" % [trait_name, float(player_profile.traits[trait_name])])
	lines.append("\nECHO TRAITS (INVERSE)")
	for trait_name: String in PlayerBehaviorProfile.TRAIT_NAMES:
		lines.append("  %s: %.2f" % [trait_name, float(echo_profile.traits[trait_name])])
	lines.append("\nALEX RELATIONSHIP")
	for value_name: String in NPCRelationship.VALUE_NAMES:
		lines.append("  %s: %.2f" % [value_name, float(alex_relationship.values[value_name])])
	lines.append("\nALEX LATEST MEMORIES")
	if alex_memories.is_empty():
		lines.append("  (none yet)")
	else:
		var first_memory := maxi(0, alex_memories.size() - DEBUG_MEMORY_COUNT)
		for memory_index: int in range(alex_memories.size() - 1, first_memory - 1, -1):
			var memory: NPCMemory = alex_memories[memory_index]
			var source_note := " [debug source: ECHO]" if memory.actual_source == "ECHO" else ""
			lines.append("  %s%s" % [memory.description, source_note])
	debug_label.text = "\n".join(lines)


func _trim_memories() -> void:
	while alex_memories.size() > MAX_MEMORIES:
		alex_memories.pop_front()


func _on_away_timer_timeout() -> void:
	away_message.visible = false


func _save_game() -> void:
	if _saved_on_shutdown or not is_instance_valid(save_manager):
		return
	if player_profile == null or alex_relationship == null:
		return
	_saved_on_shutdown = true
	save_manager.save_game(player_profile, alex_relationship, alex_memories)
