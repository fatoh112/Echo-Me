extends SceneTree
## One-time authoring build. Saves optimized UV2 ArrayMeshes and the static
## neighborhood scene; runtime does not scan assets or construct the town.
const SCENE_PATH := "res://scenes/world/neighborhood.tscn"
const LIGHT_DATA_PATH := "res://scenes/world/town_lighting.lmbake"
const MESH_DIRECTORY := "res://assets/environment/slavic_town/baked/"
const REPORT_PATH := "res://data/environment/town_asset_selection.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := Neighborhood.new()
	town.name = "Neighborhood"
	root.add_child(town)
	var locations: Dictionary = DataUtils.dictionary(DataUtils.read_json("res://data/neighborhood.json"))
	town.build(locations)
	var mesh_directory := ProjectSettings.globalize_path(MESH_DIRECTORY)
	var make_directory := DirAccess.make_dir_recursive_absolute(mesh_directory)
	if make_directory != OK:
		printerr("Could not create optimized town mesh directory: ", make_directory)
		quit(1)
		return
	var shadow_chunks := 0
	for chunk: MeshInstance3D in town.assets.geometry.get_children():
		var path := MESH_DIRECTORY + chunk.name + ".res"
		var save_error := ResourceSaver.save(chunk.mesh, path)
		if save_error != OK:
			printerr("Could not save bakeable mesh ", path, ": ", save_error)
			quit(1)
			return
		chunk.mesh = ResourceLoader.load(path) as ArrayMesh
		if chunk.mesh == null or chunk.mesh.surface_get_array_len(0) == 0:
			printerr("Saved bakeable mesh cannot be reloaded: ", path)
			quit(1)
			return
		var arrays := chunk.mesh.surface_get_arrays(0)
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		if uv2.size() != chunk.mesh.surface_get_array_len(0):
			printerr("Saved mesh has invalid UV2: ", path)
			quit(1)
			return
		if chunk.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow_chunks += 1
	var lightmap := town.get_node("LightmapGI") as LightmapGI
	var light_data := LightmapGIData.new()
	var save_light_data := ResourceSaver.save(light_data, LIGHT_DATA_PATH)
	if save_light_data != OK:
		printerr("Could not create LightmapGI data resource: ", save_light_data)
		quit(1)
		return
	lightmap.light_data = ResourceLoader.load(LIGHT_DATA_PATH) as LightmapGIData
	if lightmap.light_data == null:
		printerr("The LightmapGI data resource cannot be reloaded.")
		quit(1)
		return
	var used: Array = town.assets.sources.keys()
	used.sort()
	var selection := {
		"pack": "Slavic Medieval Town Kit Lite",
		"source_root": "res://assets/environment/slavic_town/",
		"used_glbs": used,
		"imported_source_count": 225,
		"asset_mesh_instances": town.assets.instance_count,
		"small_primitive_instances": town.builder.instance_count,
		"total_batches_including_ground": town.visual_batch_count,
		"bakeable_mesh_count": town.assets.batch_count + 1,
		"bakeable_shadow_chunks": shadow_chunks,
		"submitted_asset_vertices": town.assets.vertex_count,
		"lightmap_uv2_vertices": town.assets.lightmap_vertex_count,
		"lightmap_texel_size": AssetTownBuilder.LIGHTMAP_TEXEL_SIZE,
		"lightmap_data": LIGHT_DATA_PATH,
	}
	var report := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report == null:
		printerr("Could not write used source report: ", FileAccess.get_open_error())
		quit(1)
		return
	report.store_string(JSON.stringify(selection, "\t") + "\n")
	report.close()
	_set_owner(town, town)
	var packed := PackedScene.new()
	var pack_error := packed.pack(town)
	if pack_error != OK:
		printerr("Could not pack authored town scene: ", pack_error)
		quit(1)
		return
	var scene_error := ResourceSaver.save(packed, SCENE_PATH)
	if scene_error != OK:
		printerr("Could not save authored town scene: ", scene_error)
		quit(1)
		return
	var verify := ResourceLoader.load(SCENE_PATH) as PackedScene
	var verify_root := verify.instantiate() as Neighborhood if verify != null else null
	if verify_root == null or verify_root.get_node_or_null("LightmapGI") == null or verify_root.get_node_or_null("SlavicTown") == null:
		printerr("The saved town scene failed its reload check.")
		quit(1)
		return
	print("AUTHORED TOWN: ", selection["asset_mesh_instances"], " GLB instances; ", selection["submitted_asset_vertices"], " source vertices; ", selection["bakeable_mesh_count"], " UV2 bake meshes; ", shadow_chunks, " shadow chunks; ", used.size(), " source GLBs; ", town.visual_batch_count, " runtime render batches")
	verify_root.free()
	town.free()
	quit()


func _set_owner(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_set_owner(child, owner)
