extends RefCounted
class_name AssetTownBuilder
## Fixed authored placement only. PackedScene resources provide meshes and simple
## collision; one MultiMesh per shared mesh removes decorative node overhead.
var geometry: Node3D
var collision: StaticBody3D
var sources: Dictionary = {}
var placements: Array[Dictionary] = []
var instance_count := 0
var batch_count := 0
var vertex_count := 0
var _packed: Dictionary = {}
var _batches: Dictionary = {}

func _init(parent: Node3D) -> void:
	geometry = Node3D.new()
	geometry.name = "SlavicTown"
	parent.add_child(geometry)
	collision = StaticBody3D.new()
	collision.name = "AssetCollision"
	parent.add_child(collision)

func place(path: String, position: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE, tint: Color = Color.WHITE) -> void:
	if not _packed.has(path):
		_packed[path] = load(path) as PackedScene
	var packed: PackedScene = _packed[path]
	assert(packed != null, "Missing town prefab: " + path)
	var instance := packed.instantiate() as Node3D
	var transform := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), position)
	placements.append({"path": path, "transform": transform})
	_collect(instance, transform, tint)
	instance.free()

func box_collision(position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = position
	node.rotation = rotation
	collision.add_child(node)

func _collect(node: Node, parent_transform: Transform3D, tint: Color) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= (node as Node3D).transform
	if node.scene_file_path.ends_with(".glb"):
		sources[node.scene_file_path] = true
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		assert(mesh != null, "Missing imported mesh")
		var key := mesh.get_rid().get_id()
		if not _batches.has(key):
			_batches[key] = {"mesh": mesh, "entries": []}
		_batches[key]["entries"].append({"transform": transform, "tint": tint})
		instance_count += 1
		for surface in range(mesh.get_surface_count()):
			vertex_count += mesh.surface_get_array_len(surface)
	elif node is CollisionShape3D and not (node as CollisionShape3D).disabled:
		var original := node as CollisionShape3D
		var copied := CollisionShape3D.new()
		copied.shape = original.shape
		copied.transform = transform
		collision.add_child(copied)
	for child in node.get_children():
		_collect(child, transform, tint)

func flush() -> void:
	for batch: Dictionary in _batches.values():
		var mesh: Mesh = batch["mesh"]
		var entries: Array = batch["entries"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = entries.size()
		for index in range(entries.size()):
			multi.set_instance_transform(index, entries[index]["transform"])
			multi.set_instance_color(index, entries[index]["tint"])
		var visible := MultiMeshInstance3D.new()
		visible.name = "AssetBatch" + str(batch_count)
		visible.multimesh = multi
		visible.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visible.lod_bias = 0.8
		geometry.add_child(visible)
		batch_count += 1
	_batches.clear()
