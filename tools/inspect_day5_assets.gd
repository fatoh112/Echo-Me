extends SceneTree
## Read-only catalogue of the supplied Day 5 GLB and medieval-character packs.
const ENVIRONMENT_SCENE := "res://assets/environment/mountain_village/glb_mega_village_environment_4_houses/GLB Mega Village Environment 4 Houses/Mega Village Environment 4 Houses GLB.glb"
const NPC_ROOT := "res://assets/characters/npcs/medieval_people/Free Medieval 3D People Low Poly Pack/fbx/"
const EXPORTS := ["people_unity", "unral_better_export"]


func _initialize() -> void:
	call_deferred("_inspect")


func _inspect() -> void:
	var report := {
		"environment": _inspect_environment(),
		"npc_models": _inspect_npcs(),
	}
	var output := FileAccess.open("res://data/environment/day5_asset_inventory.json", FileAccess.WRITE)
	if output == null:
		printerr("Could not write Day 5 asset inventory: ", FileAccess.get_open_error())
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("DAY 5 ASSETS: inventory saved; ", report["environment"]["mesh_instance_count"], " placed environment mesh instances; ", report["npc_models"].size(), " FBX files inspected")
	quit()


func _inspect_environment() -> Dictionary:
	var packed := load(ENVIRONMENT_SCENE) as PackedScene
	if packed == null:
		printerr("Environment GLB did not import as a PackedScene: ", ENVIRONMENT_SCENE)
		return {"error": "PackedScene import failed", "source": ENVIRONMENT_SCENE}
	var scene := packed.instantiate()
	root.add_child(scene)
	var mesh_instances: Array = scene.find_children("*", "MeshInstance3D", true, false)
	var light_count := scene.find_children("*", "Light3D", true, false).size()
	var mesh_names: Dictionary = {}
	var unique_meshes: Dictionary = {}
	var total_vertices := 0
	var total_triangles := 0
	var materials: Dictionary = {}
	var material_details: Dictionary = {}
	var world_bounds := AABB()
	var bounds_initialized := false
	var placed_meshes: Array[Dictionary] = []
	for instance: MeshInstance3D in mesh_instances:
		if instance.mesh == null:
			continue
		mesh_names[instance.name] = mesh_names.get(instance.name, 0) + 1
		unique_meshes[instance.mesh.get_instance_id()] = true
		var local_bounds := instance.get_aabb()
		var transformed_bounds := _transform_aabb(local_bounds, instance.global_transform)
		placed_meshes.append({
			"node": str(scene.get_path_to(instance, true)),
			"name": instance.name,
			"mesh": instance.mesh.resource_name if not instance.mesh.resource_name.is_empty() else instance.mesh.resource_path.get_file(),
			"position": _vector_array(instance.global_position),
			"bounds_min": _vector_array(transformed_bounds.position),
			"bounds_max": _vector_array(transformed_bounds.end),
			"surface_count": instance.mesh.get_surface_count(),
		})
		if bounds_initialized:
			world_bounds = world_bounds.merge(transformed_bounds)
		else:
			world_bounds = transformed_bounds
			bounds_initialized = true
		for surface in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total_vertices += vertices.size()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			total_triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var material := instance.get_active_material(surface)
			if material != null:
				materials[material.resource_name if not material.resource_name.is_empty() else material.resource_path.get_file()] = true
				material_details[material.get_instance_id()] = _material_details(material)
	var named: Array[String] = []
	for candidate: MeshInstance3D in mesh_instances:
		if candidate.name.to_lower().contains("floor") or candidate.name.to_lower().contains("wall") or candidate.name.to_lower().contains("door") or candidate.name.to_lower().contains("fireplace") or candidate.name.to_lower().contains("bridge") or candidate.name.to_lower().contains("cliff") or candidate.name.to_lower().contains("roof"):
			named.append(candidate.name)
	named.sort()
	var bounds_size := world_bounds.size if bounds_initialized else Vector3.ZERO
	var light_nodes: Array[Dictionary] = []
	for light: Light3D in scene.find_children("*", "Light3D", true, false):
		var light_info := {"node": str(light.name), "position": _vector_array(light.global_position), "type": light.get_class(), "energy": light.light_energy, "shadows": light.shadow_enabled}
		if light is OmniLight3D:
			light_info["range"] = (light as OmniLight3D).omni_range
		light_nodes.append(light_info)
	var result := {
		"source": ENVIRONMENT_SCENE,
		"scene_root": scene.name,
		"top_level_node_count": scene.get_child_count(),
		"mesh_instance_count": mesh_instances.size(),
		"unique_mesh_resource_count": unique_meshes.size(),
		"surface_material_count": materials.size(),
		"materials": material_details.values(),
		"light_count": light_count,
		"placed_vertex_count_with_reuse": total_vertices,
		"triangle_count_with_reuse": total_triangles,
		"world_bounds_min": world_bounds.position,
		"world_bounds_max": world_bounds.end,
		"world_bounds_size": bounds_size,
		"notable_mesh_node_names": named,
		"source_mesh_instance_names": mesh_names.keys(),
		"placed_meshes": placed_meshes,
		"lights": light_nodes,
	}
	scene.queue_free()
	return result


