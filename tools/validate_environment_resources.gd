extends SceneTree
## Offline authoring audit: do not run this traversal during gameplay.
const ATLAS := "res://assets/environment/slavic_town/materials/slavic_atlas.tres"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/slavic_town_sources.json"))
	if not catalog is Array:
		printerr("Invalid environment catalogue")
		quit(1)
		return
	var errors: Array[String] = []
	var categories: Dictionary = {}
	var meshes := 0
	var vertices := 0
	var shared := load(ATLAS) as StandardMaterial3D
	for row: Dictionary in catalog:
		var path := "res://" + str(row["file"])
		var category := str(row["category"])
		categories[category] = int(categories.get(category, 0)) + 1
		if not FileAccess.file_exists(path) or not ResourceLoader.exists(path):
			errors.append("Missing source/import: " + path)
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			errors.append("Cannot load: " + path)
			continue
		var model := packed.instantiate() as Node3D
		for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_node.mesh
			meshes += 1
			for surface in range(mesh.get_surface_count()):
				vertices += mesh.surface_get_array_len(surface)
				if mesh.surface_get_material(surface) != shared:
					errors.append("Unshared material: " + path)
				var arrays := mesh.surface_get_arrays(surface)
				if arrays[Mesh.ARRAY_VERTEX].is_empty() or arrays[Mesh.ARRAY_NORMAL].is_empty() or arrays[Mesh.ARRAY_TEX_UV].is_empty():
					errors.append("Missing vertex/normal/UV data: " + path)
		if not model.find_children("*", "CollisionObject3D", true, false).is_empty():
			errors.append("Unexpected generated model physics: " + path)
		model.free()
	for identity: String in ["house_cottage", "house_merchant", "house_inn", "market_stall", "barrel_group", "bench", "fence_segment", "well", "watch_tower"]:
		var path := "res://scenes/environment/" + identity + ".tscn"
		if load(path) == null:
			errors.append("Missing prefab: " + path)
	if shared == null or shared.albedo_texture == null or shared.metallic > 0.01 or shared.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		errors.append("Invalid atlas material")
	for error: String in errors:
		printerr(error)
	print("ENVIRONMENT RESOURCE AUDIT: ", catalog.size(), " sources; ", meshes, " meshes; ", vertices, " source vertices; ", categories.size(), " categories; ", errors.size(), " errors")
	if errors.is_empty() and "--write-selection" in OS.get_cmdline_user_args():
		var town := (load("res://scenes/world/neighborhood.tscn") as PackedScene).instantiate() as Neighborhood
		root.add_child(town)
		town.build(DataUtils.dictionary(DataUtils.read_json("res://data/neighborhood.json")))
		var used := town.assets.sources.keys()
		used.sort()
		var selection := {
			"pack": "Slavic Medieval Town Kit Lite",
			"source_root": "res://assets/environment/slavic_town/",
			"used_glbs": used,
			"imported_source_count": catalog.size(),
			"asset_mesh_instances": town.assets.instance_count,
			"small_primitive_instances": town.builder.instance_count,
			"total_batches_including_ground": town.visual_batch_count,
			"submitted_asset_vertices": town.assets.vertex_count,
		}
		var file := FileAccess.open("res://data/environment/town_asset_selection.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(selection, "\t") + "\n")
		file.close()
		town.free()
	quit(0 if errors.is_empty() else 1)
