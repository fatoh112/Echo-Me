extends Node3D
class_name PlayerVisual

const TARGET_HEIGHT := 1.82
enum LocomotionState { IDLE, WALK, RUN, INTERACT, TALK, SIT }
@export var idle_clip := ""
@export var walk_clip := ""
@export var run_clip := ""
@onready var model: Node3D = $KachujinModel
@onready var animation_tree: AnimationTree = $AnimationTree
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var locomotion_state := LocomotionState.IDLE
var usable_clips: Array[String] = []
var normalized_bounds := AABB()
var animations_ready := false

func _ready() -> void:
	_inspect_and_clean(model)
	var bounds := _model_bounds(model)
	var correction := TARGET_HEIGHT / maxf(bounds.size.y, 0.01)
	scale = Vector3.ONE * correction
	position.y = -bounds.position.y * correction
	# Mixamo eyes/toes face +Z. Controller's authoritative movement forward is -Z.
	rotation.y = PI
	normalized_bounds = AABB(Vector3(bounds.position.x * correction, 0, bounds.position.z * correction), bounds.size * correction)
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)
	var imported := MixamoAnimationLoader.attach(skeleton, animation_player)
	idle_clip = str(imported.get("IDLE", idle_clip))
	walk_clip = str(imported.get("WALK", walk_clip))
	run_clip = str(imported.get("RUN", run_clip))
	for clip in animation_player.get_animation_list():
		if animation_player.get_animation(clip).length > 0.15:
			usable_clips.append(clip)
	animation_player.stop()
	_prepare_animation_tree()
	if not animations_ready and idle_clip in usable_clips:
		animation_player.play(idle_clip)

func _process(_delta: float) -> void:
	var player := get_parent().get_parent() as CharacterBody3D
	if player == null:
		return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var next_state := LocomotionState.IDLE if speed < 0.1 else (LocomotionState.RUN if speed >= 4.0 else LocomotionState.WALK)
	if next_state != locomotion_state:
		locomotion_state = next_state
		if animations_ready:
			var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
			playback.travel(LocomotionState.keys()[locomotion_state])
		else:
			var clip := idle_clip if next_state == LocomotionState.IDLE else (run_clip if next_state == LocomotionState.RUN else walk_clip)
			if clip in usable_clips:
				animation_player.play(clip, 0.18)
			else:
				# Hold the last valid pose when a movement clip is missing.
				animation_player.pause()

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
	var names: Array[String] = ["IDLE", "WALK", "RUN"]
	var clips: Array[String] = [idle_clip, walk_clip, run_clip]
	animations_ready = true
	for index in range(names.size()):
		var state := AnimationNodeAnimation.new()
		if clips[index] in usable_clips:
			state.animation = clips[index]
		else:
			animations_ready = false
		machine.add_node(names[index], state, Vector2(index * 200, 60))
	for edge: Array in [["IDLE", "WALK"], ["WALK", "IDLE"], ["WALK", "RUN"], ["RUN", "WALK"], ["IDLE", "RUN"], ["RUN", "IDLE"]]:
		var transition := AnimationNodeStateMachineTransition.new()
		transition.xfade_time = 0.18
		machine.add_transition(edge[0], edge[1], transition)
	animation_tree.tree_root = machine
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	# Missing clips must never drive invalid animation nodes or alter physics.
	animation_tree.active = animations_ready
	if animations_ready:
		var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
		playback.start("IDLE")
