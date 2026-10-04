extends RefCounted
class_name TownGeometry

var geometry: Node3D
var props: Node3D
var colliders: StaticBody3D
var _batches: Dictionary = {}
var _meshes: Dictionary = {}
var instance_count := 0
var batch_count := 0

func _init(parent: Node3D = null) -> void:
	if parent == null:
		return
	geometry = Node3D.new()
	geometry.name = "TownGeometry"
	parent.add_child(geometry)
	props = Node3D.new()
	props.name = "Props"
	parent.add_child(props)
	colliders = StaticBody3D.new()
	colliders.name = "TownCollision"
	parent.add_child(colliders)

func box(position: Vector3, dimensions: Vector3, material_id: String, collision: bool = false, yaw: float = 0.0, tint: Color = Color.WHITE) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(dimensions)
	_add("box", material_id, Transform3D(basis, position), tint)
	if collision:
		var shape := BoxShape3D.new()
		shape.size = dimensions
		var node := CollisionShape3D.new()
		node.shape = shape
		node.position = position
		node.rotation.y = yaw
		colliders.add_child(node)

func cylinder(position: Vector3, diameter: float, height: float, material_id: String, collision: bool = false) -> void:
	_add("cylinder", material_id, Transform3D(Basis.IDENTITY.scaled(Vector3(diameter, height, diameter)), position))
	if collision:
		var shape := CylinderShape3D.new()
		shape.radius = diameter * 0.5
		shape.height = height
		var node := CollisionShape3D.new()
		node.shape = shape
		node.position = position
		colliders.add_child(node)

func sphere(position: Vector3, dimensions: Vector3, material_id: String) -> void:
	_add("sphere", material_id, Transform3D(Basis.IDENTITY.scaled(dimensions), position))

func beam(start: Vector3, end: Vector3, thickness: float, material_id: String = "wood") -> void:
	var direction := end - start
	var basis := Basis(Quaternion(Vector3.UP, direction.normalized())) * Basis.from_scale(Vector3(thickness, direction.length(), thickness))
	_add("box", material_id, Transform3D(basis, (start + end) * 0.5))

func roof(position: Vector3, dimensions: Vector3, material_id: String, yaw: float = 0.0) -> void:
	_add("roof", material_id, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(dimensions), position))

func flush() -> void:
	for key: String in _batches:
		var entries: Array = _batches[key]
		var parts := key.split(":")
		var mesh := _mesh(parts[0])
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = entries.size()
		for index in range(entries.size()):
			multi.set_instance_transform(index, entries[index]["transform"])
			multi.set_instance_color(index, entries[index]["color"])
		var node := MultiMeshInstance3D.new()
		node.name = parts[0] + "_" + parts[1]
		node.multimesh = multi
		node.material_override = WorldVisualConfig.material(parts[1])
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		props.add_child(node)
		batch_count += 1
	_batches.clear()

func _add(kind: String, material_id: String, transform: Transform3D, tint: Color = Color.WHITE) -> void:
	var key := kind + ":" + material_id
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append({"transform": transform, "color": tint})
	instance_count += 1

func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		"box":
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3.ONE
			mesh = box_mesh
		"cylinder":
			var cylinder_mesh := CylinderMesh.new()
			cylinder_mesh.height = 1.0
			cylinder_mesh.top_radius = 0.5
			cylinder_mesh.bottom_radius = 0.5
			cylinder_mesh.radial_segments = 12
			cylinder_mesh.rings = 1
			mesh = cylinder_mesh
		"sphere":
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = 0.5
			sphere_mesh.height = 1.0
			sphere_mesh.radial_segments = 12
			sphere_mesh.rings = 6
			mesh = sphere_mesh
		"roof":
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var a := Vector3(-0.5, 0, -0.5)
			var b := Vector3(0.5, 0, -0.5)
			var c := Vector3(0, 1, -0.5)
			var d := Vector3(-0.5, 0, 0.5)
			var e := Vector3(0.5, 0, 0.5)
			var f := Vector3(0, 1, 0.5)
			var vertices: Array[Vector3] = [a, c, b, d, e, f, a, d, f, a, f, c, b, c, f, b, f, e, a, b, e, a, e, d]
			# Godot front faces use clockwise winding.
			for triangle in range(0, vertices.size(), 3):
				surface.add_vertex(vertices[triangle])
				surface.add_vertex(vertices[triangle + 2])
				surface.add_vertex(vertices[triangle + 1])
			surface.generate_normals()
			mesh = surface.commit()
	_meshes[kind] = mesh
	return mesh
