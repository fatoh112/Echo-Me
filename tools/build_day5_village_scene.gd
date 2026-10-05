extends SceneTree
## One-time authoring tool: merge imported PBR surfaces into spatial, UV2-ready chunks.
## Runtime scene uses the saved meshes and authored collision sections only.

const SOURCE_PATH := "res://assets/environment/mountain_village/glb_mega_village_environment_4_houses/GLB Mega Village Environment 4 Houses/Mega Village Environment 4 Houses GLB.glb"
const OUTPUT_SCENE := "res://scenes/world/mountain_village_optimized.tscn"
const LIGHT_DATA_PATH := "res://scenes/world/premium_village.lmbake"
const MESH_DIR := "res://assets/environment/mountain_village/baked/"
const CELL_SIZE := 80.0
const LIGHTMAP_TEXEL_SIZE := 0.32
const HOUSE_CENTERS: Array[Vector2] = [Vector2(41.5, -57.0), Vector2(37.0, -79.5), Vector2(24.0, -92.0), Vector2(13.2, -81.0)]
const PLAYER_HOUSE_DOOR_CENTER := Vector3(15.170366, 2.29008, -80.91562)
const PLAYER_HOUSE_DOOR_WIDTH := 1.4

var chunks: Dictionary = {}
var collision_groups: Dictionary = {}
var collision_seen_positions: Dictionary = {}
var original_mesh_count := 0
var placed_vertex_count := 0
var collision_shape_count := 0
var open_door_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory_path := ProjectSettings.globalize_path(MESH_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(directory_path)
	if mkdir_error != OK:
		printerr("Could not create optimized village mesh directory: ", mkdir_error)
		quit(1)
		return
	var source_packed := load(SOURCE_PATH) as PackedScene
	if source_packed == null:
		printerr("Could not load Mountain Village source scene.")
		quit(1)
		return
	var source := source_packed.instantiate() as Node3D
	root.add_child(source)
	await process_frame
	var optimized := Node3D.new()
	optimized.name = "MountainVillageOptimized"
	var hidden_source := Node3D.new()
	hidden_source.name = "CollisionSource"
	hidden_source.visible = false
	optimized.add_child(hidden_source)
	hidden_source.owner = optimized
	var light_root := Node3D.new()
	light_root.name = "ImportedLights"
	optimized.add_child(light_root)
	light_root.owner = optimized
	var visuals := Node3D.new()
	visuals.name = "StaticVisuals"
	optimized.add_child(visuals)
	visuals.owner = optimized
	var source_meshes := source.find_children("*", "MeshInstance3D", true, false)
	for node in source_meshes:
		var mesh_instance := node as MeshInstance3D
		original_mesh_count += 1
		if mesh_instance.mesh == null:
			continue
		if str(mesh_instance.name).begins_with("S_Modular_Wooden_Door_"):
			mesh_instance.visible = false
			open_door_count += 1
			continue
		var shadow := _casts_shadow(str(mesh_instance.name))
		var cell := Vector2i(floori(mesh_instance.global_position.x / CELL_SIZE), floori(mesh_instance.global_position.z / CELL_SIZE))
		var cell_origin := Vector3(float(cell.x) * CELL_SIZE, 0.0, float(cell.y) * CELL_SIZE)
		var transform := mesh_instance.global_transform
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index)
			if material == null:
				continue
			var material_identity := material.resource_path if not material.resource_path.is_empty() else "%s_%d" % [material.resource_name, material.get_instance_id()]
			var key := "%d_%d_%s_%d_%d" % [cell.x, cell.y, _safe_name(material.resource_name), hash(material_identity), int(shadow)]
			if not chunks.has(key):
				chunks[key] = _new_chunk(cell, cell_origin, material, shadow)
			_append_surface(chunks[key], mesh_instance.mesh, surface_index, transform, cell_origin)
			placed_vertex_count += mesh_instance.mesh.surface_get_array_len(surface_index)
		_collect_collision(mesh_instance, cell)
	_copy_lights(source, light_root, optimized)
	var bake_count := 0
	for key: String in chunks:
		var entry: Dictionary = chunks[key]
		var mesh := _make_lightmap_mesh(entry, key)
		if mesh == null:
			quit(1)
			return
		var path := MESH_DIR + "Day5_" + key + ".res"
		var save_error := ResourceSaver.save(mesh, path)
		if save_error != OK:
			printerr("Could not save UV2 mesh ", path, ": ", save_error)
			quit(1)
			return
		var instance := MeshInstance3D.new()
		instance.name = "BakeChunk_" + key
		instance.mesh = ResourceLoader.load(path) as ArrayMesh
		instance.position = entry["cell_origin"]
		instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if entry["casts_shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.lod_bias = 0.8
		visuals.add_child(instance)
		instance.owner = optimized
		bake_count += 1
	var collision_count := _write_collision(optimized)
	root.remove_child(source)
	source.free()
	optimized.set_meta("day5_source_mesh_instances", original_mesh_count)
	optimized.set_meta("day5_authored_render_batches", bake_count)
	optimized.set_meta("day5_placed_vertices", placed_vertex_count)
	optimized.set_meta("day5_collision_sections", collision_count)
	optimized.set_meta("day5_collision_shapes", collision_shape_count)
	optimized.set_meta("day5_open_door_leaves", open_door_count)
	_set_owner(optimized, optimized)
	var packed := PackedScene.new()
	var pack_error := packed.pack(optimized)
	if pack_error != OK:
		printerr("Could not pack optimized village: ", pack_error)
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_SCENE)
	if save_error != OK:
		printerr("Could not save optimized village scene: ", save_error)
		quit(1)
		return
	var light_data_error := ResourceSaver.save(LightmapGIData.new(), LIGHT_DATA_PATH)
	if light_data_error != OK:
		printerr("Could not create LightmapGI bake target: ", light_data_error)
		quit(1)
		return
	print("DAY 5 AUTHORED VILLAGE: ", original_mesh_count, " source meshes, ", placed_vertex_count, " placed vertices, ", bake_count, " spatial PBR chunks, ", collision_count, " static collision sections, ", collision_shape_count, " box collision shapes.")
	optimized.free()
	quit(0)

