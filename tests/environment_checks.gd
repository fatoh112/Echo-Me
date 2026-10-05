extends RefCounted
## Day 5 regression: optimized PBR village, four open interiors, physical anchors, and real NPC rigs.

const HERO_DOORWAYS: Array[Vector3] = [
	Vector3(40.5, 4.9, -57.1), Vector3(36.7, 4.9, -78.5),
	Vector3(23.3, 1.4, -92.2), Vector3(14.2, 1.4, -80.5),
]

func run(game: Node3D, check: Callable) -> void:
	var town := game.neighborhood as PremiumVillage
	var village := town.village
	var source := village.get_node_or_null("CollisionSource") as Node3D
	check.call(town != null and village != null and source != null, "Environment: premium authored village scene is loaded")
	check.call(game.neighborhood.find_children("*", "SlavicTown", true, false).is_empty(), "Environment: retired Slavic visual town is absent")
	var chunks := village.find_children("BakeChunk*", "MeshInstance3D", true, false)
	check.call(chunks.size() > 0 and chunks.size() < 100, "Environment: authored PBR geometry stays below 100 draw batches")
	check.call(chunks.size() == town.mesh_instance_count, "Environment: visible render nodes match saved mesh chunk count")
	check.call(town.structural_collision_count >= 6 and town.collision_shape_count >= 300 and town.static_triangle_count == 0, "Environment: structural collision uses grouped, low-cost authored boxes")
	var every_collision_is_box := true
	var colliders := village.find_children("Box_*", "CollisionShape3D", true, false)
	for node in colliders:
		every_collision_is_box = every_collision_is_box and (node as CollisionShape3D).shape is BoxShape3D
	check.call(colliders.size() == town.collision_shape_count and every_collision_is_box, "Environment: no large triangle mesh collision remains")
	check.call(source != null and source.find_children("*", "MeshInstance3D", true, false).is_empty(), "Environment: the 706-mesh source import is not instantiated at runtime")
	check.call(int(village.get_meta("day5_open_door_leaves", 0)) >= 8, "Environment: all four paired doorways omit the closed door leaves")
	var has_albedo := false
	var has_normal := false
	var has_roughness := false
	var static_shadow_chunks := 0
	for node in chunks:
		var chunk := node as MeshInstance3D
		check.call(chunk.gi_mode == GeometryInstance3D.GI_MODE_STATIC, "Environment: PBR chunk participates in LightmapGI")
		check.call(chunk.cast_shadow in [GeometryInstance3D.SHADOW_CASTING_SETTING_ON, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF], "Environment: each chunk has an explicit shadow role")
		if chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			static_shadow_chunks += 1
		for surface_index in range(chunk.mesh.get_surface_count()):
			var material := chunk.mesh.surface_get_material(surface_index) as StandardMaterial3D
			check.call(material != null, "Environment: imported material remains a StandardMaterial3D")
			if material != null:
				has_albedo = has_albedo or material.albedo_texture != null
				has_normal = has_normal or material.normal_texture != null
				has_roughness = has_roughness or material.roughness_texture != null
			var arrays := chunk.mesh.surface_get_arrays(surface_index)
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			check.call(uv2.size() == chunk.mesh.surface_get_array_len(surface_index), "Environment: generated lightmap UV2 covers every merged surface")
	check.call(has_albedo and has_normal and has_roughness, "Environment: packed albedo, normal, and roughness maps remain active")
	check.call(static_shadow_chunks >= 4 and static_shadow_chunks < chunks.size(), "Environment: main sun shadows are limited to large silhouettes")
	var lightmap := game.neighborhood.get_node("LightmapGI") as LightmapGI
	check.call(lightmap.light_data != null and lightmap.light_data.resource_path == "res://scenes/world/premium_village.lmbake", "Environment: scene has an external editor-bake target")
	var environment := town.world_environment.environment
	var low_graphics := "--echo-low-graphics" in OS.get_cmdline_user_args()
	check.call(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "Environment: desktop default uses Forward Plus")
	check.call(environment.tonemap_mode == Environment.TONE_MAPPER_ACES and environment.fog_enabled and environment.ssao_enabled == not low_graphics, "Environment: ACES, contact occlusion, and atmospheric depth match the quality profile")
	check.call(environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY and environment.tonemap_exposure >= 0.9 and town.sun.light_energy >= 1.3, "Environment: bright daylight sky fill matches the vendor reference")
	check.call(environment.volumetric_fog_enabled == (town.quality_profile == "HIGH"), "Environment: HIGH profile adds volumetric fog")
	check.call(town.sun.shadow_enabled == not low_graphics and town.sun.light_bake_mode == Light3D.BAKE_DYNAMIC, "Environment: one real-time sun shadow and baked indirect contribution match the quality profile")
	for light: OmniLight3D in village.find_children("*", "OmniLight3D", true, false):
		check.call(not light.shadow_enabled and light.omni_range <= 8.0, "Environment: local warm lights use short, shadowless ranges")
	check.call(game.neighborhood.find_children("*", "LightmapGI", true, false).size() == 1, "Environment: one scene-level LightmapGI covers the village")
	for location_id: String in LocationRegistry.IDS:
		check.call(game.world.locations.has(location_id) and town.locations_root.has_node(location_id), "Environment: official location ID remains live " + location_id)
		check.call(game.world.closest_location(game.world.location_position(location_id)) == location_id, "Environment: physical anchor resolves to its official logical ID " + location_id)
	for index in range(HERO_DOORWAYS.size()):
		check.call(PlayerSpawnResolver.is_clear(game.player, HERO_DOORWAYS[index]), "Environment: hero doorway is physically clear " + str(index + 1))
		check.call(_ground_hit(game, HERO_DOORWAYS[index], _collision_excludes(game)), "Environment: hero doorway has a supporting floor " + str(index + 1))
	check.call(PlayerSpawnResolver.is_clear(game.player, game.world.location_position("PLAYER_QUARTERS")), "Environment: player house spawn capsule is clear")
	check.call(_ground_hit(game, game.world.location_position("PLAYER_QUARTERS"), _collision_excludes(game)), "Environment: player house spawn rests on imported floor collision")
	var unique_models: Dictionary = {}
	for npc_id: String in game.npc_manager.entities:
		var entity := game.npc_manager.entities[npc_id] as NPCController
		var rig := entity.visual_root as NPCVisual
		var model_scene := NPCVisual.NPC_MODELS.get(npc_id) as PackedScene
		check.call(rig._humanoid != null and model_scene != null, "NPC visual: authored model loaded " + npc_id)
		if model_scene != null:
			unique_models[model_scene.resource_path] = true
		check.call(rig._humanoid != null and rig._humanoid.find_children("*", "Skeleton3D", true, false).size() > 0, "NPC visual: imported skeleton remains under the visual root " + npc_id)
		check.call(rig._humanoid != null and rig._humanoid.find_children("*", "CollisionObject3D", true, false).is_empty(), "NPC visual: no gameplay authority moved into the model " + npc_id)
		for mesh_instance: MeshInstance3D in rig._humanoid.find_children("*", "MeshInstance3D", true, false):
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				check.call(material != null and not material.vertex_color_use_as_albedo, "NPC visual: authored clothing atlas is not multiplied by empty FBX vertex colors " + npc_id)
		check.call(not entity.body_mesh.visible and entity.collider.shape is CapsuleShape3D, "NPC gameplay: original interaction body remains authoritative " + npc_id)
		check.call(entity.name_label.position.y >= 1.7 and entity.name_label.position.y <= 2.1, "NPC visual: subtle name label follows real human height " + npc_id)
		check.call(_within_human_scale(rig), "NPC visual: imported humanoid is normalized near human scale " + npc_id)
	check.call(unique_models.size() == 6, "NPC visual: six distinct pack models are assigned")
	var router := game.npc_manager.path_router as NPCPathRouter
	check.call(router != null and router.ready and router.grid_step >= 0.75 and router.patch_cells >= 3, "NPC navigation: collision-tested walkway routing settings load")
	var excludes := _collision_excludes(game)
	for npc: NPCData in game.world.npcs.values():
		var point: Vector3 = game.world.npc_position(npc)
		check.call(_capsule_clear(game, point, excludes), "NPC schedule: capsule is clear at the scheduled interior/zone " + npc.id)
		check.call(_ground_hit(game, point, excludes), "NPC schedule: scheduled spawn rests on world collision " + npc.id)
	print("DAY 5 ENVIRONMENT: ", chunks.size(), " PBR batches, ", town.structural_collision_count, " static collision sections, ", town.collision_shape_count, " box shapes; six distinct rigged NPCs.")

func _within_human_scale(rig: NPCVisual) -> bool:
	if rig._humanoid == null:
		return false
	var bounds := rig._measure_bounds(rig._humanoid, rig._humanoid)
	var style: Dictionary = WorldVisualConfig.NPC_STYLE.get(rig._npc_id, WorldVisualConfig.NPC_STYLE["mike"])
	var displayed_height := bounds.size.y * rig._humanoid.scale.y
	var displayed_floor := bounds.position.y * rig._humanoid.scale.y + rig._humanoid.position.y
	return absf(displayed_height - float(style["height"])) < 0.02 and absf(displayed_floor) < 0.02

func _collision_excludes(game: Node3D) -> Array[RID]:
	var excluded: Array[RID] = [game.player.get_rid()]
	for entity: NPCController in game.npc_manager.entities.values():
		excluded.append(entity.get_rid())
	return excluded

func _capsule_clear(game: Node3D, point: Vector3, excluded: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = game.player.get_node("CollisionShape3D").shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 0.94, 0))
	query.exclude = excluded
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _ground_hit(game: Node3D, point: Vector3, excluded: Array[RID]) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0.95, 0), point - Vector3(0, 0.65, 0))
	ray.exclude = excluded
	return not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
