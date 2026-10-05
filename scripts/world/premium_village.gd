extends Node3D
class_name PremiumVillage

const HOUSE_CENTERS: Array[Vector2] = [
	Vector2(41.5, -57.0), Vector2(37.0, -79.5),
	Vector2(24.0, -92.0), Vector2(13.2, -81.0),
]
const LOCATION_LABELS: Dictionary = {
	"PLAYER_QUARTERS": "YOUR HOME",
	"TOWN_SQUARE": "THE WELL",
	"MERCHANT_SHOP": "ALEX · MERCHANT",
	"TAVERN": "THE TAVERN",
	"RESIDENTIAL_ROW": "RESIDENTIAL ROW",
	"BACK_ALLEY": "BACK ALLEY",
	"WATCH_POST": "THE WATCH",
}
@onready var village: Node3D = $ImportedVillage
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var lightmap: LightmapGI = $LightmapGI

var locations_root: Node3D
var mesh_instance_count := 0
var structural_collision_count := 0
var collision_shape_count := 0
var static_triangle_count := 0
var quality_profile := "MEDIUM"

func _ready() -> void:
	quality_profile = "HIGH" if "--echo-high-graphics" in OS.get_cmdline_user_args() else "MEDIUM"
	_configure_world_environment()
	_configure_imported_scene()
	_read_authored_collision()
	print("PREMIUM VILLAGE: profile ", quality_profile, ", meshes ", mesh_instance_count, ", collision sections ", structural_collision_count, ", box shapes ", collision_shape_count)

func build(locations: Dictionary) -> void:
	if locations_root == null:
		locations_root = Node3D.new()
		locations_root.name = "LogicalLocations"
		add_child(locations_root)
	for child in locations_root.get_children():
		child.queue_free()
	for location_id: String in locations:
		var coordinates: Array = locations[location_id].get("position", [0.0, 1.2, -65.0])
		var marker := Marker3D.new()
		marker.name = location_id
		marker.position = Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
		locations_root.add_child(marker)

func _configure_world_environment() -> void:
	var environment := world_environment.environment
	var low_graphics := "--echo-low-graphics" in OS.get_cmdline_user_args()
	var high_graphics := quality_profile == "HIGH"
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	# The vendor screenshots show a clear daytime sky. The old dark sunset palette
	# underexposed imported stonework even in open sunlight.
	sky_material.sky_top_color = Color(0.40, 0.63, 0.88)
	sky_material.sky_horizon_color = Color(0.84, 0.89, 0.94)
	sky_material.ground_bottom_color = Color(0.28, 0.29, 0.30)
	sky_material.ground_horizon_color = Color(0.57, 0.53, 0.47)
	sky_material.sun_angle_max = 7.0
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.78, 0.83, 0.90)
	environment.ambient_light_energy = 1.02
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.background_energy_multiplier = 1.12
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.98
	environment.tonemap_white = 6.0
	environment.ssao_enabled = not low_graphics
	environment.ssao_radius = 0.68
	environment.ssao_intensity = 0.46
	environment.ssao_power = 1.10
	environment.ssao_detail = 0.16
	environment.ssao_horizon = 0.055
	environment.ssao_sharpness = 0.82
	environment.ssao_light_affect = 0.18
	environment.ssil_enabled = high_graphics and not low_graphics
	environment.ssil_intensity = 0.42
	environment.ssil_radius = 4.0
	environment.ssr_enabled = false
	environment.glow_enabled = not low_graphics
	environment.glow_intensity = 0.18
	environment.glow_strength = 0.7
	environment.glow_bloom = 0.025
	environment.glow_hdr_threshold = 1.6
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_MIX
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.57, 0.64, 0.70)
	environment.fog_light_energy = 0.26
	environment.fog_sun_scatter = 0.012
	environment.fog_depth_begin = 96.0
	environment.fog_depth_end = 230.0
	environment.fog_depth_curve = 1.24
	environment.volumetric_fog_enabled = high_graphics and not low_graphics
	environment.volumetric_fog_density = 0.006
	environment.volumetric_fog_albedo = Color(0.54, 0.57, 0.62)
	environment.volumetric_fog_length = 96.0 if not high_graphics else 128.0
	environment.volumetric_fog_gi_inject = 0.0
	environment.volumetric_fog_sky_affect = 0.22
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.82
	# Light from the square's open approach, so the walls and cobbles catch direct sun
	# in the same view angle as the vendor reference captures.
	sun.rotation_degrees = Vector3(-32.0, 40.0, 0.0)
	sun.light_color = Color(1.0, 0.90, 0.75)
	sun.shadow_enabled = not low_graphics
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.5
	sun.shadow_blur = 0.58
	sun.shadow_opacity = 0.76
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 64.0 if not high_graphics else 88.0
	sun.light_bake_mode = Light3D.BAKE_DYNAMIC
	lightmap.quality = LightmapGI.BAKE_QUALITY_MEDIUM if not high_graphics else LightmapGI.BAKE_QUALITY_HIGH
	lightmap.texel_scale = 0.32 if not high_graphics else 0.24
	lightmap.max_texture_size = 8192
	lightmap.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_8

func _configure_imported_scene() -> void:
	var collision_source := village.get_node_or_null("CollisionSource") as Node3D
	for node in village.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if collision_source != null and collision_source.is_ancestor_of(mesh_instance):
			if str(mesh_instance.name).begins_with("S_Modular_Wooden_Door_"):
				mesh_instance.visible = false
			continue
		mesh_instance_count += 1
		mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		var node_name := str(mesh_instance.name)
		if node_name.begins_with("BakeChunk"):
			mesh_instance.extra_cull_margin = 1.0
	for node in village.find_children("*", "OmniLight3D", true, false):
		var local_light := node as OmniLight3D
		local_light.light_energy = minf(local_light.light_energy, 1.4)
		local_light.omni_range = minf(local_light.omni_range, 8.0)
		local_light.light_color = Color(1.0, 0.72, 0.52)
		local_light.shadow_enabled = false
		local_light.light_bake_mode = Light3D.BAKE_DYNAMIC

func _read_authored_collision() -> void:
	var sections := village.find_children("Collision_*", "StaticBody3D", true, false)
	structural_collision_count = sections.size()
	for body: StaticBody3D in sections:
		for node in body.find_children("Box_*", "CollisionShape3D", true, false):
			var shape_node := node as CollisionShape3D
			if shape_node.shape is BoxShape3D:
				collision_shape_count += 1
	static_triangle_count = int(village.get_meta("day5_collision_triangles", 0))
