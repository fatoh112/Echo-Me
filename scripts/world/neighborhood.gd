extends Node3D
class_name Neighborhood

const PACK := "res://assets/environment/slavic_town/glb/glTF/"
const PREFABS := "res://scenes/environment/"
var builder: TownGeometry
var assets: AssetTownBuilder
var locations_root: Node3D
var visual_instance_count := 0
var visual_batch_count := 0
var baked_chunk_count := 0
var bakeable_vertex_count := 0

func build(locations: Dictionary) -> void:
	if has_node("LightmapGI") and has_node("SlavicTown"):
		_restore_baked_town()
		return
	_build_lightmap()
	_build_lighting()
	# Tiny bespoke signs/lanterns share the NPC palette. All major town visuals
	# are imported pack meshes. No old blockout building or paving is generated.
	builder = TownGeometry.new(self)
	assets = AssetTownBuilder.new(self)
	locations_root = Node3D.new()
	locations_root.name = "Locations"
	add_child(locations_root)
	_ground()
	_architecture()
	_square()
	_merchant()
	_tavern()
	_residential()
	_alley()
	_watch()
	_boundary()
	for location_id: String in locations:
		var coordinates: Array = locations[location_id]["position"]
		var anchor := Marker3D.new()
		anchor.name = location_id
		anchor.position = Vector3(float(coordinates[0]), 0, float(coordinates[2]))
		locations_root.add_child(anchor)
	_sign("Your Quarters", Vector3(-2.1, 2.66, 16.48), PI, 2.2)
	_sign("Town Square", Vector3(-4.8, 1.76, 3.6), 0, 2.2)
	_sign("Alex's Goods", Vector3(-8.2, 2.8, -9.63), 0, 2.4)
	_sign("The Amber Hearth", Vector3(13.1, 3.65, -9.68), 0, 3.2)
	_sign("Residential Row", Vector3(13.5, 2.72, 16.42), PI, 2.8)
	_sign("Back Alley", Vector3(-2.2, 2.65, -13.7), 0, 1.7)
	_sign("Town Watch", Vector3(-13.49, 2.65, 8), PI / 2, 2.2)
	assets.flush()
	builder.flush()
	visual_instance_count = assets.instance_count + builder.instance_count
	visual_batch_count = assets.batch_count + builder.batch_count + 1
	baked_chunk_count = assets.batch_count
	bakeable_vertex_count = assets.lightmap_vertex_count

func _restore_baked_town() -> void:
	var low_quality := "--echo-low-graphics" in OS.get_cmdline_user_args()
	var environment := (get_node("LightmapGI/Environment/WorldEnvironment") as WorldEnvironment).environment
	WorldVisualConfig.tune_environment(environment, low_quality)
	var sun := get_node("LightmapGI/Environment/Sunset") as DirectionalLight3D
	sun.shadow_enabled = not low_quality
	for probe: ReflectionProbe in find_children("*", "ReflectionProbe", true, false):
		probe.visible = not low_quality
	assets = AssetTownBuilder.new()
	assets.restore_baked_metrics(self)
	builder = TownGeometry.new()
	builder.geometry = get_node("TownGeometry")
	builder.props = get_node("Props")
	builder.colliders = get_node("TownCollision")
	var selection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/town_asset_selection.json"))
	builder.instance_count = int(selection.get("small_primitive_instances", 0))
	builder.batch_count = builder.props.get_child_count()
	locations_root = get_node("Locations")
	visual_instance_count = assets.instance_count + builder.instance_count
	visual_batch_count = assets.batch_count + builder.batch_count + 1
	baked_chunk_count = assets.batch_count
	bakeable_vertex_count = assets.lightmap_vertex_count


func _build_lightmap() -> void:
	var lightmap := LightmapGI.new()
	lightmap.name = "LightmapGI"
	lightmap.directional = false
	lightmap.bounces = 3
	lightmap.bounce_indirect_energy = 0.85
	lightmap.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_16
	lightmap.texel_scale = 1.0
	lightmap.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	lightmap.max_texture_size = 8192
	lightmap.use_texture_for_bounces = true
	lightmap.use_denoiser = true
	lightmap.shadowmask_mode = 1 # SHADOWMASK_MODE_REPLACE
	lightmap.environment_mode = LightmapGI.ENVIRONMENT_MODE_SCENE
	lightmap.light_data = LightmapGIData.new()
	add_child(lightmap)

