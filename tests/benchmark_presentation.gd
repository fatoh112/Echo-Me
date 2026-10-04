extends SceneTree
## Repeatable on-device comparison for Compatibility visual quality profiles.
const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 180

var _output: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	await process_frame
	var environments: Array = scene.find_children("*", "WorldEnvironment", true, false)
	var directional_lights: Array = scene.find_children("*", "DirectionalLight3D", true, false)
	var environment_node := environments[0] as WorldEnvironment if not environments.is_empty() else null
	var sun := directional_lights[0] as DirectionalLight3D if not directional_lights.is_empty() else null
	var probes: Array[Node] = scene.find_children("*", "ReflectionProbe", true, false)
	var environment: Environment = environment_node.environment
	await _measure("Baseline, effects and shadows off", environment, sun, probes, false, false, false, false)
	await _measure("SSAO + glow, sun shadows off", environment, sun, probes, true, true, false, false)
	await _measure("Sun shadows + SSAO + glow", environment, sun, probes, true, true, true, false)
	if sun != null:
		sun.directional_shadow_max_distance = 42.0
	await _measure("Final, probes enabled", environment, sun, probes, true, true, true, true)
	for row: Dictionary in _output:
		print("PRESENTATION BENCHMARK: %s | avg %.2f ms | median %.2f ms | p95 %.2f ms | %.1f avg FPS | %d avg draws | %d avg objects" % [
			row["name"], row["avg_ms"], row["median_ms"], row["p95_ms"], 1000.0 / row["avg_ms"], row["draw_calls"], row["objects"],
		])
	scene.queue_free()
	await process_frame
	quit()


func _measure(label: String, environment: Environment, sun: DirectionalLight3D, probes: Array[Node], ssao_enabled: bool, glow_enabled: bool, sun_shadows: bool, probes_enabled: bool) -> void:
	environment.ssao_enabled = ssao_enabled
	environment.glow_enabled = glow_enabled
	if sun != null:
		sun.shadow_enabled = sun_shadows
	for probe: Node in probes:
		probe.visible = probes_enabled
	for _frame in range(WARMUP_FRAMES):
		await process_frame
	var times: Array[float] = []
	var draws := 0
	var objects := 0
	for _frame in range(SAMPLE_FRAMES):
		var started := Time.get_ticks_usec()
		await process_frame
		times.append((Time.get_ticks_usec() - started) / 1000.0)
		draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objects += int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	times.sort()
	var total := 0.0
	for elapsed in times:
		total += elapsed
	var mean := total / maxf(1.0, float(times.size()))
	_output.append({
		"name": label,
		"avg_ms": mean,
		"median_ms": times[floori(times.size() * 0.5)],
		"p95_ms": times[mini(times.size() - 1, floori(times.size() * 0.95))],
		"draw_calls": roundi(float(draws) / SAMPLE_FRAMES),
		"objects": roundi(float(objects) / SAMPLE_FRAMES),
	})
