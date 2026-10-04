extends RefCounted
class_name AssetTownBuilder
## Fixed authoring pass: combines transformed GLB surfaces into spatial ArrayMeshes
## with unique UV2 charts. MultiMesh is deliberately excluded from lightmap GI.

const CELL_SIZE := 20.0
const LIGHTMAP_TEXEL_SIZE := 0.30
const ATLAS := preload("res://assets/environment/slavic_town/materials/slavic_atlas.tres")
const PLASTER := preload("res://assets/environment/slavic_town/materials/slavic_plaster.tres")
const WOOD := preload("res://assets/environment/slavic_town/materials/slavic_wood.tres")
const ROOF := preload("res://assets/environment/slavic_town/materials/slavic_roof.tres")
const STONE := preload("res://assets/environment/slavic_town/materials/slavic_stone.tres")

var geometry: Node3D
var collision: StaticBody3D
var sources: Dictionary = {}
var placements: Array[Dictionary] = []
var instance_count := 0
var batch_count := 0
var vertex_count := 0
var lightmap_vertex_count := 0
var _packed: Dictionary = {}
var _chunks: Dictionary = {}


func _init(parent: Node3D = null) -> void:
	if parent == null:
		return
	geometry = Node3D.new()
	geometry.name = "SlavicTown"
	parent.add_child(geometry)
	collision = StaticBody3D.new()
	collision.name = "AssetCollision"
	parent.add_child(collision)


func restore_baked_metrics(parent: Node3D) -> void:
	geometry = parent.get_node_or_null("SlavicTown") as Node3D
	collision = parent.get_node_or_null("AssetCollision") as StaticBody3D
	var selection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/town_asset_selection.json"))
	for path: String in selection.get("used_glbs", []):
		sources[path] = true
	instance_count = int(selection.get("asset_mesh_instances", 0))
	vertex_count = int(selection.get("submitted_asset_vertices", 0))
	batch_count = geometry.get_child_count() if geometry != null else 0
	lightmap_vertex_count = int(selection.get("lightmap_uv2_vertices", vertex_count))


func place(path: String, position: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE, tint: Color = Color.WHITE) -> void:
	if not _packed.has(path):
		_packed[path] = load(path) as PackedScene
	var packed: PackedScene = _packed[path]
	assert(packed != null, "Missing town prefab: " + path)
	var instance := packed.instantiate() as Node3D
	var transform := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), position)
	placements.append({"path": path, "transform": transform})
	_collect(instance, transform, tint, path)
	instance.free()


func box_collision(position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = position
	node.rotation = rotation
	collision.add_child(node)


func flush() -> void:
	for key: String in _chunks:
		var entry: Dictionary = _chunks[key]
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
		assert(unwrap_error == OK, "Unable to generate lightmap UV2 for " + key + ": " + str(unwrap_error))
		var instance := MeshInstance3D.new()
		instance.name = "BakeChunk_" + key
		instance.mesh = mesh
		var cell: Vector2i = entry["cell"]
		instance.position = Vector3(float(cell.x) * CELL_SIZE, 0.0, float(cell.y) * CELL_SIZE)
		instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if entry["casts_shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.lod_bias = 0.8
		geometry.add_child(instance)
		batch_count += 1
		lightmap_vertex_count += mesh.surface_get_array_len(0)
	_chunks.clear()


func _collect(node: Node, parent_transform: Transform3D, tint: Color, placement_path: String) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= (node as Node3D).transform
	if node.scene_file_path.ends_with(".glb"):
		sources[node.scene_file_path] = true
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		assert(mesh != null, "Missing imported mesh")
		instance_count += 1
		for surface in range(mesh.get_surface_count()):
			vertex_count += mesh.surface_get_array_len(surface)
			var asset_path: String = node.scene_file_path if node.scene_file_path.ends_with(".glb") else placement_path
			_append_surface(mesh, surface, transform, tint, asset_path)
	elif node is CollisionShape3D and not (node as CollisionShape3D).disabled:
		var original := node as CollisionShape3D
		var copied := CollisionShape3D.new()
		copied.name = "Authored_" + str(collision.get_child_count())
		copied.shape = original.shape
		copied.transform = transform
		collision.add_child(copied)
	for child: Node in node.get_children():
		_collect(child, transform, tint, placement_path)


func _append_surface(mesh: Mesh, surface: int, transform: Transform3D, tint: Color, path: String) -> void:
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var source_colors := PackedColorArray()
	if arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		source_colors = arrays[Mesh.ARRAY_COLOR]
	var source_indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		source_indices = arrays[Mesh.ARRAY_INDEX]
	var origin := transform * Vector3.ZERO
	var cell := Vector2i(floori(origin.x / CELL_SIZE), floori(origin.z / CELL_SIZE))
	var casts_shadow := _casts_shadow(path)
	var material := _material_for_source(path)
	var key := "%d_%d_%d_%s" % [cell.x, cell.y, int(casts_shadow), material.resource_name.to_lower().replace(" ", "_")]
	if not _chunks.has(key):
		_chunks[key] = {
			"cell": cell,
			"casts_shadow": casts_shadow,
			"material": material,
			"vertices": PackedVector3Array(),
			"normals": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"colors": PackedColorArray(),
			"indices": PackedInt32Array(),
		}
	var chunk: Dictionary = _chunks[key]
	var cell_origin := Vector3(float(cell.x) * CELL_SIZE, 0.0, float(cell.y) * CELL_SIZE)
	var vertex_offset: int = chunk["vertices"].size()
	var normal_transform := transform.basis.inverse().transposed()
	var baked_vertices: PackedVector3Array = chunk["vertices"]
	var baked_normals: PackedVector3Array = chunk["normals"]
	var baked_uv: PackedVector2Array = chunk["uv"]
	var baked_colors: PackedColorArray = chunk["colors"]
	for index in range(vertices.size()):
		baked_vertices.append(transform * vertices[index] - cell_origin)
		baked_normals.append((normal_transform * normals[index]).normalized())
		baked_uv.append(uvs[index])
		var color := source_colors[index] if source_colors.size() == vertices.size() else Color.WHITE
		baked_colors.append(color * tint)
	var baked_indices: PackedInt32Array = chunk["indices"]
	if source_indices.is_empty():
		for index in range(vertices.size()):
			baked_indices.append(vertex_offset + index)
	else:
		for index in source_indices:
			baked_indices.append(vertex_offset + index)
	chunk["vertices"] = baked_vertices
	chunk["normals"] = baked_normals
	chunk["uv"] = baked_uv
	chunk["colors"] = baked_colors
	chunk["indices"] = baked_indices


func _casts_shadow(path: String) -> bool:
	var source := path.get_file().to_lower()
	return source.contains("house_") or source.contains("well.tscn") or source.contains("watch_tower") or source.contains("fence_segment") or source.contains("village_hut") or source.contains("village_tover") or source.contains("village_whell") or source.contains("fence_wall") or source.contains("fence_cobble") or source.contains("village_outbuilding")


func _material_for_source(path: String) -> StandardMaterial3D:
	var source := path.get_file().to_lower()
	if source.contains("road_cobble") or source.contains("fence_cobble") or source.contains("whell") or source.contains("envrock"):
		return STONE
	if source.contains("hut_roof") or source.contains("roof_cut"):
		return ROOF
	if source.contains("hut_wall_front") or source.contains("hut_wall_painted"):
		return PLASTER
	if source.contains("barrel") or source.contains("container_crate") or source.contains("container_bag") or source.contains("firewood") or source.contains("tabble") or source.contains("bench") or source.contains("fence_wall") or source.contains("house_mug"):
		return WOOD
	return ATLAS