func _ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "DirtGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(180, 180)
	plane.add_uv2 = true
	ground.mesh = plane
	ground.material_override = preload("res://assets/environment/slavic_town/materials/town_ground.tres")
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(ground)
	assets.box_collision(Vector3(0, -0.18, 0), Vector3(60, 0.36, 60))
	# Flatten only the road's vertical relief to about 1 cm. Physics remains
	# perfectly level; the unmodified controller never has to climb cobbles.
	for z in [14.8, 12.5, 10.2, 7.9]:
		for x in [-0.9, 0.0, 0.9]:
			_road(Vector3(x, 0.003, z), PI / 2)
	for z in [5.6, 3.3, 1.0, -1.3, -3.6, -5.9]:
		for x in [3.1, 4.0, 4.9]:
			_road(Vector3(x, 0.003, z), PI / 2)
	for z in [-8.5, -10.8, -13.1, -15.4, -17.7, -20.0, -22.3, -24.6, -26.9]:
		for x in [-0.9, 0.0, 0.9]:
			_road(Vector3(x, 0.003, z), PI / 2)
	for z in [-6.1, 8.6]:
		for x in [-16.1, -13.8, -11.5, -9.2, -6.9, -4.6, -2.3, 0.0, 2.3, 4.6, 6.9, 9.2, 11.5, 13.8, 16.1, 18.4, 20.7]:
			for offset in [-0.45, 0.45]:
				_road(Vector3(x, 0.003, z + offset))
	var random := RandomNumberGenerator.new()
	random.seed = 401
	# Extend the intentional stone apron around the covered well. Broken placement,
	# small rotations and restrained value variation soften the old 11x11 tile grid.
	for row in range(16):
		for column in range(19):
			var point := Vector3(-9.0 + column * 1.0, 0.004, -7.2 + row * 0.96)
			point.x += random.randf_range(-0.16, 0.16)
			point.z += random.randf_range(-0.16, 0.16)
			var tile_scale := random.randf_range(0.42, 0.50)
			var value := random.randf_range(0.93, 1.07)
			var tile_tint := Color(0.63, 0.60, 0.55) * value
			_model("EA03_Environment_Road_Cobble_01b", point, random.randf_range(-0.45, 0.45), Vector3(tile_scale, 0.026, tile_scale), tile_tint)

func _road(point: Vector3, yaw: float = 0.0) -> void:
	_model("EA03_Environment_Road_Cobble_01a", point, yaw, Vector3(0.46, 0.025, 0.53), Color(0.63, 0.59, 0.53))

func _architecture() -> void:
	_prefab("house_merchant", Vector3(-11, 0, -15))
	_prefab("house_inn", Vector3(11, 0, -15), 0, Color(1.0, 0.88, 0.76))
	_prefab("house_cottage", Vector3(0, 0, 21), PI)
	_prefab("house_cottage", Vector3(12, 0, 21), PI, Color(0.88, 0.97, 0.88))
	_prefab("house_inn", Vector3(22, 0, 22), PI, Color(0.85, 0.91, 1.0))
	_prefab("house_merchant", Vector3(-12, 0, 22), PI, Color(0.90, 0.82, 0.70))
	_prefab("house_cottage", Vector3(-24, 0, -13), PI / 2)
	_prefab("house_inn", Vector3(24, 0, -9), -PI / 2, Color(0.9, 0.88, 0.82))
	_prefab("house_cottage", Vector3(-24, 0, -1), PI / 2, Color(0.92, 0.86, 0.8))
	_prefab("house_cottage", Vector3(24, 0, 3), -PI / 2)
	# Rear houses frame the alley without taking its four-meter walk corridor.
	_prefab("house_cottage", Vector3(-7.3, 0, -25), PI / 2, Color(0.72, 0.78, 0.85))
	_prefab("house_merchant", Vector3(7.5, 0, -25), -PI / 2, Color(0.80, 0.76, 0.67))
	for point: Vector3 in [Vector3(2.7, 2.3, 16.35), Vector3(13.8, 2.3, 16.35), Vector3(-8.1, 2.3, -9.5), Vector3(13.8, 2.3, -9.45)]:
		_lantern(point)

