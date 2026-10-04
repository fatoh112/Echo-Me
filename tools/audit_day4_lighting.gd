extends SceneTree
## Read-only lighting audit of the current runtime-built world.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var environment := Environment.new()
	for property: Dictionary in environment.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("ssao_") or property_name.begins_with("glow_") or property_name.begins_with("fog_") or property_name in ["tonemapper", "tonemap_exposure", "ambient_light_source", "ambient_light_color", "ambient_light_energy", "background_mode", "sky"]:
			print("Environment.%s = %s" % [property_name, environment.get(property_name)])
	print("LightmapGI.bake_available = ", ClassDB.class_has_method("LightmapGI", "bake"))
	print("GeometryInstance3D.gi_mode_constants = ", ClassDB.class_get_enum_constants("GeometryInstance3D", "GIMode"))
	print("LightmapGI.properties:")
	var lightmap := LightmapGI.new()
	for property: Dictionary in lightmap.get_property_list():
		var property_name: String = property["name"]
		if property_name in ["bounds", "aabb", "generate_probes_subdiv", "quality", "shadowmask_mode", "light_data", "environment_mode", "bounces", "texel_scale", "directional"]:
			print("  %s = %s" % [property_name, lightmap.get(property_name)])
	print("DirectionalLight3D.shadow_properties:")
	var light := DirectionalLight3D.new()
	for property: Dictionary in light.get_property_list():
		var property_name: String = property["name"]
		if property_name.contains("shadow") or property_name.contains("directional_") or property_name == "light_bake_mode":
			print("  %s = %s" % [property_name, light.get(property_name)])
	print("ReflectionProbe.properties:")
	var probe := ReflectionProbe.new()
	for property: Dictionary in probe.get_property_list():
		var property_name: String = property["name"]
		if property_name in ["update_mode", "intensity", "max_distance", "extents", "ambient_mode", "ambient_color", "ambient_color_energy", "interior", "box_projection", "origin_offset", "cull_mask"]:
			print("  %s = %s" % [property_name, probe.get(property_name)])
	var pack := load("res://assets/environment/slavic_town/glb/glTF/EA03_Environment_Road_Cobble_01a.glb") as PackedScene
	var imported := pack.instantiate()
	var mesh_instance := _find_mesh(imported)
	assert(mesh_instance != null)
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	print("Imported mesh: type=%s vertices=%d colors=%d normals=%d uv=%d uv2=%d tangents=%d format=%d" % [
		mesh_instance.mesh.get_class(), _array_size(arrays[Mesh.ARRAY_VERTEX]), _array_size(arrays[Mesh.ARRAY_COLOR]),
		_array_size(arrays[Mesh.ARRAY_NORMAL]), _array_size(arrays[Mesh.ARRAY_TEX_UV]), _array_size(arrays[Mesh.ARRAY_TEX_UV2]),
		_array_size(arrays[Mesh.ARRAY_TANGENT]), mesh_instance.mesh.surface_get_format(0),
	])
	print("Imported mesh GI mode: ", mesh_instance.gi_mode, "; UV2 data flag: ", mesh_instance.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2 != 0)
	imported.free()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var counts := {"DirectionalLight3D": 0, "OmniLight3D": 0, "SpotLight3D": 0, "ReflectionProbe": 0, "LightmapGI": 0, "WorldEnvironment": 0, "shadowed": 0, "emissive_materials": 0, "MultiMeshInstance3D": 0}
	_count_lighting(main, counts)
	print("Current scene lighting and mesh nodes: ", counts)
	main.queue_free()
	await process_frame
	lightmap.free()
	light.free()
	probe.free()
	quit()


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


func _array_size(value: Variant) -> int:
	if value is PackedVector3Array or value is PackedVector2Array or value is PackedColorArray or value is PackedFloat32Array or value is PackedInt32Array or value is PackedInt64Array:
		return value.size()
	return 0


func _count_lighting(node: Node, counts: Dictionary) -> void:
	if node is DirectionalLight3D:
		counts["DirectionalLight3D"] += 1
		if (node as DirectionalLight3D).shadow_enabled:
			counts["shadowed"] += 1
	elif node is OmniLight3D:
		counts["OmniLight3D"] += 1
		if (node as OmniLight3D).shadow_enabled:
			counts["shadowed"] += 1
	elif node is SpotLight3D:
		counts["SpotLight3D"] += 1
		if (node as SpotLight3D).shadow_enabled:
			counts["shadowed"] += 1
	elif node is ReflectionProbe:
		counts["ReflectionProbe"] += 1
	elif node is LightmapGI:
		counts["LightmapGI"] += 1
	elif node is WorldEnvironment:
		counts["WorldEnvironment"] += 1
	elif node is MultiMeshInstance3D:
		counts["MultiMeshInstance3D"] += 1
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface)
			if material is BaseMaterial3D and (material as BaseMaterial3D).emission_enabled:
				counts["emissive_materials"] += 1
	for child: Node in node.get_children():
		_count_lighting(child, counts)
