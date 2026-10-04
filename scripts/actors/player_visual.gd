extends Node3D
class_name PlayerVisual

const TARGET_HEIGHT := 1.82
enum LocomotionState { IDLE, WALK, RUN, INTERACT, TALK, SIT, JUMP, STRAFE_LEFT, STRAFE_RIGHT, JOG, TURN_LEFT, TURN_RIGHT, START_WALK }
const TREE_STATES := ["IDLE", "WALK", "RUN", "JUMP", "TALK", "SIT", "STRAFE_LEFT", "STRAFE_RIGHT", "JOG", "TURN_LEFT", "TURN_RIGHT", "START_WALK"]
const PREVIEW_STATES := ["IDLE", "WALK", "RUN", "JUMP", "TALK", "SIT", "STRAFE_LEFT", "STRAFE_RIGHT", "JOG", "TURN_LEFT", "TURN_RIGHT", "START_WALK"]
@export_range(0.15, 0.25, 0.01) var transition_seconds := 0.18
@onready var model: Node3D = $KachujinModel
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var controller: PlayerController = get_parent().get_parent()
var idle_clip := "locomotion/IDLE"
var walk_clip := "locomotion/WALK"
var run_clip := "locomotion/RUN"
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var playback: AnimationNodeStateMachinePlayback
var locomotion_state := LocomotionState.IDLE
var usable_clips: Array[String] = []
var normalized_bounds := AABB()
var animations_ready := false
var preview_state := ""
var preview_seconds := 0.0
var talk_seconds := 0.0
var horizontal_speed := 0.0
var _cadence := 1.0
var _strafe_blend := 0.0
var _clip_data: Dictionary = {}


func _ready() -> void:
	_inspect_and_clean(model)
	var bounds := _model_bounds(model)
	var correction := TARGET_HEIGHT / maxf(bounds.size.y, 0.01)
	scale = Vector3.ONE * correction
	position.y = -bounds.position.y * correction
	# Mixamo +Z forward becomes the controller's -Z forward.
	rotation.y = PI
	normalized_bounds = AABB(Vector3(bounds.position.x * correction, 0, bounds.position.z * correction), bounds.size * correction)
	MixamoAnimationLoader.attach(skeleton, animation_player)
	for clip in animation_player.get_animation_list():
		if animation_player.get_animation(clip).length > 0.15:
			usable_clips.append(clip)
	_clip_data = DataUtils.dictionary(DataUtils.read_json("res://data/animations/player_clips.json")).get("clips", {})
	animation_player.stop()
	_prepare_animation_tree()
	# Evaluate once after the authoritative CharacterBody update, on physics ticks.
	process_physics_priority = 1
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.advance(0.0)


func _physics_process(delta: float) -> void:
	if not animations_ready:
		return
	horizontal_speed = Vector2(controller.velocity.x, controller.velocity.z).length()
	talk_seconds = maxf(0, talk_seconds - delta)
	preview_seconds = maxf(0, preview_seconds - delta)
	if not preview_state.is_empty() and preview_seconds <= 0:
		clear_preview()
	var next_state := _choose_state()
	_set_state(next_state)
	var native_speed := _native_speed(next_state)
	if next_state.begins_with("STRAFE"):
		var target_blend := clampf((horizontal_speed - controller.walk_speed) / maxf(controller.walk_speed * (controller.run_multiplier - 1), 0.1), 0, 1)
		_strafe_blend = move_toward(_strafe_blend, target_blend, delta / transition_seconds)
		animation_tree.set("parameters/" + next_state + "/Gait/blend_position", _strafe_blend)
		native_speed = lerpf(_native_speed(next_state), _native_speed(next_state + "_RUN"), _strafe_blend)
	var moving := next_state in ["WALK", "RUN", "STRAFE_LEFT", "STRAFE_RIGHT", "JOG"]
	var target_rate := clampf(horizontal_speed / maxf(native_speed, 0.1), 0.25, 3.5) if moving else 1.0
	if not preview_state.is_empty():
		target_rate = 1.0
	_cadence = lerpf(_cadence, target_rate, 1.0 - exp(-18.0 * delta))
	animation_tree.set("parameters/" + next_state + "/Rate/scale", _cadence)
	animation_tree.advance(delta)


