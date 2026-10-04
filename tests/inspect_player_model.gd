extends SceneTree

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var arguments := OS.get_cmdline_user_args()
	var path := arguments[0] if not arguments.is_empty() else "res://assets/characters/player/Kachujin G Rosales.fbx"
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("FBX failed to load")
		quit(1)
		return
	var model := packed.instantiate()
	root.add_child(model)
	await process_frame
	_walk(model, 0)
	model.queue_free()
	await process_frame
	quit()

func _walk(node: Node, depth: int) -> void:
	print("  ".repeat(depth), node.name, " : ", node.get_class())
	if node is Node3D:
		print("  ".repeat(depth), "transform ", node.transform)
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		print("  ".repeat(depth), "bounds ", node.global_transform * mesh.get_aabb(), "; surfaces ", mesh.get_surface_count())
		for index in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(index)
			print("  ".repeat(depth), "vertices ", arrays[Mesh.ARRAY_VERTEX].size())
			var mat := mesh.surface_get_material(index) as StandardMaterial3D
			if mat != null:
				print("  ".repeat(depth), "material ", mat.resource_name, " color ", mat.albedo_color, " transparent ", mat.transparency)
				for property_name in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture"]:
					var texture: Texture2D = mat.get(property_name)
					if texture != null:
						print("  ".repeat(depth), property_name, " ", texture.get_size())
	if node is Skeleton3D:
		print("BONES: ", node.get_bone_count())
		for index in range(node.get_bone_count()):
			print(index, ": ", node.get_bone_name(index), " parent ", node.get_bone_parent(index), " rest ", node.get_bone_rest(index).origin)
	if node is AnimationPlayer:
		for animation_name in node.get_animation_list():
			var animation: Animation = node.get_animation(animation_name)
			print("ANIMATION: ", animation_name, " duration ", animation.length, " tracks ", animation.get_track_count())
			for index in range(mini(4, animation.get_track_count())):
				print("TRACK: ", animation.track_get_path(index), " type ", animation.track_get_type(index))
	for child in node.get_children():
		_walk(child, depth + 1)
