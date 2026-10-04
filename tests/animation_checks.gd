extends RefCounted

func run(game: Node3D, check: Callable) -> void:
	var player: PlayerController = game.player
	var visual := player.visual
	var tree := visual.animation_tree.tree_root as AnimationNodeStateMachine
	var library := visual.animation_player.get_animation_library("locomotion")
	check.call(library != null and library.get_animation_list().size() == 14, "Animation: fourteen baked clips load")
	check.call(visual.animations_ready and visual.animation_tree.active, "Animation: valid active tree")
	check.call(visual.animation_tree.get_node(visual.animation_tree.anim_player) == visual.animation_player, "Animation: tree references authoritative player")
	check.call(player.find_children("*", "Skeleton3D", true, false).size() == 1, "Animation: exactly one player skeleton")
	check.call(visual.model.find_children("*", "MeshInstance3D", true, false).size() == 1, "Animation: exactly one skinned body")
	check.call(visual.animation_player.get_animation_library_list().size() == 1, "Animation: no imported bind-pose library")
	check.call(player.get_node("CameraPivot").get_parent() == player, "Animation: camera independent of skeleton")
	check.call(InputMap.has_action("run") and InputMap.has_action("jump"), "Animation: run/jump inputs registered")
	check.call(player.run_multiplier >= 1.6 and player.run_multiplier <= 1.9, "Animation: configured run ratio")
	check.call(visual.transition_seconds >= 0.15 and visual.transition_seconds <= 0.25, "Animation: short crossfades")
	for state: String in PlayerVisual.TREE_STATES:
		check.call(tree.has_node(state), "Animation: state exists " + state)
		check.call(tree.get_node(state) is AnimationNodeBlendTree, "Animation: cadence node exists " + state)
	for clip_name in library.get_animation_list():
		var clip := library.get_animation(clip_name)
		var bindings_valid := true
		var root_in_place := true
		var no_jump_arc := true
		for track in range(clip.get_track_count()):
			var path := clip.track_get_path(track)
			bindings_valid = bindings_valid and path.get_subname_count() == 1 and path.get_concatenated_names() == "Skeleton3D"
			if path.get_subname_count() != 1:
				continue
			var bone := str(path.get_subname(0))
			bindings_valid = bindings_valid and visual.skeleton.find_bone(bone) >= 0
			if bone == "mixamorig_Hips" and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var rest := visual.skeleton.get_bone_rest(0).origin
				for key in range(clip.track_get_key_count(track)):
					var value: Vector3 = clip.track_get_key_value(track, key)
					root_in_place = root_in_place and is_equal_approx(value.x, rest.x) and is_equal_approx(value.z, rest.z)
					if clip_name == "JUMP":
						no_jump_arc = no_jump_arc and is_equal_approx(value.y, 1.111)
		check.call(bindings_valid, "Animation: only valid bone bindings " + clip_name)
		check.call(root_in_place, "Animation: root XZ locked " + clip_name)
		check.call(no_jump_arc, "Animation: no duplicate physics jump arc " + clip_name)
		check.call(clip.get_track_count() >= 50 and clip.length > 0.15, "Animation: multi-frame motion " + clip_name)
		var expected_loop := clip_name not in ["JUMP", "TURN_LEFT", "TURN_RIGHT", "START_WALK"]
		check.call((clip.loop_mode == Animation.LOOP_LINEAR) == expected_loop, "Animation: correct loop policy " + clip_name)
	var report := DataUtils.dictionary(DataUtils.read_json("res://data/animations/source_inspection.json"))
	check.call(report.files.size() >= 14, "Animation: all usable supplied FBXs inspected (optional rejected pose stays local)")
	for row: Dictionary in report.files:
		check.call(row.bones == 75 and row.missing_target_bones.is_empty() and row.extra_bones.is_empty(), "Animation: complete matching source bone names " + str(row.file))
		check.call(row.source_fps == 30, "Animation: verified original source frame rate " + str(row.file))
	var old_position := player.global_position
	var old_rotation := player.body_visual.rotation
	var old_camera := player.camera_pivot.rotation
	player.controls_enabled = true
	player.global_position = Vector3(4, 0, 7)
	player.velocity = Vector3.ZERO
	player.camera_pivot.rotation = Vector3(-0.16, 0, 0)
	visual.talk_seconds = 0
	await _frames(game, 5)
	check.call(visual.state_name() == "IDLE" and visual.playback.get_current_node() == "IDLE", "Animation: initial grounded Idle")
	var idle_leg := visual.skeleton.get_bone_pose_rotation(65)
	Input.action_press("move_forward")
	await _frames(game, 20)
	check.call(visual.state_name() == "WALK", "Animation: velocity selects Walk")
	check.call(is_equal_approx(player.horizontal_speed, player.walk_speed), "Animation: configured walk speed")
	check.call(not idle_leg.is_equal_approx(visual.skeleton.get_bone_pose_rotation(65)), "Animation: walk evaluates skeleton pose")
	Input.action_press("run")
	await _frames(game, 14)
	check.call(visual.state_name() == "RUN", "Animation: Shift selects Run")
	check.call(is_equal_approx(player.horizontal_speed, player.walk_speed * player.run_multiplier), "Animation: run speed resolves through physics")
	check.call(player.camera_pivot.rotation.is_equal_approx(Vector3(-0.16, 0, 0)), "Animation: run never rotates camera")
	Input.action_release("run")
	Input.action_release("move_forward")
	player.global_position = Vector3(4, 0, 7)
	Input.action_press("move_left")
	await _frames(game, 25)
	check.call(visual.state_name() == "STRAFE_LEFT" and player.velocity.x < 0, "Animation: camera-relative left travel")
	check.call((-player.body_visual.global_basis.z).dot(player.velocity.normalized()) > 0.98, "Animation: lateral character faces travel smoothly")
	Input.action_release("move_left")
	Input.action_press("move_right")
	Input.action_press("run")
	await _frames(game, 25)
	check.call(visual.state_name() == "STRAFE_RIGHT" and player.velocity.x > 0, "Animation: camera-relative right travel")
	check.call(visual._strafe_blend > 0.9, "Animation: fast lateral gait blends by speed")
	Input.action_release("move_right")
	Input.action_release("run")
	Input.action_press("move_back")
	await _frames(game, 25)
	check.call(visual.state_name() == "WALK" and player.velocity.z > 0, "Animation: backward input moves intuitively")
	check.call((-player.body_visual.global_basis.z).dot(player.velocity.normalized()) > 0.98, "Animation: backward travel rotates toward movement")
	Input.action_release("move_back")
	await _frames(game, 5)
	var start_y := player.global_position.y
	Input.action_press("jump")
	await _frames(game, 3)
	Input.action_release("jump")
	check.call(not player.is_on_floor() and visual.state_name() == "JUMP", "Animation: grounded Space jump becomes airborne")
	check.call(player.velocity.y > 0 and player.global_position.y > start_y, "Animation: physics supplies upward arc")
	var air_velocity := player.velocity.y
	Input.action_press("jump")
	await _frames(game, 3)
	Input.action_release("jump")
	check.call(player.velocity.y < air_velocity, "Animation: no double jump")
	await _frames(game, 85)
	check.call(player.is_on_floor() and absf(player.global_position.y - start_y) < 0.04, "Animation: gravity lands on ground")
	check.call(visual.state_name() == "IDLE", "Animation: landing returns to Idle")
	visual.play_talk(0.2)
	await _frames(game, 3)
	check.call(visual.state_name() == "TALK", "Animation: temporary talk starts")
	await _frames(game, 20)
	check.call(visual.state_name() == "IDLE", "Animation: talk expires without permanent loop")
	visual.play_talk()
	Input.action_press("move_forward")
	await _frames(game, 3)
	check.call(visual.state_name() == "WALK" and visual.talk_seconds == 0, "Animation: movement cancels talk")
	Input.action_release("move_forward")
	await _frames(game, 3)
	for state: String in PlayerVisual.PREVIEW_STATES:
		check.call(visual.preview_animation(state, 0.15), "Animation: preview accepts " + state)
		await _frames(game, 2)
		check.call(visual.state_name() == state and player.preview_locked, "Animation: preview state " + state)
		visual.clear_preview()
	check.call(not visual.preview_animation("MISSING"), "Animation: invalid preview is rejected")
	visual.preview_animation("SIT", 0.15)
	await _frames(game, 15)
	check.call(visual.state_name() == "IDLE" and not player.preview_locked, "Animation: Sit preview timeout restores control")
	visual.preview_animation("SIT")
	Input.action_press("move_forward")
	await _frames(game, 3)
	check.call(not player.preview_locked and visual.state_name() == "WALK", "Animation: movement cancels preview")
	Input.action_release("move_forward")
	await _frames(game, 3)
	var sarah: NPCData = game.world.npcs.sarah
	player.global_position = game.world.npc_position(sarah) + Vector3(0, 0, 2)
	game.npc_manager.update_entities(player.global_position)
	game._update_proximity()
	await _frames(game, 5)
	game.interaction_ui.open_for_npc(sarah)
	await _frames(game, 3)
	check.call(visual.state_name() == "TALK" and not player.controls_enabled, "Animation: interaction starts timed Talk")
	game.interaction_ui.close_all()
	visual.talk_seconds = 0
	game.debug_ui.refresh()
	check.call("PLAYER ANIMATION:" in game.debug_ui.animation_label.text and "SPEED:" in game.debug_ui.animation_label.text and "ON FLOOR:" in game.debug_ui.animation_label.text, "Animation: optional F3 telemetry")
	await _npc_hooks(game, check)
	player.global_position = old_position
	player.body_visual.rotation = old_rotation
	player.camera_pivot.rotation = old_camera
	player.velocity = Vector3.ZERO
	game.world.player_position = old_position
	await _frames(game, 3)

