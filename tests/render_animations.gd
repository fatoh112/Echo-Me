extends SceneTree

var game: Node3D
var camera: Camera3D
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera = Camera3D.new()
	game.add_child(camera)
	camera.current = true
	await _movement("idle", "", false, 35)
	await _movement("walk", "move_forward", false, 22)
	await _movement("run", "move_forward", true, 18)
	await _movement("strafe_left", "move_left", false, 20)
	await _movement("strafe_right_run", "move_right", true, 20)
	await _movement("backward", "move_back", false, 25)
	await _movement("jump", "jump", false, 20)
	_reset()
	game.player.visual.play_talk()
	await _frames(35)
	await _capture("talk")
	game.player.visual.preview_animation("SIT")
	await _frames(40)
	await _capture("sit")
	game.player.visual.clear_preview()
	_reset()
	game.player.get_node("CameraPivot/Camera3D").current = true
	Input.action_press("move_forward")
	Input.action_press("run")
	await _frames(15)
	await _capture("run_camera")
	Input.action_release("move_forward")
	Input.action_release("run")
	game.debug_ui.panel.visible = true
	game.debug_ui.refresh()
	await _capture("animation_debug")
	game.queue_free()
	await process_frame
	quit(failures)

func _reset() -> void:
	game.player.global_position = Vector3(4, 0, 7)
	game.player.velocity = Vector3.ZERO
	game.player.body_visual.rotation = Vector3.ZERO
	game.player.camera_pivot.rotation = Vector3(-0.16, 0, 0)
	game.player.visual.talk_seconds = 0
	game.player.controls_enabled = true
	game.npc_manager.update_entities(game.player.global_position)

func _movement(label: String, action: String, running: bool, frames: int) -> void:
	_reset()
	await _frames(5)
	if not action.is_empty():
		Input.action_press(action)
	if running:
		Input.action_press("run")
	await _frames(frames)
	await _capture(label)
	# A second frame checks that motion is progressing, not a frozen pose.
	await _frames(8)
	await _capture(label + "_b")
	if not action.is_empty():
		Input.action_release(action)
	Input.action_release("run")

func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame
		camera.global_position = game.player.global_position + Vector3(-2.4, 1.7, -3.6)
		camera.look_at(game.player.global_position + Vector3(0, 0.95, 0))
	await process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("user://echo_me_animation_previews")
	DirAccess.make_dir_recursive_absolute(directory)
	var error := root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	if error != OK:
		failures += 1
	var rig: Skeleton3D = game.player.visual.skeleton
	var left := rig.get_bone_global_pose(rig.find_bone("mixamorig_LeftToeBase")).origin
	var right := rig.get_bone_global_pose(rig.find_bone("mixamorig_RightToeBase")).origin
	print("CAPTURE ", label, " state=", game.player.visual.state_name(), " speed=", game.player.horizontal_speed, " toe_local_y=", left.y, "/", right.y, " calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " -> ", directory.path_join(label + ".png"))
