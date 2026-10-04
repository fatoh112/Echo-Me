extends SceneTree

var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _capture("player_street")
	await _view("main_street", Vector3(4, 0, 7), 0.15)
	await _view("town_square", Vector3(4.5, 0, 5.5), 0.38)
	var ground_camera := Camera3D.new()
	ground_camera.fov = 55
	game.add_child(ground_camera)
	ground_camera.position = Vector3(1.8, 2.1, 8.0)
	ground_camera.look_at(Vector3(0.4, 0.02, 5.2))
	ground_camera.current = true
	await _capture("ground_detail")
	ground_camera.free()
	(game.player.get_node("CameraPivot/Camera3D") as Camera3D).current = true
	await _view("merchant", Vector3(-11, 0, -3.5), 0)
	await _view("tavern", Vector3(11, 0, -3.5), 0)
	await _view("residential_row", Vector3(12, 0, 12), PI)
	await _view("back_alley", Vector3(0, 0, -16), 0)
	await _view("watch_post", Vector3(-7.3, 0, 8), PI / 2)
	# A second angle includes the tall roof and stairs in one landmark view.
	var watch_camera := Camera3D.new()
	watch_camera.fov = 70
	game.add_child(watch_camera)
	watch_camera.position = Vector3(-2, 4.6, 13)
	watch_camera.look_at(Vector3(-16.2, 5.0, 8))
	watch_camera.current = true
	await _capture("watch_post")
	watch_camera.free()
	(game.player.get_node("CameraPivot/Camera3D") as Camera3D).current = true
	var roof_camera := Camera3D.new()
	roof_camera.fov = 60
	game.add_child(roof_camera)
	roof_camera.position = Vector3(-16.1, 19.0, 8.0)
	roof_camera.look_at(Vector3(-16.1, 2.6, 8.0), Vector3.FORWARD)
	roof_camera.current = true
	await _capture("watch_roof_topdown")
	roof_camera.free()
	(game.player.get_node("CameraPivot/Camera3D") as Camera3D).current = true
	await _view("home_exterior", Vector3(0, 0, 13), PI)
	var sarah: NPCData = game.world.npcs["sarah"]
	await _view("player_near_npc", game.world.npc_position(sarah) + Vector3(-0.9, 0, 2.6), -0.3)
	game.interaction_ui.open_for_npc(sarah)
	await _capture("interaction")
	game.interaction_ui.close_all()
	var camera := Camera3D.new()
	camera.position = Vector3(32, 32, 34)
	game.add_child(camera)
	camera.look_at(Vector3(0, 1, -1))
	camera.current = true
	await _capture("neighborhood")
	game.player.global_position = Vector3(0, 0, 11)
	game.npc_manager.update_entities(game.player.global_position)
	game.world.last_player_location = "PLAYER_QUARTERS"
	game.interaction_ui.update_clock(game.world)
	camera.position = game.player.global_position + Vector3(1.2, 1.7, -3.5)
	camera.look_at(game.player.global_position + Vector3(0, 1.0, 0))
	await _capture("player_front")
	camera.current = false
	(game.player.get_node("CameraPivot/Camera3D") as Camera3D).current = true
	var now := Time.get_unix_time_from_system()
	for index in range(8):
		ActionSystem.apply(game.world, WorldAction.create("HELP", "sarah", "RESIDENTIAL_ROW", "PLAYER", now - 10 + index))
	var action := WorldAction.create("BETRAY", "sarah", "RESIDENTIAL_ROW", "ECHO", now)
	ActionSystem.apply(game.world, action)
	game.world.last_offline_events.append(action)
	game.debug_ui.panel.visible = true
	game.debug_ui.refresh("sarah")
	await _capture("debug_collision")
	game.debug_ui.panel.visible = false
	var events: Array[WorldAction] = [action]
	game.interaction_ui.show_offline_summary(game.world, events)
	await _capture("offline_summary")
	game.queue_free()
	await process_frame
	quit()

func _view(image_name: String, position_value: Vector3, yaw: float) -> void:
	game.player.global_position = position_value
	game.player.velocity = Vector3.ZERO
	game.player.get_node("CameraPivot").rotation = Vector3(-0.16, yaw, 0)
	game.world.last_player_location = game.world.closest_location(position_value)
	game.npc_manager.update_entities(position_value)
	game._update_proximity()
	game.interaction_ui.update_clock(game.world)
	await _capture(image_name)

func _capture(image_name: String) -> void:
	for _frame in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("user://echo_me_previews")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(image_name + ".png")
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		printerr("Preview image failed: ", result)
	else:
		print("PREVIEW: ", path)
	print("RENDER: ", image_name, "; draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "; objects ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
