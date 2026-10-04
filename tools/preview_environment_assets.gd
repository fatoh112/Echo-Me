extends SceneTree
## Authoring only: inspect supplied meshes, pivots and materials in real OpenGL.
const ROOT := "res://assets/environment/slavic_town/glb/glTF/"
const MODELS := [
	"EA03_Village_Hut_Wall_Front_04e", "EA03_Village_Hut_Wall_Front_03f",
	"EA03_Village_Hut_Wall_Painted_Side_02c", "EA03_Village_Hut_Roof_Cut_01c",
	"EA03_Village_Hut_Roof_01c", "EA03_Prop_Village_Whell_01d",
	"EA03_Village_Tover_01a", "EA03_Village_OutBuilding_WoodRoof_01b",
	"EA03_Prop_House_Door_01b", "EA03_Prop_House_Shutter_01e",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.34, 0.39)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.9)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	stage.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 45
	stage.add_child(camera)
	var directory := ProjectSettings.globalize_path("user://echo_me_asset_inspection")
	DirAccess.make_dir_recursive_absolute(directory)
	for model_name: String in MODELS:
		var packed := load(ROOT + model_name + ".glb") as PackedScene
		if packed == null:
			quit(1)
			return
		var model := packed.instantiate()
		stage.add_child(model)
		var bounds := AABB()
		var first := true
		for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_bounds := mesh_node.global_transform * mesh_node.get_aabb()
			bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
			first = false
		var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var center := bounds.get_center()
		camera.position = center + Vector3(1.3, 0.65, 1.05).normalized() * extent * 2.0
		camera.look_at(center)
		for _frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join(model_name + ".png"))
		print("ASSET PREVIEW: ", model_name, " bounds ", bounds)
		model.free()
	quit()