func _square() -> void:
	_prefab("well", Vector3(-0.25, 0, 0.5), 0.10)
	_prefab("bench", Vector3(-5.4, 0, 1.4), PI / 2)
	_prefab("bench", Vector3(6.7, 0, 0.3), -PI / 2)
	_prefab("bench", Vector3(-2.6, 0, 5.2), PI)
	_lantern_post(Vector3(-4.8, 0, 3.6))
	_lantern_post(Vector3(6.1, 0, -4.1))
	_tree(Vector3(-7.0, 0, 3.3), 0.56, "EA03_Nature_Tree_01b")
	_tree(Vector3(8.5, 0, 3.5), 0.55, "EA03_Nature_Tree_02c")
	_model("EA03_Nature_Bush_01a", Vector3(-7.5, 0, 4.0), 0.4, Vector3.ONE * 0.24)
	_model("EA03_Nature_Bush_01a", Vector3(8.9, 0, 4.1), -0.4, Vector3.ONE * 0.26)

func _merchant() -> void:
	_prefab("market_stall", Vector3(-15.4, 0, -6.7))
	_prefab("market_stall", Vector3(-17.4, 0, -2.3), 0.13)
	_prefab("barrel_group", Vector3(-13.3, 0, -9.0), 0.2)
	_crate(Vector3(-17.8, 0, -7.7))
	_crate(Vector3(-17.8, 0.64, -7.7), true)
	_model("EA03_Prop_Container_Bag_02a", Vector3(-14, 0.05, -8.7))
	_model("EA03_Prop_Vegetable_Basket_02", Vector3(-16.6, 0, -4.9))

func _tavern() -> void:
	_prefab("barrel_group", Vector3(7.2, 0, -8.8), -0.2)
	_prefab("barrel_group", Vector3(16.6, 0, -9.1), PI / 2)
	for point: Vector3 in [Vector3(14, 0, -6.5), Vector3(16.7, 0, -4.5)]:
		_model("EA03_Prop_Tabble_01a", point, PI / 2)
		assets.box_collision(point + Vector3(0, 0.42, 0), Vector3(2.68, 0.84, 0.98))
		_prefab("bench", point + Vector3(0, 0, 1.2))
		_prefab("bench", point + Vector3(0, 0, -1.2), PI)
		for offset: Vector3 in [Vector3(-0.4, 0.832, 0.12), Vector3(0.65, 0.832, -0.20)]:
			_model("EA_Items_House_mug_01a", point + offset)
	_lantern(Vector3(9.0, 2.7, -9.4))
	_lantern(Vector3(14, 2.7, -9.4))

func _residential() -> void:
	_prefab("fence_segment", Vector3(18.0, 0, 15.6), 0.1)
	_prefab("fence_segment", Vector3(8.2, 0, 18.8), PI / 2)
	_prefab("bench", Vector3(15.5, 0, 13.8))
	_prefab("barrel_group", Vector3(19.3, 0, 16.2))
	_model("EA03_Items_House_Firewood_01a", Vector3(7.7, 0, 17.0))
	_model("EA03_Items_House_Firewood_01a", Vector3(-5.0, 0, 19.0))
	_crate(Vector3(-4.9, 0, 16.9))
	for point: Vector3 in [Vector3(17.3, 0, 15.0), Vector3(-6, 0, 17.4), Vector3(6.8, 0, 18.2)]:
		_model("EA03_Nature_Bush_01a", point, 0.5, Vector3.ONE * 0.24)
	_lantern_post(Vector3(6.7, 0, 12.8))
	_model("EA_Prop_Stand_Sheet_01a", Vector3(19.5, 0, 13.0), 0.12, Vector3.ONE * 0.65)
	_tree(Vector3(27, 0, 12), 0.64, "EA03_Nature_Tree_02c")
	_tree(Vector3(-8, 0, 26), 0.60, "EA03_Nature_Tree_01b")

