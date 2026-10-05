extends SceneTree
## Captures the 18 required Day 5 views into user://echo_me_previews.

var game: Node3D
var capture_camera: Camera3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.set_process(false)
	game.npc_manager.set_process(false)
	game.player.controls_enabled = false
	var camera := game.player.get_node("CameraPivot/Camera3D") as Camera3D
	camera.current = true
	await _capture("01_player_spawn")
	game.interaction_ui.hide()
	game.debug_ui.hide()
	await _view("02_village_overview", Vector3(30.0, 36.0, -32.0), Vector3(31.0, 3.0, -74.0), 72.0)
	await _view("03_town_square", Vector3(23.0, 5.0, -59.0), Vector3(17.0, 1.4, -66.0), 62.0)
	await _view("04_merchant_exterior", Vector3(31.5, 6.3, -73.5), Vector3(37, 5.4, -79.5), 58.0)
	await _view("05_merchant_interior", Vector3(37.5, 6.5, -76.5), Vector3(36.2, 6.0, -80.1), 65.0)
	await _view("06_tavern_exterior", Vector3(41.5, 7.2, -47.0), Vector3(41.5, 5.5, -57), 58.0)
	await _view("07_tavern_interior", Vector3(42.5, 6.5, -53.7), Vector3(41.4, 5.7, -57), 65.0)
	await _view("08_residential_exterior", Vector3(14.5, 3.5, -87.5), Vector3(24, 2.0, -92), 60.0)
	await _view("09_residential_interior", Vector3(24.5, 3.0, -88.8), Vector3(23.3, 2.3, -92.2), 65.0)
	var david_for_alley := game.npc_manager.entities["david"] as NPCController
	david_for_alley.update_representation(david_for_alley.global_position, "ACTIVE")
	await _view("10_back_alley", Vector3(35.5, 3.0, -68.5), Vector3(28.0, 1.3, -69.0), 62.0)
	var noah_for_watch := game.npc_manager.entities["noah"] as NPCController
	noah_for_watch.global_position = Vector3(27.3, 3.45, -69.2)
	noah_for_watch.update_representation(noah_for_watch.global_position, "ACTIVE")
	await _view("11_watch_area", Vector3(22.0, 5.0, -72.0), Vector3(27.3, 4.1, -69.2), 62.0)
	await _capture_npc_lineup()
	var alex := game.npc_manager.entities["alex"] as NPCController
	alex.global_position = Vector3(36.2, 4.92, -72.4)
	alex.update_representation(alex.global_position, "ACTIVE")
	game.player.global_position = alex.global_position + Vector3(-1.3, 0, 0.3)
	game.player.velocity = Vector3.ZERO
	game.player.body_visual.look_at(alex.global_position, Vector3.UP)
	alex.look_at(game.player.global_position, Vector3.UP)
	await _view("13_player_next_to_alex", Vector3(31.5, 7.8, -77.0), Vector3(36.0, 5.9, -72.4), 66.0)
	game.player.global_position = Vector3(12.7, 1.4, -82.5)
	game.player.velocity = Vector3.ZERO
	await _view("14_player_indoors", Vector3(12.8, 3.4, -77.9), Vector3(12.5, 2.2, -81), 66.0)
	await _night_interior()
	await _view("16_mountains_background", Vector3(30, 36, -32), Vector3(31, 3, -74), 72.0)
	await _view("17_ground_closeup", Vector3(34.0, 2.4, -59.5), Vector3(34.2, 1.3, -61.0), 48.0)
	await _view("18_roof_closeup", Vector3(39.0, 11.0, -86.5), Vector3(37, 7.2, -79.5), 50.0)
	print("DAY 5 CAPTURES COMPLETE: 18 images in ", ProjectSettings.globalize_path("user://echo_me_previews"))
	quit()

func _view(image_name: String, eye: Vector3, target: Vector3, fov: float) -> void:
	if capture_camera == null:
		capture_camera = Camera3D.new()
		game.add_child(capture_camera)
	capture_camera.current = true
	capture_camera.fov = fov
	capture_camera.global_position = eye
	capture_camera.look_at(target, Vector3.UP)
	await _capture(image_name)

func _capture_npc_lineup() -> void:
	var index := 0
	var states := ["IDLE", "SIT", "WALK", "RUN", "JOG", "JUMP"]
	for npc_id: String in ["alex", "sarah", "mike", "emma", "david", "noah"]:
		var npc := game.npc_manager.entities[npc_id] as NPCController
		var position := Vector3(12.8 + index * 1.65, 1.25, -70.0)
		npc.update_representation(position, "ACTIVE")
		npc.global_position = position
		npc.rotation.y = 0.0
		npc.play_locomotion(states[index])
		index += 1
	await _view("12_six_real_npcs", Vector3(17.7, 5.0, -59.0), Vector3(17.7, 2.0, -70.0), 55.0)

func _night_interior() -> void:
	var environment: Environment = game.neighborhood.world_environment.environment
	var old_ambient_energy: float = environment.ambient_light_energy
	var old_background_energy: float = environment.background_energy_multiplier
	var old_sun_energy: float = game.neighborhood.sun.light_energy
	environment.ambient_light_energy = 0.14
	environment.background_energy_multiplier = 0.3
	game.neighborhood.sun.light_energy = 0.12
	await _view("15_night_like_fireplace", Vector3(14, 3.6, -83.9), Vector3(13.0, 2.4, -82.7), 62.0)
	environment.ambient_light_energy = old_ambient_energy
	environment.background_energy_multiplier = old_background_energy
	game.neighborhood.sun.light_energy = old_sun_energy

func _capture(image_name: String) -> void:
	for _frame in range(14):
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("user://echo_me_previews")
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_texture().get_image()
	var save_error := image.save_png(directory.path_join(image_name + ".png"))
	if save_error != OK:
		printerr("DAY 5 CAPTURE FAILED: ", image_name, " error ", save_error)
	else:
		print("DAY 5 CAPTURE: ", image_name, " | draws ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " | objects ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
