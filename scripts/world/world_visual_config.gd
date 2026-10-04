extends RefCounted
class_name WorldVisualConfig

const SUN_COLOR := Color(1.0, 0.82, 0.65)
const SUN_ENERGY := 1.18
const AMBIENT_COLOR := Color(0.68, 0.75, 0.88)
const AMBIENT_ENERGY := 0.66
const PALETTE: Dictionary = {
	"stone": Color(0.48, 0.43, 0.36), "paving": Color(0.52, 0.48, 0.41),
	"wood": Color(0.23, 0.14, 0.085), "wood_light": Color(0.43, 0.29, 0.16),
	"plaster": Color(0.79, 0.71, 0.56), "plaster_rose": Color(0.67, 0.51, 0.42),
	"roof": Color(0.32, 0.135, 0.09), "roof_slate": Color(0.25, 0.29, 0.31),
	"metal": Color(0.16, 0.18, 0.19), "window": Color(0.12, 0.15, 0.16),
	"cloth_red": Color(0.48, 0.19, 0.15), "cloth_blue": Color(0.24, 0.36, 0.40),
	"cloth_green": Color(0.32, 0.40, 0.23), "cream": Color(0.84, 0.76, 0.60),
	"water": Color(0.24, 0.40, 0.42), "foliage": Color(0.28, 0.34, 0.19),
	"earth": Color(0.32, 0.28, 0.23), "glow": Color(1.0, 0.62, 0.24),
	"skin": Color(0.71, 0.50, 0.35), "charcoal": Color(0.20, 0.19, 0.18),
}
const NPC_STYLE: Dictionary = {
	"alex": {"height": 1.78, "width": 0.66, "coat": "wood_light", "trim": "cream", "apron": true, "hat": true},
	"sarah": {"height": 1.72, "width": 0.46, "coat": "cloth_green", "trim": "cream", "skirt": true, "hair": true},
	"mike": {"height": 1.80, "width": 0.45, "coat": "cloth_blue", "trim": "stone", "hat": true},
	"emma": {"height": 1.70, "width": 0.53, "coat": "cloth_red", "trim": "cream", "apron": true, "skirt": true},
	"david": {"height": 1.85, "width": 0.59, "coat": "charcoal", "trim": "cloth_red", "hood": true},
	"noah": {"height": 1.96, "width": 0.58, "coat": "cloth_blue", "trim": "metal", "guard": true},
}
static var _materials: Dictionary = {}

static func material(identity: String) -> StandardMaterial3D:
	if not _materials.has(identity):
		var result := StandardMaterial3D.new()
		result.albedo_color = PALETTE.get(identity, PALETTE["stone"])
		result.roughness = 0.86
		result.vertex_color_use_as_albedo = true
		if identity == "metal":
			result.metallic = 0.25
		if identity == "glow":
			result.emission_enabled = true
			result.emission = PALETTE["glow"]
			result.emission_energy_multiplier = 0.65
		_materials[identity] = result
	return _materials[identity]


static func tune_environment(environment: Environment, low_quality: bool = false) -> void:
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.92
	environment.tonemap_white = 6.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLOR
	environment.ambient_light_energy = AMBIENT_ENERGY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.ssao_enabled = not low_quality
	environment.ssao_radius = 1.15
	environment.ssao_intensity = 1.05
	environment.ssao_power = 1.25
	environment.ssao_detail = 0.18
	environment.ssao_horizon = 0.055
	environment.ssao_sharpness = 0.82
	environment.ssao_light_affect = 0.18
	environment.glow_enabled = not low_quality
	environment.glow_intensity = 0.16
	environment.glow_strength = 0.72
	environment.glow_bloom = 0.035
	environment.glow_hdr_threshold = 1.5
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_MIX
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.43, 0.49, 0.57)
	environment.fog_light_energy = 0.72
	environment.fog_sun_scatter = 0.025
	environment.fog_depth_begin = 46.0
	environment.fog_depth_end = 138.0
	environment.fog_depth_curve = 1.24