func _alley() -> void:
	# Imported roofed wall segments, not old collision boxes made visible.
	for side in [-1.0, 1.0]:
		for z in [-13.7, -18.7]:
			_model("EA03_Fence_Wall_01b", Vector3(side * 3.1, -0.0077, z), PI / 2)
			assets.box_collision(Vector3(side * 3.1, 1.6, z + 2.5), Vector3(1.2, 3.2, 5.0))
	_prefab("barrel_group", Vector3(-2.0, 0, -23.4), PI / 2)
	_crate(Vector3(2.15, 0, -18.7))
	_crate(Vector3(2.15, 0.64, -18.7), true)
	_model("EA03_Prop_Container_Bag_02a", Vector3(1.9, 0.05, -16.7))
	_lantern(Vector3(-2.1, 2.4, -14.0))

func _watch() -> void:
	_prefab("watch_tower", Vector3(-16.2, 0, 8))
	_prefab("fence_segment", Vector3(-14, 0, 13.4))
	_prefab("fence_segment", Vector3(-20.0, 0, 11), PI / 2)
	_prefab("barrel_group", Vector3(-10.6, 0, 4.0), PI / 2)
	_lantern(Vector3(-13.55, 2.35, 8))
	_tree(Vector3(-23.8, 0, 16), 0.74, "EA03_Nature_Tree_01b")

func _boundary() -> void:
	for side in [-1.0, 1.0]:
		for value in [-27.0, -23.3, -19.6, -15.9, -12.2, -8.5, -4.8, -1.1, 2.6, 6.3, 10.0, 13.7, 17.4, 21.1, 24.8, 28.5]:
			_prefab("fence_segment", Vector3(value, 0, side * 29.3))
			_prefab("fence_segment", Vector3(side * 29.3, 0, value), PI / 2)
	for point: Vector3 in [Vector3(-26, 0, -25), Vector3(24, 0, -24), Vector3(-25, 0, 25), Vector3(27, 0, 27), Vector3(15, 0, -28), Vector3(-15, 0, -28)]:
		_tree(point, 0.76, "EA03_Nature_Tree_01b")
	# Sparse edge growth, with deterministic fixed variation and no processing.
	for index in range(16):
		var x := -25.0 + index * 3.2
		_model("EA03_Plant_Grass_01c", Vector3(x, 0.01, 28.0), float(index), Vector3.ONE * 0.62)
	for point: Vector3 in [Vector3(-10.5, 0.01, -18.5), Vector3(-12.7, 0.01, -18.3), Vector3(12.4, 0.01, -18.4), Vector3(14.5, 0.01, -18.1), Vector3(-23.2, 0.01, -9), Vector3(26.9, 0.01, 6), Vector3(-22.8, 0.01, 5), Vector3(23.5, 0.01, 17.8), Vector3(-9.7, 0.01, 18.7), Vector3(20.3, 0.01, -25.7), Vector3(-18.4, 0.01, -25.4)]:
		_model("EA03_Plant_Grass_01c", point, point.x * 0.13, Vector3.ONE * 0.38)
	# Authored irregular clusters outside the playable fence, using low-vertex
	# source trees rather than a row of identical background silhouettes.
	var background: Array[Vector3] = [Vector3(-35, 0, -37), Vector3(-38, 0, -43), Vector3(-31, 0, -47), Vector3(-16, 0, -38), Vector3(-9, 0, -44), Vector3(-4, 0, -40), Vector3(18, 0, -37), Vector3(22, 0, -44), Vector3(33, 0, -40), Vector3(42, 0, -24), Vector3(39, 0, -18), Vector3(45, 0, -8), Vector3(37, 0, 17), Vector3(43, 0, 22), Vector3(35, 0, 32), Vector3(19, 0, 39), Vector3(11, 0, 35), Vector3(7, 0, 42), Vector3(-15, 0, 37), Vector3(-22, 0, 44), Vector3(-31, 0, 37), Vector3(-39, 0, 23), Vector3(-43, 0, 17), Vector3(-36, 0, -6), Vector3(-42, 0, -13)]
	var trees := ["EA03_Nature_Tree_06b", "EA03_Nature_Tree_01b", "EA03_Nature_Tree_02c"]
	for index in range(background.size()):
		_model(trees[index % 3], background[index], index * 0.3, Vector3.ONE * (0.62 + (index % 4) * 0.1))
	# Distant roof groups break the abrupt fence/horizon line while remaining outside
	# the collision area. Their scale and cool value keep the playable facades dominant.
	var skyline: Array[Vector3] = [Vector3(-43, 0, -42), Vector3(-27, 0, -51), Vector3(-7, 0, -55), Vector3(16, 0, -49), Vector3(38, 0, -44), Vector3(51, 0, -25), Vector3(55, 0, -3), Vector3(53, 0, 21), Vector3(39, 0, 47), Vector3(15, 0, 54), Vector3(-10, 0, 52), Vector3(-34, 0, 43), Vector3(-51, 0, 21), Vector3(-54, 0, -5)]
	for index in range(skyline.size()):
		var house: String = ["house_cottage", "house_inn", "house_merchant"][index % 3]
		var yaw := float(index) * 0.81
		var tint: Color = [Color(0.57, 0.65, 0.72), Color(0.69, 0.63, 0.55), Color(0.57, 0.62, 0.67)][index % 3]
		_prefab(house, skyline[index], yaw, tint * 0.8)

