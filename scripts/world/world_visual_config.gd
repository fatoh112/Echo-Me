extends RefCounted
class_name WorldVisualConfig

const SUN_COLOR := Color(1.0, 0.76, 0.49)
const SUN_ENERGY := 1.15
const AMBIENT_COLOR := Color(0.68, 0.73, 0.81)
const AMBIENT_ENERGY := 0.62
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
		result.roughness = 0.94
		result.vertex_color_use_as_albedo = true
		if identity == "metal":
			result.metallic = 0.25
		if identity == "glow":
			result.emission_enabled = true
			result.emission = PALETTE["glow"]
			result.emission_energy_multiplier = 0.65
		_materials[identity] = result
	return _materials[identity]
