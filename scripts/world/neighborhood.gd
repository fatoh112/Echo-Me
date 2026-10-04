extends Node3D
class_name Neighborhood

var builder: TownGeometry
var locations_root: Node3D
var visual_instance_count := 0
var visual_batch_count := 0

func build(locations: Dictionary) -> void:
	_build_lighting()
	builder = TownGeometry.new(self)
	locations_root = Node3D.new()
	locations_root.name = "Locations"
	add_child(locations_root)
	_ground()
	_building(Vector3(-11, 0, -13), Vector3(8, 4.6, 6), 0, "plaster", "roof")
	_building(Vector3(11, 0, -13), Vector3(9, 5.4, 7), 0, "plaster_rose", "roof")
	_building(Vector3(0, 0, 20), Vector3(8, 4.4, 7), PI, "plaster", "roof_slate")
	_building(Vector3(12, 0, 18), Vector3(8, 5, 7), PI, "plaster", "roof")
	_building(Vector3(21, 0, 18), Vector3(7, 4.2, 6), PI, "plaster_rose", "roof_slate")
	_building(Vector3(-12, 0, 20), Vector3(7, 5.3, 7), PI, "plaster_rose", "roof")
	_building(Vector3(-16, 0, 8), Vector3(6, 4.7, 6), PI / 2, "stone", "roof_slate")
	_building(Vector3(-19, 0, 3), Vector3(4, 7.2, 4), 0, "stone", "roof_slate")
	_building(Vector3(-6.5, 0, -22), Vector3(7, 5.8, 9), 0, "plaster", "roof_slate")
	_building(Vector3(6.5, 0, -22), Vector3(7, 4.5, 9), 0, "plaster_rose", "roof")
	for z in [-10.0, 2.0]:
		_building(Vector3(-24, 0, z), Vector3(7, 4.8, 7), PI / 2, "plaster", "roof")
		_building(Vector3(24, 0, z), Vector3(7, 5.2, 7), -PI / 2, "plaster", "roof_slate")
	_market()
	_tavern()
	_square()
	_watch()
	_props()
	for x in [-30.0, 30.0]:
		builder.box(Vector3(x, 1.2, 0), Vector3(0.8, 2.4, 60), "stone", true)
	for z in [-30.0, 30.0]:
		builder.box(Vector3(0, 1.2, z), Vector3(60, 2.4, 0.8), "stone", true)
	for location_id: String in locations:
		var coordinates: Array = locations[location_id]["position"]
		var anchor := Marker3D.new()
		anchor.name = location_id
		anchor.position = Vector3(float(coordinates[0]), 0, float(coordinates[2]))
		locations_root.add_child(anchor)
	_sign("Your Quarters", Vector3(1.6, 3.05, 16.30), PI, 2.2)
	_sign("Town Square", Vector3(-4.2, 2.1, 3.6), 0, 2.2)
	_sign("Alex's Goods", Vector3(-11, 3.0, -9.85), 0, 2.8)
	_sign("The Amber Hearth", Vector3(11, 3.2, -9.35), 0, 3.2)
	_sign("Residential Row", Vector3(12, 2.9, 14.35), PI, 2.8)
	_sign("Back Alley", Vector3(0, 2.6, -16.3), 0, 2.0)
	_sign("Town Watch", Vector3(-12.75, 3.15, 8), PI / 2, 2.2)
	builder.flush()
	visual_instance_count = builder.instance_count
	visual_batch_count = builder.batch_count

func _ground() -> void:
	builder.box(Vector3(0, -0.18, 0), Vector3(60, 0.36, 60), "earth", true)
	var random := RandomNumberGenerator.new()
	random.seed = 401
	for z in range(-28, 29):
		for x in range(-28, 29):
			var paved: bool = abs(x) <= 3 or (abs(x) <= 8 and z >= -10 and z <= 6) or (z >= -8 and z <= -3) or (z >= 6 and z <= 12)
			if not paved:
				continue
			var tint := Color.WHITE * random.randf_range(0.82, 1.12)
			tint.a = 1
			builder.box(Vector3(x + (0.24 if z % 2 else -0.24), 0.006, z), Vector3(0.94, 0.012, 0.91), "paving", false, 0, tint)
	for side in [-1.0, 1.0]:
		builder.box(Vector3(side * 19, 0.1, 16), Vector3(18, 0.2, 0.3), "stone")
		builder.box(Vector3(side * 18, 0.1, -9), Vector3(19, 0.2, 0.3), "stone")

