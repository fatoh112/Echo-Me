extends Node3D
class_name Neighborhood

var _materials: Dictionary = {}


func build(locations: Dictionary) -> void:
	_build_lighting()
	_box("Ground", Vector3(0, -0.15, 0), Vector3(64, 0.3, 64), Color(0.40, 0.42, 0.43))
	_box("Street", Vector3(0, 0.015, -3), Vector3(5, 0.03, 46), Color(0.24, 0.25, 0.27), false)
	_box("SpawnPad", Vector3(0, 0.025, 8), Vector3(5, 0.05, 5), Color(0.3, 0.4, 0.48), false)
	_box("ShopBuilding", Vector3(-10, 2, -11), Vector3(8, 4, 6), Color(0.54, 0.50, 0.43))
	_box("ShopCounter", Vector3(-10, 0.5, -7), Vector3(6, 1, 1), Color(0.45, 0.37, 0.27))
	_box("CafeBuilding", Vector3(10, 1.75, -11), Vector3(8, 3.5, 5), Color(0.53, 0.43, 0.43))
	_box("CafePatio", Vector3(10, 0.015, -5), Vector3(10, 0.03, 7), Color(0.54, 0.51, 0.48), false)
	for table_x in [6.5, 13.5]:
		_box("CafeTable", Vector3(table_x, 0.7, -4), Vector3(1.5, 1.4, 1.5), Color(0.42, 0.33, 0.27))
	_box("Park", Vector3(-10, 0.02, 9), Vector3(12, 0.04, 10), Color(0.34, 0.43, 0.34), false)
	_box("ParkBench", Vector3(-14, 0.4, 10), Vector3(1, 0.8, 3), Color(0.43, 0.35, 0.28))
	for tree_position: Vector3 in [Vector3(-15, 0, 5), Vector3(-5, 0, 13)]:
		_box("TreeTrunk", tree_position + Vector3(0, 1, 0), Vector3(0.5, 2, 0.5), Color(0.4, 0.3, 0.22))
		_box("TreeCrown", tree_position + Vector3(0, 2.6, 0), Vector3(2, 1.6, 2), Color(0.27, 0.38, 0.29), false)
	_box("Apartments", Vector3(10, 2.5, 17), Vector3(10, 5, 6), Color(0.48, 0.49, 0.53))
	_box("ApartmentDoor", Vector3(10, 1.2, 13.98), Vector3(2, 2.4, 0.04), Color(0.25, 0.27, 0.29), false)
	_box("AlleyWest", Vector3(-4.8, 2, -21), Vector3(3, 4, 9), Color(0.43, 0.43, 0.46))
	_box("AlleyEast", Vector3(4.8, 2, -21), Vector3(3, 4, 9), Color(0.43, 0.43, 0.46))
	for wall_position: Vector3 in [Vector3(-31, 0.6, 0), Vector3(31, 0.6, 0)]:
		_box("Boundary", wall_position, Vector3(0.5, 1.2, 64), Color(0.3, 0.32, 0.34))
	for wall_position: Vector3 in [Vector3(0, 0.6, -31), Vector3(0, 0.6, 31)]:
		_box("Boundary", wall_position, Vector3(64, 1.2, 0.5), Color(0.3, 0.32, 0.34))
	for location_id: String in locations:
		var location := DataUtils.dictionary(locations[location_id])
		var coordinates: Array = location.get("position", [0, 0, 0])
		var marker := Label3D.new()
		marker.text = str(location.get("display_name", location_id))
		marker.position = Vector3(float(coordinates[0]), 3.2, float(coordinates[2]))
		marker.font_size = 32
		marker.pixel_size = 0.009
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = false
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)


func _box(box_name: String, position_value: Vector3, size_value: Vector3, tint: Color, collision: bool = true) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	mesh_instance.position = position_value
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	var key := tint.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = 1.0
		_materials[key] = material
	mesh_instance.material_override = _materials[key]
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	if collision:
		var body := StaticBody3D.new()
		body.position = position_value
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_value
		collider.shape = shape
		body.add_child(collider)
		add_child(body)


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.16, 0.20)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.82)
	environment.ambient_light_energy = 0.75
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	light.light_energy = 0.8
	light.shadow_enabled = false
	add_child(light)
