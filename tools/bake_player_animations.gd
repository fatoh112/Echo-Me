extends SceneTree

# Reproducible offline bake: headless --script res://tools/bake_player_animations.gd.
# Gameplay loads only the resulting AnimationLibrary; it never opens these FBXs.
const FOLDER := "res://assets/animations/player/"
const OUTPUT := "res://assets/animations/player/player_locomotion.res"
const MAPPING := {
	"Idle.fbx": "IDLE", "walking.fbx": "WALK", "running.fbx": "RUN",
	"Jogging.fbx": "JOG", "jump.fbx": "JUMP", "Talking.fbx": "TALK",
	"Sitting.fbx": "SIT", "left strafe walk.fbx": "STRAFE_LEFT",
	"right strafe walk.fbx": "STRAFE_RIGHT", "left strafe.fbx": "STRAFE_LEFT_RUN",
	"right strafe.fbx": "STRAFE_RIGHT_RUN", "left turn.fbx": "TURN_LEFT",
	"right turn.fbx": "TURN_RIGHT", "Female Start Walking.fbx": "START_WALK",
}
const ONE_SHOTS := ["JUMP", "TURN_LEFT", "TURN_RIGHT", "START_WALK"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var target_model := (load("res://assets/characters/player/Kachujin G Rosales.fbx") as PackedScene).instantiate()
	var target := target_model.find_child("Skeleton3D", true, false) as Skeleton3D
	var library := AnimationLibrary.new()
	var manifest: Dictionary = {"library": OUTPUT, "import_fps": 30, "clips": {}, "excluded": {"Kachujin G Rosales.fbx": "one-frame bind pose, not an animation"}}
	for file_name: String in MAPPING:
		var source := (load(FOLDER + file_name) as PackedScene).instantiate()
		var rig := source.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var original: Animation
		var selected_clip_name := ""
		for clip_name in player.get_animation_list():
			var candidate := player.get_animation(clip_name)
			if clip_name != "RESET" and candidate.length > 0.15 and (original == null or candidate.length > original.length):
				original = candidate
				selected_clip_name = str(clip_name)
		if original == null or not _compatible(rig, target, original):
			manifest.excluded[file_name] = "no compatible animated bone tracks"
			source.free()
			continue
		var name_value: String = MAPPING[file_name]
		var clip := original.duplicate(true) as Animation
		var root_speed := 0.0
		for track in range(original.get_track_count()):
			if str(original.track_get_path(track)) == "Skeleton3D:mixamorig_Hips" and original.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var first: Vector3 = original.track_get_key_value(track, 0)
				var last: Vector3 = original.track_get_key_value(track, original.track_get_key_count(track) - 1)
				root_speed = Vector2(last.x - first.x, last.z - first.z).length() * (1.82 / 2.07741) / clip.length
		_retarget(clip, rig, target, name_value)
		if name_value == "JUMP":
			# Remove anticipation and ground landing; physics supplies the actual arc.
			clip = _slice(clip, 0.43, 1.40)
		clip.loop_mode = Animation.LOOP_NONE if name_value in ONE_SHOTS else Animation.LOOP_LINEAR
		library.add_animation(name_value, clip)
		manifest.clips[name_value] = {"source": file_name, "source_clip": selected_clip_name, "duration": clip.length, "source_duration": original.length, "native_speed_mps": root_speed, "loop": clip.loop_mode == Animation.LOOP_LINEAR, "gameplay": name_value not in ["JOG", "SIT", "TURN_LEFT", "TURN_RIGHT", "START_WALK"]}
		print("BAKED ", name_value, " duration=", clip.length, " native speed=", root_speed)
		source.free()
	target_model.free()
	if library.get_animation_list().size() != MAPPING.size():
		printerr("Incomplete bake; preserve previous library")
		quit(1)
		return
	var error := ResourceSaver.save(library, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	var file := FileAccess.open("res://data/animations/player_clips.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	quit(0 if error == OK else 1)

func _compatible(source: Skeleton3D, target: Skeleton3D, clip: Animation) -> bool:
	if source == null or source.get_bone_count() != target.get_bone_count():
		return false
	for track in range(clip.get_track_count()):
		var path := clip.track_get_path(track)
		if path.get_subname_count() != 1:
			return false
		var name_value := str(path.get_subname(0))
		var a := source.find_bone(name_value)
		var b := target.find_bone(name_value)
		if a < 0 or b < 0 or source.get_bone_parent(a) != target.get_bone_parent(b):
			return false
		var rest_a := source.get_bone_rest(a)
		var rest_b := target.get_bone_rest(b)
		if rest_a.origin.distance_to(rest_b.origin) > 0.025 or rest_a.basis.get_rotation_quaternion().angle_to(rest_b.basis.get_rotation_quaternion()) > deg_to_rad(1.1):
			return false
	return true

func _retarget(clip: Animation, source: Skeleton3D, target: Skeleton3D, state: String) -> void:
	for track in range(clip.get_track_count() - 1, -1, -1):
		var type := clip.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			clip.remove_track(track)
			continue
		var bone := str(clip.track_get_path(track).get_subname(0))
		var source_rest := source.get_bone_rest(source.find_bone(bone))
		var target_rest := target.get_bone_rest(target.find_bone(bone))
		clip.track_set_path(track, NodePath("Skeleton3D:" + bone))
		var correction := target_rest.basis.get_rotation_quaternion() * source_rest.basis.get_rotation_quaternion().inverse()
		for key in range(clip.track_get_key_count(track)):
			if type == Animation.TYPE_ROTATION_3D:
				var value: Quaternion = correction * (clip.track_get_key_value(track, key) as Quaternion)
				# These supplied lateral clips face along their baked lateral travel.
				# Normalize to +Z; the controller turns Body toward the travel vector.
				if bone == "mixamorig_Hips" and state.begins_with("STRAFE"):
					value = Quaternion(Vector3.UP, -PI / 2 if state.contains("LEFT") else PI / 2) * value
				clip.track_set_key_value(track, key, value.normalized())
			elif type == Animation.TYPE_POSITION_3D:
				var value: Vector3 = target_rest.origin + (clip.track_get_key_value(track, key) as Vector3) - source_rest.origin
				if bone == "mixamorig_Hips":
					value.x = target_rest.origin.x
					value.z = target_rest.origin.z
					if state == "JUMP":
						value.y = 1.111
				clip.track_set_key_value(track, key, value)

func _slice(source: Animation, start: float, end: float) -> Animation:
	var result := Animation.new()
	result.length = end - start
	for track in range(source.get_track_count()):
		var type := source.track_get_type(track)
		var output_track := result.add_track(type)
		result.track_set_path(output_track, source.track_get_path(track))
		result.track_insert_key(output_track, 0, _sample(source, track, start))
		for key in range(source.track_get_key_count(track)):
			var time := source.track_get_key_time(track, key)
			if time > start and time < end:
				result.track_insert_key(output_track, time - start, source.track_get_key_value(track, key))
		result.track_insert_key(output_track, result.length, _sample(source, track, end))
	return result

func _sample(clip: Animation, track: int, time: float) -> Variant:
	match clip.track_get_type(track):
		Animation.TYPE_POSITION_3D: return clip.position_track_interpolate(track, time)
		Animation.TYPE_ROTATION_3D: return clip.rotation_track_interpolate(track, time)
		Animation.TYPE_SCALE_3D: return clip.scale_track_interpolate(track, time)
	return null