func _choose_state() -> String:
	if not preview_state.is_empty():
		return preview_state
	if not controller.is_on_floor():
		return "JUMP"
	if horizontal_speed > 0.1:
		talk_seconds = 0.0
		# Identify lateral travel relative to the camera, including collision slides.
		var local_velocity := Basis(Vector3.UP, controller.camera_pivot.rotation.y).inverse() * controller.velocity
		if absf(local_velocity.x) > absf(local_velocity.z) * 2.0:
			return "STRAFE_LEFT" if local_velocity.x < 0 else "STRAFE_RIGHT"
		return "RUN" if horizontal_speed > controller.walk_speed * 1.15 else "WALK"
	return "TALK" if talk_seconds > 0 else "IDLE"


func play_talk(duration: float = 2.5) -> void:
	clear_preview()
	talk_seconds = clampf(duration, 0.1, 5.0)


func preview_animation(state: String, duration: float = 4.0) -> bool:
	if state not in PREVIEW_STATES or not animations_ready:
		return false
	preview_state = state
	preview_seconds = clampf(duration, 0.1, 20)
	talk_seconds = 0.0
	controller.preview_locked = true
	controller.velocity.x = 0
	controller.velocity.z = 0
	_cadence = 1.0
	_set_state(state)
	animation_tree.set("parameters/" + state + "/Rate/scale", 1.0)
	return true


func clear_preview() -> void:
	preview_state = ""
	preview_seconds = 0
	controller.preview_locked = false


func state_name() -> String:
	return LocomotionState.keys()[locomotion_state]


func _native_speed(state: String) -> float:
	return float(DataUtils.dictionary(_clip_data.get(state, {})).get("native_speed_mps", 0.0))


func _set_state(state: String) -> void:
	var next_value: int = LocomotionState[state]
	if next_value != locomotion_state:
		locomotion_state = next_value
		playback.travel(state)


func _inspect_and_clean(node: Node) -> void:
	for child in node.get_children():
		if child is Camera3D or child is Light3D or child is CollisionObject3D or child is CollisionShape3D:
			node.remove_child(child)
			child.queue_free()
			continue
		if child is Skeleton3D:
			skeleton = child
		if child is AnimationPlayer:
			animation_player = child
		if child is MeshInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for index in range(child.mesh.get_surface_count()):
				var source := child.mesh.surface_get_material(index) as StandardMaterial3D
				if source != null:
					var material := source.duplicate() as StandardMaterial3D
					material.roughness = 0.88
					material.metallic = 0.0
					material.albedo_color.a = 1.0
					# Hair uses a cheap cutout rather than alpha blending.
					if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						material.alpha_scissor_threshold = 0.45
					child.set_surface_override_material(index, material)
		_inspect_and_clean(child)

func _model_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := candidate as MeshInstance3D
		var relative := node.global_transform.affine_inverse() * mesh_node.global_transform
		var mesh_bounds := relative * mesh_node.get_aabb()
		bounds = bounds.merge(mesh_bounds) if found else mesh_bounds
		found = true
	return bounds

func _prepare_animation_tree() -> void:
	var machine := AnimationNodeStateMachine.new()
	animations_ready = true
	for index in range(TREE_STATES.size()):
		var state: String = TREE_STATES[index]
		var tree := AnimationNodeBlendTree.new()
		var rate := AnimationNodeTimeScale.new()
		tree.add_node("Rate", rate, Vector2(220, 40))
		tree.connect_node("output", 0, "Rate")
		if state.begins_with("STRAFE"):
			var gait := AnimationNodeBlendSpace1D.new()
			gait.min_space = 0
			gait.max_space = 1
			gait.sync = true
			for blend_index in range(2):
				var clip := AnimationNodeAnimation.new()
				clip.animation = "locomotion/" + state + ("_RUN" if blend_index else "")
				animations_ready = animations_ready and clip.animation in usable_clips
				gait.add_blend_point(clip, blend_index, -1, "Walk" if blend_index == 0 else "Run")
			tree.add_node("Gait", gait)
			tree.connect_node("Rate", 0, "Gait")
		else:
			var clip := AnimationNodeAnimation.new()
			clip.animation = "locomotion/" + state
			animations_ready = animations_ready and clip.animation in usable_clips
			tree.add_node("Clip", clip)
			tree.connect_node("Rate", 0, "Clip")
		machine.add_node(state, tree, Vector2((index % 4) * 200, (index / 4) * 100))
	for from_state: String in TREE_STATES:
		for to_state: String in TREE_STATES:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = transition_seconds
			machine.add_transition(from_state, to_state, transition)
	animation_tree.tree_root = machine
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.active = animations_ready
	playback = animation_tree.get("parameters/playback")
	if animations_ready:
		playback.start("IDLE")