func _new_chunk(cell: Vector2i, cell_origin: Vector3, material: Material, shadow: bool) -> Dictionary:
	return {
		"cell": cell, "cell_origin": cell_origin, "material": material, "casts_shadow": shadow,
		"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"uv": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array(),
	}

func _append_surface(entry: Dictionary, mesh: Mesh, surface_index: int, transform: Transform3D, cell_origin: Vector3) -> void:
	var arrays := mesh.surface_get_arrays(surface_index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors := PackedColorArray()
	if arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		colors = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var vertex_offset := (entry["vertices"] as PackedVector3Array).size()
	var normal_transform := transform.basis.inverse().transposed()
	var out_vertices: PackedVector3Array = entry["vertices"]
	var out_normals: PackedVector3Array = entry["normals"]
	var out_uv: PackedVector2Array = entry["uv"]
	var out_colors: PackedColorArray = entry["colors"]
	var out_indices: PackedInt32Array = entry["indices"]
	for vertex_index in range(vertices.size()):
		out_vertices.append(transform * vertices[vertex_index] - cell_origin)
		out_normals.append((normal_transform * normals[vertex_index]).normalized() if normals.size() == vertices.size() else Vector3.UP)
		out_uv.append(uvs[vertex_index] if uvs.size() == vertices.size() else Vector2.ZERO)
		out_colors.append(colors[vertex_index] if colors.size() == vertices.size() else Color.WHITE)
	if indices.is_empty():
		for vertex_index in range(vertices.size()):
			out_indices.append(vertex_offset + vertex_index)
	else:
		for index in indices:
			out_indices.append(vertex_offset + index)
	entry["vertices"] = out_vertices
	entry["normals"] = out_normals
	entry["uv"] = out_uv
	entry["colors"] = out_colors
	entry["indices"] = out_indices

func _make_lightmap_mesh(entry: Dictionary, key: String) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = entry["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = entry["normals"]
	arrays[Mesh.ARRAY_TEX_UV] = entry["uv"]
	arrays[Mesh.ARRAY_COLOR] = entry["colors"]
	arrays[Mesh.ARRAY_INDEX] = entry["indices"]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, entry["material"])
	var unwrap_error := mesh.lightmap_unwrap(Transform3D.IDENTITY, LIGHTMAP_TEXEL_SIZE)
	if unwrap_error != OK:
		printerr("UV2 unwrap failed for ", key, ": ", unwrap_error)
		return null
	return mesh

func _casts_shadow(node_name: String) -> bool:
	return node_name.begins_with("Wall_") or node_name.begins_with("duv") or node_name.begins_with("yan") or node_name.begins_with("Extrude") or node_name.begins_with("S_Nordic_Forest_Cliff") or node_name.begins_with("S_Massive_Nordic") or node_name.begins_with("S_Pruned_Tree")

func _safe_name(value: String) -> String:
	return value.to_lower().replace(" ", "_").replace("/", "_").replace(":", "_")

func _copy_lights(source: Node3D, light_root: Node3D, owner: Node) -> void:
	for node in source.find_children("*", "OmniLight3D", true, false):
		var old := node as OmniLight3D
		var light := OmniLight3D.new()
		light.name = str(old.name)
		light_root.add_child(light)
		light.owner = owner
		light.transform = old.global_transform
		light.light_color = old.light_color
		light.light_energy = old.light_energy
		light.omni_range = old.omni_range
		light.omni_attenuation = old.omni_attenuation
		light.shadow_enabled = false
		light.light_bake_mode = Light3D.BAKE_DYNAMIC

func _collect_collision(mesh_instance: MeshInstance3D, cell: Vector2i) -> void:
	var name := str(mesh_instance.name)
	if not (name.begins_with("Floor_") or name.begins_with("Wall_") or name.begins_with("duv") or name.begins_with("yan") or name.begins_with("S_Mossy_Stone_Wall") or name.begins_with("S_Japanese_Bridge_Railing") or name.begins_with("S_Wooden_Bollard")):
		return
	var world_position := mesh_instance.global_position
	if name.begins_with("S_Japanese_Bridge_Railing"):
		var rounded_position := Vector3(snappedf(world_position.x, 0.05), snappedf(world_position.y, 0.05), snappedf(world_position.z, 0.05))
		var dedupe_key := str(rounded_position)
		if collision_seen_positions.has(dedupe_key):
			return
		collision_seen_positions[dedupe_key] = true
	var house_index := _house_index_for(mesh_instance.global_position) if (name.begins_with("Floor_") or name.begins_with("Wall_") or name.begins_with("duv") or name.begins_with("yan")) else -1
	if name == "Wall_400x244" and house_index == 3:
		# This angled upper panel's bounding box reaches down through the real doorway.
		# Keep its imported visual, but omit its imprecise box from house collision.
		return
	var key := "house_%d" % house_index if house_index >= 0 else "world_%d_%d" % [cell.x, cell.y]
	if not collision_groups.has(key):
		collision_groups[key] = []
	(collision_groups[key] as Array).append(mesh_instance)

func _house_index_for(point: Vector3) -> int:
	var best_index := -1
	var best_distance := 100.0
	for index in range(HOUSE_CENTERS.size()):
		var distance := Vector2(point.x, point.z).distance_squared_to(HOUSE_CENTERS[index])
		if distance < best_distance:
			best_index = index
			best_distance = distance
	return best_index

func _write_collision(scene_root: Node3D) -> int:
	var count := 0
	for key: String in collision_groups:
		var sources: Array = collision_groups[key]
		if sources.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = "Collision_" + key
		scene_root.add_child(body)
		body.owner = scene_root
		for index in range(sources.size()):
			var source := sources[index] as MeshInstance3D
			if source == null or source.mesh == null:
				continue
			var bounds := source.mesh.get_aabb()
			var source_transform := source.global_transform
			var scale := source_transform.basis.get_scale().abs()
			var box_size := bounds.size * scale
			box_size.x = maxf(box_size.x, 0.08)
			box_size.y = maxf(box_size.y, 0.08)
			box_size.z = maxf(box_size.z, 0.08)
			var wall_center := source_transform * bounds.get_center()
			if _is_player_house_door_wall(key, wall_center, box_size):
				_add_doorway_collision(body, scene_root, source_transform.basis.orthonormalized(), wall_center, box_size)
				continue
			var box := BoxShape3D.new()
			box.size = box_size
			var collision := CollisionShape3D.new()
			collision.name = "Box_%03d" % index
			collision.shape = box
			collision.position = wall_center
			collision.basis = source_transform.basis.orthonormalized()
			body.add_child(collision)
			collision.owner = scene_root
			collision_shape_count += 1
		count += 1
	return count

func _is_player_house_door_wall(key: String, center: Vector3, size: Vector3) -> bool:
	return key == "house_3" \
		and center.distance_to(PLAYER_HOUSE_DOOR_CENTER) < 0.35 \
		and size.x < 0.3 \
		and size.y > 1.8 \
		and size.z > 7.5

func _add_doorway_collision(body: StaticBody3D, scene_root: Node3D, wall_basis: Basis, wall_center: Vector3, wall_size: Vector3) -> void:
	var side_length := (wall_size.z - PLAYER_HOUSE_DOOR_WIDTH) * 0.5
	var side_offset := (PLAYER_HOUSE_DOOR_WIDTH + side_length) * 0.5
	_add_collision_box(body, scene_root, "Box_005_DoorLeft", Vector3(wall_size.x, wall_size.y, side_length), Transform3D(wall_basis, wall_center + wall_basis * Vector3(0.0, 0.0, -side_offset)))
	_add_collision_box(body, scene_root, "Box_005_DoorRight", Vector3(wall_size.x, wall_size.y, side_length), Transform3D(wall_basis, wall_center + wall_basis * Vector3(0.0, 0.0, side_offset)))
	_add_collision_box(body, scene_root, "Box_005_DoorLintel", Vector3(wall_size.x, 0.1, PLAYER_HOUSE_DOOR_WIDTH), Transform3D(wall_basis, wall_center + wall_basis * Vector3(0.0, wall_size.y * 0.475, 0.0)))

func _add_collision_box(body: StaticBody3D, scene_root: Node3D, node_name: String, size: Vector3, collision_transform: Transform3D) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = box
	collision.transform = collision_transform
	body.add_child(collision)
	collision.owner = scene_root
	collision_shape_count += 1

func _set_owner(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_set_owner(child, scene_owner)