func _building(origin: Vector3, dimensions: Vector3, yaw: float, wall: String, roof_material: String) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var width := dimensions.x
	var height := dimensions.y
	var depth := dimensions.z
	builder.box(origin + Vector3(0, height / 2, 0), dimensions, wall, true, yaw)
	builder.box(origin + Vector3(0, 0.47, 0), Vector3(width + 0.08, 0.94, depth + 0.08), "stone", false, yaw)
	for x in [-width / 2, 0.0, width / 2]:
		for z in [-depth / 2 - 0.05, depth / 2 + 0.05]:
			builder.box(origin + turn * Vector3(x, height / 2, z), Vector3(0.17, height, 0.17), "wood", false, yaw)
	for level in [1.0, height * 0.54, height]:
		for z in [-depth / 2 - 0.09, depth / 2 + 0.09]:
			builder.box(origin + turn * Vector3(0, level, z), Vector3(width + 0.25, 0.17, 0.18), "wood", false, yaw)
	for x in [-width / 2 - 0.07, width / 2 + 0.07]:
		builder.box(origin + turn * Vector3(x, height * 0.54, 0), Vector3(0.16, 0.17, depth), "wood", false, yaw)
	var front := depth / 2 + 0.12
	builder.box(origin + turn * Vector3(0, 1.23, front), Vector3(1.5, 2.46, 0.08), "window", false, yaw)
	builder.box(origin + turn * Vector3(0, 1.12, front + 0.06), Vector3(1.15, 2.24, 0.12), "wood_light", false, yaw)
	for x in [-0.67, 0.67]:
		builder.box(origin + turn * Vector3(x, 1.2, front + 0.05), Vector3(0.2, 2.4, 0.18), "stone", false, yaw)
	for index in range(7):
		var angle := index * PI / 6
		builder.box(origin + turn * Vector3(cos(angle) * 0.67, 2.38 + sin(angle) * 0.4, front + 0.05), Vector3(0.26, 0.26, 0.2), "stone", false, yaw)
	for y in [0.65, 1.75]:
		builder.box(origin + turn * Vector3(0, y, front + 0.14), Vector3(1.08, 0.08, 0.08), "metal", false, yaw)
	builder.sphere(origin + turn * Vector3(0.4, 1.2, front + 0.20), Vector3.ONE * 0.10, "metal")
	for x in [-width * 0.30, width * 0.30]:
		for y in [1.5, height * 0.76]:
			_window(origin, turn, Vector3(x, y, front), yaw)
	for step in range(2):
		builder.box(origin + turn * Vector3(0, 0.05 * (2 - step), front + 0.22 + step * 0.25), Vector3(1.8, 0.1 * (2 - step), 0.45), "stone")
	var roof_height := minf(2.2, width * 0.29)
	builder.roof(origin + Vector3(0, height, 0), Vector3(width + 0.65, roof_height, depth + 0.7), roof_material, yaw)
	for z in [-depth / 2 - 0.38, depth / 2 + 0.38]:
		for side in [-1.0, 1.0]:
			builder.beam(origin + turn * Vector3(side * (width / 2 + 0.35), height, z), origin + turn * Vector3(0, height + roof_height, z), 0.14)
	for index in range(1, 6):
		var factor := index / 6.0
		for side in [-1.0, 1.0]:
			builder.box(origin + turn * Vector3(side * (width / 2 + 0.2) * (1 - factor), height + roof_height * factor + 0.018, 0), Vector3(0.06, 0.04, depth + 0.65), "wood", false, yaw)
	builder.box(origin + turn * Vector3(width * 0.28, height + roof_height, -depth * 0.20), Vector3(0.65, 1.8, 0.65), "stone", false, yaw)
	_lantern(origin + turn * Vector3(-1.4, 2.35, front + 0.4))

func _window(origin: Vector3, turn: Basis, local: Vector3, yaw: float) -> void:
	builder.box(origin + turn * local, Vector3(0.83, 1.05, 0.07), "window", false, yaw)
	for side in [-1.0, 1.0]:
		builder.box(origin + turn * (local + Vector3(side * 0.53, 0, 0.04)), Vector3(0.22, 1.15, 0.08), "wood_light", false, yaw)
	builder.box(origin + turn * (local + Vector3(0, 0, 0.08)), Vector3(0.055, 1.03, 0.06), "wood_light", false, yaw)
	builder.box(origin + turn * (local + Vector3(0, 0, 0.08)), Vector3(0.84, 0.055, 0.06), "wood_light", false, yaw)
	builder.box(origin + turn * (local + Vector3(0, -0.56, 0.03)), Vector3(1.3, 0.15, 0.28), "stone", false, yaw)