func _inspect_npcs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for export_name: String in EXPORTS:
		var directory := NPC_ROOT.path_join(export_name)
		var dir := DirAccess.open(directory)
		if dir == null:
			printerr("Could not scan NPC export folder: ", directory)
			continue
		for file_name in dir.get_files():
			if not file_name.to_lower().ends_with(".fbx"):
				continue
			var source_path := directory.path_join(file_name)
			var packed := load(source_path) as PackedScene
			var entry := _inspect_npc_scene(source_path, packed)
			result.append(entry)
			print("NPC ASSET: ", entry["model"], " | rig ", entry["skeleton_bones"], " bones | ", entry["vertex_count"], " vertices | height ", snappedf(float(entry["height_m"]), 0.01), " m | anims ", entry["animation_names"])
	return result


func _inspect_npc_scene(source_path: String, packed: PackedScene) -> Dictionary:
	var entry := {
		"source": source_path,
		"model": source_path.get_file().get_basename(),
		"export_variant": source_path.get_base_dir().get_file(),
		"imported": packed != null,
		"skeleton_count": 0,
		"skeleton_bones": 0,
		"animation_players": 0,
		"animation_names": [],
		"mesh_instance_count": 0,
		"surface_count": 0,
		"vertex_count": 0,
		"triangle_count": 0,
		"material_count": 0,
		"texture_sizes": [],
		"height_m": 0.0,
		"width_m": 0.0,
		"depth_m": 0.0,
		"up_axis_looks_humanoid": false,
	}
	if packed == null:
		return entry
	var scene := packed.instantiate()
	root.add_child(scene)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	entry["skeleton_count"] = skeletons.size()
	for skeleton: Skeleton3D in skeletons:
		entry["skeleton_bones"] += skeleton.get_bone_count()
	var animation_names: Array[String] = []
	for player: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
		entry["animation_players"] += 1
		for clip in player.get_animation_list():
			animation_names.append(str(clip))
	entry["animation_names"] = animation_names
	var mesh_instances: Array = scene.find_children("*", "MeshInstance3D", true, false)
	entry["mesh_instance_count"] = mesh_instances.size()
	var materials: Dictionary = {}
	var material_details: Dictionary = {}
	var textures: Dictionary = {}
	var bounds := AABB()
	var initialized := false
	for instance: MeshInstance3D in mesh_instances:
		if instance.mesh == null:
			continue
		var candidate_bounds := _transform_aabb(instance.get_aabb(), instance.global_transform)
		if initialized:
			bounds = bounds.merge(candidate_bounds)
		else:
			bounds = candidate_bounds
			initialized = true
		for surface in range(instance.mesh.get_surface_count()):
			entry["surface_count"] += 1
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			entry["vertex_count"] += vertices.size()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			entry["triangle_count"] += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var material := instance.get_active_material(surface)
			if material == null:
				continue
			materials[material.get_instance_id()] = true
			material_details[material.get_instance_id()] = _material_details(material)
			if material is BaseMaterial3D:
				var texture := (material as BaseMaterial3D).albedo_texture
				if texture != null:
					textures["%dx%d" % [texture.get_width(), texture.get_height()]] = true
		entry["material_count"] = materials.size()
	entry["materials"] = material_details.values()
	entry["texture_sizes"] = textures.keys()
	if initialized:
		entry["height_m"] = bounds.size.y
		entry["width_m"] = bounds.size.x
		entry["depth_m"] = bounds.size.z
		entry["up_axis_looks_humanoid"] = bounds.size.y > bounds.size.x and bounds.size.y > bounds.size.z
	scene.queue_free()
	return entry


func _transform_aabb(local_bounds: AABB, transform: Transform3D) -> AABB:
	var corners: Array[Vector3] = []
	for x in [local_bounds.position.x, local_bounds.end.x]:
		for y in [local_bounds.position.y, local_bounds.end.y]:
			for z in [local_bounds.position.z, local_bounds.end.z]:
				corners.append(transform * Vector3(x, y, z))
	var result := AABB(corners[0], Vector3.ZERO)
	for corner: Vector3 in corners:
		result = result.expand(corner)
	return result


func _vector_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _material_details(material: Material) -> Dictionary:
	var details := {"name": material.resource_name, "class": material.get_class()}
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		details["albedo_color"] = standard.albedo_color
		details["vertex_color_use_as_albedo"] = standard.vertex_color_use_as_albedo
		details["albedo_texture"] = _texture_details(standard.albedo_texture)
		details["normal_texture"] = _texture_details(standard.normal_texture)
		details["roughness_texture"] = _texture_details(standard.roughness_texture)
		details["metallic_texture"] = _texture_details(standard.metallic_texture)
		details["ao_texture"] = _texture_details(standard.ao_texture)
		details["roughness"] = standard.roughness
		details["metallic"] = standard.metallic
		return details
	if material is BaseMaterial3D:
		details["albedo_color"] = (material as BaseMaterial3D).albedo_color
	return details


func _texture_details(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	return {"path": texture.resource_path, "name": texture.resource_name, "width": texture.get_width(), "height": texture.get_height()}
