@tool
extends EditorScenePostImport

# The Lite GLBs repeat one embedded palette. Rebind it to the supplied shared PNG
# during import instead of extracting hundreds of duplicate textures.
const PALETTE := "res://assets/environment/slavic_town/textures/EA03_FREE_Slavica.png"
const MATERIAL := "res://assets/environment/slavic_town/materials/slavic_atlas.tres"

func _post_import(scene: Node) -> Object:
	var shared := load(MATERIAL) as StandardMaterial3D
	for mesh_node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(mesh_node.mesh.get_surface_count()):
			mesh_node.mesh.surface_set_material(surface, shared)
	return scene