func _market() -> void:
	_stall(Vector3(-15.8, 0, -5.5), "cloth_green")
	_stall(Vector3(-7.8, 0, -8.0), "cloth_red")
	for x in [-15.2, -16.1, -16.8]:
		builder.sphere(Vector3(x, 1.1, -5.3), Vector3(0.22, 0.20, 0.22), "cloth_red")
	_crate(Vector3(-13.7, 0, -8.3))
	_crate(Vector3(-14.1, 0.85, -8.3))
	_barrel(Vector3(-9, 0, -8.8))

func _stall(origin: Vector3, cloth: String) -> void:
	builder.box(origin + Vector3(0, 0.8, 0), Vector3(2.5, 0.16, 1.3), "wood_light", true)
	for x in [-1.15, 1.15]:
		for z in [-0.6, 0.6]:
			builder.box(origin + Vector3(x, 1.2, z), Vector3(0.11, 2.4, 0.11), "wood")
	builder.box(origin + Vector3(0, 2.4, 0), Vector3(2.85, 0.08, 1.8), cloth)
	for x in [-1.2, -0.6, 0.0, 0.6, 1.2]:
		builder.box(origin + Vector3(x, 2.23, 0.88), Vector3(0.55, 0.3, 0.05), cloth)
	builder.box(origin + Vector3(0, 0.45, 0.62), Vector3(2.4, 0.65, 0.10), "wood_light")

func _tavern() -> void:
	for point: Vector3 in [Vector3(13, 0, -5), Vector3(15.5, 0, -7)]:
		builder.cylinder(point + Vector3(0, 0.72, 0), 1.3, 0.14, "wood_light", true)
		builder.cylinder(point + Vector3(0, 0.34, 0), 0.24, 0.68, "wood")
		for side in [-1.0, 1.0]:
			builder.cylinder(point + Vector3(side * 1.0, 0.22, 0), 0.48, 0.44, "wood_light", true)
	_barrel(Vector3(7, 0, -8.4))
	_barrel(Vector3(7, 0, -7.3))
	builder.box(Vector3(11, 2.8, -8.4), Vector3(4.2, 0.12, 2.0), "cloth_red")
	for x in [8.95, 13.05]:
		builder.box(Vector3(x, 1.4, -7.5), Vector3(0.13, 2.8, 0.13), "wood")

func _square() -> void:
	var center := Vector3(0, 0, 0.5)
	builder.cylinder(center + Vector3(0, 0.17, 0), 4.0, 0.34, "stone", true)
	builder.cylinder(center + Vector3(0, 0.37, 0), 3.65, 0.20, "water")
	for index in range(12):
		var angle := index * TAU / 12.0
		builder.box(center + Vector3(sin(angle) * 1.87, 0.46, cos(angle) * 1.87), Vector3(0.95, 0.45, 0.26), "stone", false, angle)
	builder.cylinder(center + Vector3(0, 0.91, 0), 0.8, 1.7, "stone")
	builder.cylinder(center + Vector3(0, 1.73, 0), 1.6, 0.24, "stone")
	builder.cylinder(center + Vector3(0, 1.87, 0), 1.3, 0.06, "water")
	builder.sphere(center + Vector3(0, 2.16, 0), Vector3(0.45, 0.60, 0.45), "metal")
	_bench(Vector3(-5.5, 0, 1), PI / 2)
	_bench(Vector3(5.5, 0, 1), -PI / 2)
	_bench(Vector3(0, 0, 5), PI)
	for point: Vector3 in [Vector3(-6.5, 0, 4.5), Vector3(6.5, 0, 4.5)]:
		builder.cylinder(point + Vector3(0, 0.2, 0), 1.0, 0.4, "stone")
		builder.cylinder(point + Vector3(0, 1.5, 0), 0.17, 2.6, "wood")
		builder.sphere(point + Vector3(0, 2.8, 0), Vector3(1.8, 2, 1.8), "foliage")
	_lantern_post(Vector3(-5.5, 0, -6.0))
	_lantern_post(Vector3(5.5, 0, -6.0))

func _watch() -> void:
	builder.box(Vector3(-12.5, 0.4, 12), Vector3(4.5, 0.8, 0.25), "wood", true)
	for x in [-14.5, -12.5, -10.5]:
		builder.box(Vector3(x, 1.0, 12), Vector3(0.17, 2.0, 0.17), "wood")
	_sign("Notice Board", Vector3(-12.5, 1.9, 12.1), 0, 2.0)
	builder.box(Vector3(-12.5, 1.45, 12.19), Vector3(1.1, 0.7, 0.02), "cream")
	_crate(Vector3(-13.1, 0, 4.3))
	_barrel(Vector3(-12.6, 0, 5.2))

