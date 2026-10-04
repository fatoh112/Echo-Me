extends RefCounted
class_name MixamoAnimationLoader

const FOLDER := "res://assets/animations/player/"
const NAMES: Dictionary = {"idle": "IDLE", "walk": "WALK", "walking": "WALK", "run": "RUN", "running": "RUN"}

static func attach(target: Skeleton3D, player: AnimationPlayer) -> Dictionary:
	var attached: Dictionary = {}
	if target == null or not DirAccess.dir_exists_absolute(FOLDER):
		return attached
	var library := AnimationLibrary.new()
	for file_name in DirAccess.get_files_at(FOLDER):
		if file_name.get_extension().to_lower() != "fbx":
			continue
		var state := str(NAMES.get(file_name.get_basename().to_lower(), ""))
		if state.is_empty() or attached.has(state):
			continue
		var packed := load(FOLDER + file_name) as PackedScene
		if packed == null:
			continue
		var source := packed.instantiate()
		var skeletons := source.find_children("*", "Skeleton3D", true, false)
		var players := source.find_children("*", "AnimationPlayer", true, false)
		if skeletons.is_empty() or players.is_empty():
			source.free()
			continue
		var source_skeleton := skeletons[0] as Skeleton3D
		var source_player := players[0] as AnimationPlayer
		var longest: Animation
		for name_value in source_player.get_animation_list():
			var candidate := source_player.get_animation(name_value)
			if name_value != "RESET" and candidate.length > 0.15 and (longest == null or candidate.length > longest.length):
				longest = candidate
		if longest != null and _compatible(source_skeleton, target, longest):
			var clip := longest.duplicate(true) as Animation
			clip.loop_mode = Animation.LOOP_LINEAR
			_rebind(clip, target, player)
			library.add_animation(state, clip)
			attached[state] = "locomotion/" + state
		source.free()
	if not attached.is_empty():
		player.add_animation_library("locomotion", library)
	return attached

static func _compatible(source: Skeleton3D, target: Skeleton3D, clip: Animation) -> bool:
	for track in range(clip.get_track_count()):
		var path := clip.track_get_path(track)
		if path.get_subname_count() == 0:
			continue
		var bone_name := str(path.get_subname(0))
		var source_index := source.find_bone(bone_name)
		var target_index := target.find_bone(bone_name)
		if source_index < 0 or target_index < 0:
			return false
		var source_rest := source.get_bone_rest(source_index)
		var target_rest := target.get_bone_rest(target_index)
		if source_rest.origin.distance_to(target_rest.origin) > 0.025 or not source_rest.basis.is_equal_approx(target_rest.basis):
			return false
	return true

static func _rebind(clip: Animation, target: Skeleton3D, player: AnimationPlayer) -> void:
	var animation_root := player.get_node(player.root_node)
	var skeleton_path := str(animation_root.get_path_to(target))
	for track in range(clip.get_track_count() - 1, -1, -1):
		var path := clip.track_get_path(track)
		if path.get_subname_count() == 0 or clip.track_get_type(track) not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			clip.remove_track(track)
			continue
		var bone_name := str(path.get_subname(0))
		clip.track_set_path(track, NodePath(skeleton_path + ":" + bone_name))
		if bone_name == "mixamorig_Hips" and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			var rest := target.get_bone_rest(target.find_bone(bone_name)).origin
			for key in range(clip.track_get_key_count(track)):
				var value: Vector3 = clip.track_get_key_value(track, key)
				value.x = rest.x
				value.z = rest.z
				clip.track_set_key_value(track, key, value)
