extends SceneTree

# Offline authoring tool. Never called by gameplay or from a frame loop.
const FOLDER := "res://assets/animations/player/"
const TARGET := "res://assets/characters/player/Kachujin G Rosales.fbx"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var target_model := (load(TARGET) as PackedScene).instantiate()
	var target := target_model.find_child("Skeleton3D", true, false) as Skeleton3D
	var report: Dictionary = {"imported_fps": 30, "target_bones": [], "files": []}
	for index in range(target.get_bone_count()):
		report.target_bones.append(str(target.get_bone_name(index)))
	for file_name in DirAccess.get_files_at(FOLDER):
		if file_name.get_extension().to_lower() != "fbx":
			continue
		var source := (load(FOLDER + file_name) as PackedScene).instantiate()
		root.add_child(source)
		var rigs := source.find_children("*", "Skeleton3D", true, false)
		var players := source.find_children("*", "AnimationPlayer", true, false)
		var entry: Dictionary = {"file": file_name, "skeletons": rigs.size(), "meshes": source.find_children("*", "MeshInstance3D", true, false).size(), "root_transform": str(source.transform), "clips": []}
		entry.merge(_source_frame_rate(FOLDER + file_name))
		if not rigs.is_empty():
			var rig := rigs[0] as Skeleton3D
			entry.bones = rig.get_bone_count()
			entry.skeleton_transform = str(rig.transform)
			entry.missing_target_bones = []
			entry.extra_bones = []
			var rest_error := 0.0
			var basis_error := 0.0
			for index in range(rig.get_bone_count()):
				var bone_name := str(rig.get_bone_name(index))
				var target_index := target.find_bone(bone_name)
				if target_index < 0:
					entry.extra_bones.append(bone_name)
					continue
				var source_rest := rig.get_bone_rest(index)
				var target_rest := target.get_bone_rest(target_index)
				rest_error = maxf(rest_error, source_rest.origin.distance_to(target_rest.origin))
				basis_error = maxf(basis_error, source_rest.basis.get_rotation_quaternion().angle_to(target_rest.basis.get_rotation_quaternion()))
			for bone_name in report.target_bones:
				if rig.find_bone(bone_name) < 0:
					entry.missing_target_bones.append(bone_name)
			entry.max_rest_position_error = rest_error
			entry.max_rest_angle_error_degrees = rad_to_deg(basis_error)
			entry.hips_rest = str(rig.get_bone_rest(rig.find_bone("mixamorig_Hips")).origin)
			if not players.is_empty():
				var player := players[0] as AnimationPlayer
				for clip_name in player.get_animation_list():
					var clip := player.get_animation(clip_name)
					var info: Dictionary = {"name": clip_name, "duration": clip.length, "tracks": clip.get_track_count(), "animated_bones": [], "incompatible_bones": []}
					var root_min := Vector3(INF, INF, INF)
					var root_max := Vector3(-INF, -INF, -INF)
					var max_seam_angle := 0.0
					var steps: Array[float] = []
					for track in range(clip.get_track_count()):
						var path := clip.track_get_path(track)
						var bone := str(path.get_subname(0)) if path.get_subname_count() else ""
						if bone not in info.animated_bones:
							info.animated_bones.append(bone)
						if target.find_bone(bone) < 0:
							info.incompatible_bones.append(bone)
						var keys := clip.track_get_key_count(track)
						if keys > 1 and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
							var first: Quaternion = clip.track_get_key_value(track, 0)
							var last: Quaternion = clip.track_get_key_value(track, keys - 1)
							max_seam_angle = maxf(max_seam_angle, rad_to_deg(first.angle_to(last)))
						if bone == "mixamorig_Hips" and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
							info.hips_first = str(clip.track_get_key_value(track, 0))
							info.hips_last = str(clip.track_get_key_value(track, keys - 1))
							info.hips_keys = keys
							for key in range(keys):
								var value: Vector3 = clip.track_get_key_value(track, key)
								root_min = root_min.min(value)
								root_max = root_max.max(value)
								if key > 0:
									steps.append(clip.track_get_key_time(track, key) - clip.track_get_key_time(track, key - 1))
						if bone == "mixamorig_Hips" and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
							info.hips_first_rotation = str((clip.track_get_key_value(track, 0) as Quaternion).get_euler())
							info.hips_last_rotation = str((clip.track_get_key_value(track, keys - 1) as Quaternion).get_euler())
					info.hips_range = str(root_max - root_min)
					info.max_loop_seam_degrees = max_seam_angle
					steps.sort()
					info.median_optimized_key_rate_hz = 1.0 / steps[steps.size() / 2] if not steps.is_empty() else 0
					entry.clips.append(info)
		print(JSON.stringify(entry))
		report.files.append(entry)
		source.free()
	target_model.free()
	var output := FileAccess.open("res://data/animations/source_inspection.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	quit()

func _source_frame_rate(path: String) -> Dictionary:
	# Read only the supplied binary FBX's typed TimeMode metadata, offline.
	# FBX/uFBX TimeMode 6 is 30 FPS. Unknown encodings stay explicitly unknown.
	var bytes := FileAccess.get_file_as_bytes(path)
	var suffix := PackedByteArray([83, 4, 0, 0, 0, 101, 110, 117, 109, 83, 0, 0, 0, 0, 83, 0, 0, 0, 0, 73])
	var offset := bytes.find(84)
	while offset >= 0 and offset + 32 <= bytes.size():
		if bytes.slice(offset, offset + 8) == "TimeMode".to_ascii_buffer() and bytes.slice(offset + 8, offset + 28) == suffix:
			var mode := bytes.decode_s32(offset + 28)
			return {"source_time_mode": mode, "source_fps": 30 if mode == 6 else null}
		offset = bytes.find(84, offset + 1)
	return {"source_time_mode": null, "source_fps": null}