func _props() -> void:
	for point: Vector3 in [Vector3(-2.5, 0, -24), Vector3(2.3, 0, -25), Vector3(17, 0, 12), Vector3(-7, 0, 17)]:
		_barrel(point)
	for point: Vector3 in [Vector3(2.4, 0, -20), Vector3(2.4, 0, -21), Vector3(-3.8, 0, 15), Vector3(18, 0, 12)]:
		_crate(point)
	_lantern_post(Vector3(3.2, 0, 12))
	_lantern_post(Vector3(-2.4, 0, -17))
	for point: Vector3 in [Vector3(-8.5, 0, 14), Vector3(16.6, 0, 13.6), Vector3(-20.0, 0, -5)]:
		builder.cylinder(point + Vector3(0, 0.18, 0), 0.65, 0.36, "roof")
		builder.sphere(point + Vector3(0, 0.50, 0), Vector3(0.7, 0.5, 0.7), "foliage")

func _barrel(origin: Vector3) -> void:
	builder.cylinder(origin + Vector3(0, 0.52, 0), 0.76, 1.04, "wood_light", true)
	for y in [0.15, 0.85]:
		builder.cylinder(origin + Vector3(0, y, 0), 0.80, 0.07, "metal")

func _crate(origin: Vector3) -> void:
	builder.box(origin + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), "wood_light", true)
	for side in [-0.42, 0.42]:
		builder.beam(origin + Vector3(-0.36, 0.06, side), origin + Vector3(0.36, 0.74, side), 0.085)
		for y in [0.1, 0.7]:
			builder.box(origin + Vector3(0, y, side), Vector3(0.84, 0.12, 0.08), "wood")

func _bench(origin: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	builder.box(origin + Vector3(0, 0.5, 0), Vector3(2.4, 0.15, 0.6), "wood_light", true, yaw)
	builder.box(origin + turn * Vector3(0, 0.9, 0.3), Vector3(2.4, 0.5, 0.10), "wood_light", false, yaw)
	for x in [-0.95, 0.95]:
		builder.box(origin + turn * Vector3(x, 0.22, 0), Vector3(0.18, 0.44, 0.5), "wood", false, yaw)

func _lantern(origin: Vector3) -> void:
	builder.box(origin, Vector3(0.23, 0.35, 0.23), "glow")
	builder.box(origin + Vector3(0, 0.22, 0), Vector3(0.33, 0.10, 0.33), "metal")
	builder.box(origin + Vector3(0, -0.22, 0), Vector3(0.31, 0.07, 0.31), "metal")
	for x in [-0.14, 0.14]:
		builder.box(origin + Vector3(x, 0, 0), Vector3(0.035, 0.4, 0.3), "metal")

func _lantern_post(origin: Vector3) -> void:
	builder.box(origin + Vector3(0, 1.4, 0), Vector3(0.12, 2.8, 0.12), "wood")
	builder.box(origin + Vector3(0.28, 2.6, 0), Vector3(0.65, 0.11, 0.11), "metal")
	_lantern(origin + Vector3(0.52, 2.32, 0))

func _sign(text: String, position_value: Vector3, yaw: float, width: float) -> void:
	builder.box(position_value, Vector3(width, 0.56, 0.12), "wood", false, yaw)
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	var text_width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
	label.pixel_size = minf(0.010, (width - 0.16) / maxf(text_width, 1.0))
	label.position = position_value + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.075)
	label.rotation.y = yaw
	label.modulate = WorldVisualConfig.PALETTE["cream"]
	label.outline_size = 2
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	locations_root.add_child(label)

func _build_lighting() -> void:
	var holder := Node3D.new()
	holder.name = "Environment"
	add_child(holder)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.29, 0.40, 0.53)
	sky_material.sky_horizon_color = Color(0.88, 0.62, 0.40)
	sky_material.ground_horizon_color = Color(0.78, 0.56, 0.39)
	sky_material.ground_bottom_color = Color(0.20, 0.19, 0.23)
	sky_material.sun_angle_max = 8.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = WorldVisualConfig.AMBIENT_COLOR
	environment.ambient_light_energy = WorldVisualConfig.AMBIENT_ENERGY
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	holder.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sunset"
	sun.rotation_degrees = Vector3(-24, -38, 0)
	sun.light_color = WorldVisualConfig.SUN_COLOR
	sun.light_energy = WorldVisualConfig.SUN_ENERGY
	sun.shadow_enabled = false
	holder.add_child(sun)
	for point: Vector3 in [Vector3(-11, 2.8, -8), Vector3(11, 2.8, -8)]:
		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.light_color = WorldVisualConfig.SUN_COLOR
		lamp.light_energy = 0.5
		lamp.omni_range = 4
		lamp.shadow_enabled = false
		holder.add_child(lamp)