func _frames(game: Node, count: int) -> void:
	for _index in range(count):
		await game.get_tree().physics_frame
	await game.get_tree().process_frame

func _npc_hooks(game: Node, check: Callable) -> void:
	var model := Node3D.new()
	var animations := AnimationPlayer.new()
	animations.name = "AnimationPlayer"
	model.add_child(animations)
	animations.owner = model
	var library := AnimationLibrary.new()
	library.add_animation("idle", Animation.new())
	animations.add_animation_library("", library)
	var scene := PackedScene.new()
	scene.pack(model)
	model.free()
	var npc_visual := NPCVisual.new()
	game.add_child(npc_visual)
	npc_visual.replace_model(scene)
	check.call(npc_visual.animation_player != null, "Animation: future NPC cached AnimationPlayer hook")
	npc_visual.set_animation_active(false)
	check.call(npc_visual._humanoid.process_mode == Node.PROCESS_MODE_DISABLED, "Animation: distant NPC animation evaluation disabled")
	npc_visual.set_animation_active(true)
	check.call(npc_visual.play_optional_animation("idle"), "Animation: optional NPC animation can play")
	check.call(not npc_visual.play_optional_animation("missing"), "Animation: absent NPC clip skipped safely")
	npc_visual.build("alex")
	check.call(npc_visual.get_child_count() == 1 and npc_visual.piece_count == 0, "Animation: replacement avoids duplicate primitive body")
	npc_visual.queue_free()
	await game.get_tree().process_frame
