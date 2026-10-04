extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new()
	camera.position = Vector3(27, 30, 32)
	game.add_child(camera)
	camera.look_at(Vector3(0, 0, -2))
	camera.current = true
	await _capture("neighborhood")
	camera.current = false
	(game.player.get_node("CameraPivot/Camera3D") as Camera3D).current = true
	var sarah: NPCData = game.world.npcs["sarah"]
	game.player.global_position = game.world.npc_position(sarah) + Vector3(0, 0, 2.5)
	game.npc_manager.update_entities(game.player.global_position)
	game._update_proximity()
	game.interaction_ui.open_for_npc(sarah)
	await _capture("interaction")
	game.interaction_ui.close_all()
	var now := Time.get_unix_time_from_system()
	for index in range(8):
		ActionSystem.apply(game.world, WorldAction.create("HELP", "sarah", "park", "PLAYER", now - 10 + index))
	var action := WorldAction.create("BETRAY", "sarah", "park", "ECHO", now)
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


func _capture(image_name: String) -> void:
	for _frame in range(5):
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