func _prefab(identity: String, position_value: Vector3, yaw: float = 0.0, tint: Color = Color.WHITE) -> void:
	assets.place(PREFABS + identity + ".tscn", position_value, yaw, Vector3.ONE, tint)

func _model(identity: String, position_value: Vector3, yaw: float = 0.0, scale_value: Vector3 = Vector3.ONE, tint: Color = Color.WHITE) -> void:
	assets.place(PACK + identity + ".glb", position_value, yaw, scale_value, tint)

func _crate(position_value: Vector3, second: bool = false) -> void:
	_model("EA03_Prop_Container_Crate_03a" if second else "EA03_Prop_Container_Crate_01a", position_value)
	assets.box_collision(position_value + Vector3(0, 0.32, 0), Vector3(0.87, 0.64, 0.81))

func _tree(position_value: Vector3, scale_value: float, model: String) -> void:
	_model(model, position_value, 0.3, Vector3.ONE * scale_value)
	# Foliage never blocks the camera/player; only the trunk has collision.
	assets.box_collision(position_value + Vector3(0, 1.2, 0), Vector3(0.25, 2.4, 0.25))

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
	var low_quality := "--echo-low-graphics" in OS.get_cmdline_user_args()
	var holder := Node3D.new()
	holder.name = "Environment"
	get_node("LightmapGI").add_child(holder)
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
	WorldVisualConfig.tune_environment(environment, low_quality)
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	holder.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sunset"
	sun.rotation_degrees = Vector3(-32, -32, 0)
	sun.light_color = WorldVisualConfig.SUN_COLOR
	sun.light_energy = WorldVisualConfig.SUN_ENERGY
	sun.light_bake_mode = Light3D.BAKE_DISABLED
	sun.shadow_enabled = not low_quality
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.55
	sun.shadow_blur = 1.5
	sun.shadow_opacity = 0.52
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	holder.add_child(sun)
	for point: Vector3 in [Vector3(-11, 2.8, -8), Vector3(11, 2.8, -8)]:
		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.light_color = WorldVisualConfig.SUN_COLOR
		lamp.light_energy = 0.5
		lamp.omni_range = 4
		lamp.shadow_enabled = false
		lamp.light_bake_mode = Light3D.BAKE_DISABLED
		holder.add_child(lamp)
	_add_reflection_probe("SquareProbe", Vector3(-0.3, 2.5, 0.5), Vector3(12, 5, 14), not low_quality)
	_add_reflection_probe("MarketInnProbe", Vector3(0, 2.5, -12), Vector3(20, 5, 10), not low_quality)

func _add_reflection_probe(identity: String, point: Vector3, size: Vector3, enabled: bool = true) -> void:
	var probe := ReflectionProbe.new()
	probe.name = identity
	probe.position = point
	probe.extents = size
	probe.box_projection = true
	probe.intensity = 0.35
	probe.max_distance = 36.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.visible = enabled
	add_child(probe)
