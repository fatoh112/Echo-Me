extends SceneTree
## Retargets the player's baked Mixamo clips to the supplied NPC pack skeleton.
## Run after tools/bake_player_animations.gd.

const PLAYER_MODEL := "res://assets/characters/player/Kachujin G Rosales.fbx"
const NPC_MODEL := "res://assets/characters/npcs/medieval_people/Free Medieval 3D People Low Poly Pack/fbx/unral_better_export/rich_citizens_2.fbx"
const INPUT_LIBRARY := "res://assets/animations/player/player_locomotion.res"
const OUTPUT_LIBRARY := "res://assets/animations/npcs/npc_locomotion.res"
const MANIFEST := "res://data/animations/npc_clips.json"
const BONE_MAP := {
	"mixamorig_Hips": "Pelvis",
	"mixamorig_Spine": "Spine_01", "mixamorig_Spine1": "Spine_02", "mixamorig_Spine2": "Spine_03",
	"mixamorig_Neck": "Neck_01", "mixamorig_Head": "Head",
	"mixamorig_LeftShoulder": "Clavicle_L", "mixamorig_LeftArm": "Upperarm_L",
	"mixamorig_LeftForeArm": "Lowerarm_L", "mixamorig_LeftHand": "Hand_L",
	"mixamorig_LeftHandThumb1": "Thumb_01_L", "mixamorig_LeftHandThumb2": "Thumb_02_L", "mixamorig_LeftHandThumb3": "Thumb_03_L",
	"mixamorig_LeftHandIndex1": "Index_01_L", "mixamorig_LeftHandIndex2": "Index_02_L", "mixamorig_LeftHandIndex3": "Index_03_L",
	"mixamorig_LeftHandRing1": "Ring_01_L", "mixamorig_LeftHandRing2": "Ring_02_L", "mixamorig_LeftHandRing3": "Ring_03_L",
	"mixamorig_RightShoulder": "Clavicle_R", "mixamorig_RightArm": "Upperarm_R",
	"mixamorig_RightForeArm": "Lowerarm_R", "mixamorig_RightHand": "Hand_R",
	"mixamorig_RightHandThumb1": "Thumb_01_R", "mixamorig_RightHandThumb2": "Thumb_02_R", "mixamorig_RightHandThumb3": "Thumb_03_R",
	"mixamorig_RightHandIndex1": "Index_01_R", "mixamorig_RightHandIndex2": "Index_02_R", "mixamorig_RightHandIndex3": "Index_03_R",
	"mixamorig_RightHandRing1": "Ring_01_R", "mixamorig_RightHandRing2": "Ring_02_R", "mixamorig_RightHandRing3": "Ring_03_R",
	"mixamorig_LeftUpLeg": "Thigh_L", "mixamorig_LeftLeg": "Calf_L",
	"mixamorig_LeftFoot": "Foot_L", "mixamorig_LeftToeBase": "Ball_L",
	"mixamorig_RightUpLeg": "Thigh_R", "mixamorig_RightLeg": "Calf_R",
	"mixamorig_RightFoot": "Foot_R", "mixamorig_RightToeBase": "Ball_R",
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source_model := (load(PLAYER_MODEL) as PackedScene).instantiate()
	var target_model := (load(NPC_MODEL) as PackedScene).instantiate()
	var source_skeleton := source_model.find_child("Skeleton3D", true, false) as Skeleton3D
	var target_skeleton := target_model.find_child("Skeleton3D", true, false) as Skeleton3D
	var source_library := load(INPUT_LIBRARY) as AnimationLibrary
	if source_skeleton == null or target_skeleton == null or source_library == null:
		printerr("NPC animation bake failed: player/NPC skeleton or player clip library is missing")
		quit(1)
		return
	var target_path := str(target_model.get_path_to(target_skeleton))
	var output := AnimationLibrary.new()
	var manifest: Dictionary = {"source_library": INPUT_LIBRARY, "target_skeleton": NPC_MODEL, "clips": {}}
	for clip_name in source_library.get_animation_list():
		var source_clip := source_library.get_animation(clip_name)
		var clip := Animation.new()
		clip.length = source_clip.length
		clip.loop_mode = source_clip.loop_mode
		clip.step = source_clip.step
		var mapped_tracks := 0
		for source_track in source_clip.get_track_count():
			var source_path := source_clip.track_get_path(source_track)
			if source_path.get_subname_count() != 1:
				continue
			var source_bone := str(source_path.get_subname(0))
			if not BONE_MAP.has(source_bone):
				continue
			var target_bone := str(BONE_MAP[source_bone])
			var source_index := source_skeleton.find_bone(source_bone)
			var target_index := target_skeleton.find_bone(target_bone)
			if source_index < 0 or target_index < 0:
				continue
			var track_type := source_clip.track_get_type(source_track)
			if track_type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				continue
			var out_track := clip.add_track(track_type)
			clip.track_set_path(out_track, NodePath(target_path + ":" + target_bone))
			clip.track_set_interpolation_type(out_track, source_clip.track_get_interpolation_type(source_track))
			clip.track_set_interpolation_loop_wrap(out_track, source_clip.track_get_interpolation_loop_wrap(source_track))
			var source_rest := source_skeleton.get_bone_rest(source_index)
			var target_rest := target_skeleton.get_bone_rest(target_index)
			var rotation_correction := target_rest.basis.get_rotation_quaternion() * source_rest.basis.get_rotation_quaternion().inverse()
			for key_index in source_clip.track_get_key_count(source_track):
				var time := source_clip.track_get_key_time(source_track, key_index)
				var value: Variant = source_clip.track_get_key_value(source_track, key_index)
				match track_type:
					Animation.TYPE_ROTATION_3D:
						clip.track_insert_key(out_track, time, (rotation_correction * (value as Quaternion)).normalized())
					Animation.TYPE_POSITION_3D:
						var position: Vector3 = target_rest.origin + (value as Vector3) - source_rest.origin
						if source_bone == "mixamorig_Hips":
							position.x = target_rest.origin.x
							position.z = target_rest.origin.z
						clip.track_insert_key(out_track, time, position)
					Animation.TYPE_SCALE_3D:
						clip.track_insert_key(out_track, time, value)
			mapped_tracks += 1
		if mapped_tracks == 0:
			printerr("No compatible NPC tracks for clip: ", clip_name)
			quit(1)
			return
		output.add_animation(clip_name, clip)
		manifest.clips[str(clip_name)] = {"track_count": mapped_tracks, "duration_seconds": clip.length, "loop_mode": clip.loop_mode}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/animations/npcs"))
	var save_error := ResourceSaver.save(output, OUTPUT_LIBRARY, ResourceSaver.FLAG_COMPRESS)
	var manifest_file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	manifest_file.store_string(JSON.stringify(manifest, "\t") + "\n")
	manifest_file.close()
	print("NPC ANIMATIONS: ", output.get_animation_list().size(), " clips baked for ", target_skeleton.get_bone_count(), "-bone NPC rig; track path ", target_path)
	source_model.free()
	target_model.free()
	quit(0 if save_error == OK else 1)
