extends RefCounted
class_name NPCPathRouter

## Builds a small walk graph from the imported scene's actual collision at an
## active NPC's location. This keeps routes out of the walls and railings whose
## mesh bounds do not make a traversable lane.

const DATA_PATH := "res://data/npc_walkways.json"

var grid_step := 1.25
var patch_cells := 6
var pause_chance := 0.18
var pause_min_seconds := 0.7
var pause_max_seconds := 2.8
var ready := false


func load_walkways() -> bool:
	var data := DataUtils.dictionary(DataUtils.read_json(DATA_PATH))
	grid_step = maxf(0.75, DataUtils.number(data.get("grid_step", 1.25), 1.25))
	patch_cells = clampi(int(DataUtils.number(data.get("patch_cells", 6), 6)), 3, 9)
	pause_chance = DataUtils.unit(data.get("pause_chance", 0.18), 0.18)
	pause_min_seconds = maxf(0.0, DataUtils.number(data.get("pause_min_seconds", 0.7), 0.7))
	pause_max_seconds = maxf(pause_min_seconds, DataUtils.number(data.get("pause_max_seconds", 2.8), 2.8))
	ready = grid_step > 0.0 and patch_cells >= 3
	return ready


func build_local_graph(world: World3D, center: Vector3, shape: Shape3D, exclusions: Array[RID]) -> Dictionary:
	if not ready or world == null or shape == null:
		return {}
	var space := world.direct_space_state
	var center_cell_x := roundi(center.x / grid_step)
	var center_cell_z := roundi(center.z / grid_step)
	var nodes: Dictionary = {}
	for cell_x in range(center_cell_x - patch_cells, center_cell_x + patch_cells + 1):
		for cell_z in range(center_cell_z - patch_cells, center_cell_z + patch_cells + 1):
			var x := float(cell_x) * grid_step
			var z := float(cell_z) * grid_step
			var candidate := _surface_position(space, center, shape, exclusions, x, z)
			if candidate == Vector3.INF:
				continue
			var id := _node_id(cell_x, cell_z)
			nodes[id] = {
				"position": candidate,
				"links": [],
				"edge": abs(cell_x - center_cell_x) == patch_cells or abs(cell_z - center_cell_z) == patch_cells,
			}
	# Cardinal links keep the capsule centered in clear space instead of cutting corners.
	for cell_x in range(center_cell_x - patch_cells, center_cell_x + patch_cells + 1):
		for cell_z in range(center_cell_z - patch_cells, center_cell_z + patch_cells + 1):
			var id := _node_id(cell_x, cell_z)
			if not nodes.has(id):
				continue
			for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var neighbor_x := cell_x + offset.x
				var neighbor_z := cell_z + offset.y
				var neighbor_id := _node_id(neighbor_x, neighbor_z)
				if not nodes.has(neighbor_id):
					continue
				var point: Vector3 = nodes[id]["position"]
				var neighbor: Vector3 = nodes[neighbor_id]["position"]
				if absf(point.y - neighbor.y) > 0.48:
					continue
				if not _capsule_clear(space, shape, exclusions, point.lerp(neighbor, 0.5)):
					continue
				var point_links: Array = nodes[id]["links"]
				var neighbor_links: Array = nodes[neighbor_id]["links"]
				point_links.append(neighbor_id)
				neighbor_links.append(id)
	var start_id := _nearest_node(nodes, center)
	if start_id.is_empty():
		return {}
	var reachable := _reachable_nodes(nodes, start_id)
	for id: String in nodes.keys():
		if not reachable.has(id):
			nodes.erase(id)
	return {"nodes": nodes, "start_id": start_id, "center_cell": Vector2i(center_cell_x, center_cell_z)}


func waypoint_position(nodes: Dictionary, id: String) -> Vector3:
	if not nodes.has(id):
		return Vector3.ZERO
	return nodes[id]["position"] as Vector3


func choose_next(nodes: Dictionary, current_id: String, previous_id: String, random: RandomNumberGenerator) -> String:
	if not nodes.has(current_id):
		return ""
	var options: Array = nodes[current_id]["links"]
	if options.size() > 1 and not previous_id.is_empty():
		var forward: Array = []
		for id: String in options:
			if id != previous_id:
				forward.append(id)
		if not forward.is_empty():
			options = forward
	if options.is_empty():
		return ""
	return options[random.randi_range(0, options.size() - 1)]


func node_is_patch_edge(nodes: Dictionary, id: String) -> bool:
	return nodes.has(id) and bool(nodes[id].get("edge", false))


func _surface_position(space: PhysicsDirectSpaceState3D, center: Vector3, shape: Shape3D, exclusions: Array[RID], x: float, z: float) -> Vector3:
	var origin := Vector3(x, center.y + 3.4, z)
	var ray := PhysicsRayQueryParameters3D.create(origin, Vector3(x, center.y - 2.8, z))
	ray.exclude = exclusions
	ray.collision_mask = 1
	ray.collide_with_areas = false
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return Vector3.INF
	var hit_normal: Vector3 = hit["normal"]
	if hit_normal.y < 0.62:
		return Vector3.INF
	var position: Vector3 = hit.position + Vector3.UP * 0.035
	if absf(position.y - center.y) > 1.35:
		return Vector3.INF
	return position if _capsule_clear(space, shape, exclusions, position) else Vector3.INF


func _capsule_clear(space: PhysicsDirectSpaceState3D, shape: Shape3D, exclusions: Array[RID], floor_position: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, floor_position + Vector3.UP * 0.9)
	query.exclude = exclusions
	query.collision_mask = 1
	query.margin = 0.0
	return space.intersect_shape(query, 1).is_empty()


func _nearest_node(nodes: Dictionary, center: Vector3) -> String:
	var best_id := ""
	var best_score := INF
	for id: String in nodes:
		if (nodes[id]["links"] as Array).is_empty():
			continue
		var point: Vector3 = nodes[id]["position"]
		var score := Vector2(point.x, point.z).distance_squared_to(Vector2(center.x, center.z)) + pow(point.y - center.y, 2.0) * 1.5
		if score < best_score:
			best_id = id
			best_score = score
	return best_id if best_score <= 9.0 else ""


func _reachable_nodes(nodes: Dictionary, start_id: String) -> Dictionary:
	var visited: Dictionary = {}
	var pending: Array[String] = [start_id]
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if visited.has(id):
			continue
		visited[id] = true
		for link: String in nodes[id]["links"]:
			if not visited.has(link):
				pending.append(link)
	return visited


func _node_id(cell_x: int, cell_z: int) -> String:
	return "%d:%d" % [cell_x, cell_z]
