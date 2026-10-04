extends CanvasLayer
class_name DebugUI

var panel: PanelContainer
var text_label: Label
var npc_picker: OptionButton
var world: WorldState
var nearby_id := ""


func _ready() -> void:
	_build()


func setup(world_state: WorldState) -> void:
	world = world_state
	npc_picker.add_item("Nearby NPC / Alex if none")
	npc_picker.set_item_metadata(0, "")
	var ids: Array = world.npcs.keys()
	ids.sort()
	for npc_id: String in ids:
		npc_picker.add_item((world.npcs[npc_id] as NPCData).display_name)
		npc_picker.set_item_metadata(npc_picker.item_count - 1, npc_id)
	refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		panel.visible = not panel.visible
		refresh()
		get_viewport().set_input_as_handled()


func refresh(npc_id: String = "") -> void:
	if world == null:
		return
	if not npc_id.is_empty():
		nearby_id = npc_id
	var selected := str(npc_picker.get_item_metadata(npc_picker.selected))
	if selected.is_empty():
		selected = nearby_id if world.npcs.has(nearby_id) else "alex"
	var npc: NPCData = world.npcs[selected]
	var lines: Array[String] = [
		"Current Zone: " + world.last_player_location,
		"PLAYER / ECHO PROFILE", "trait             player / echo",
	]
	for trait_name in PlayerBehaviorProfile.TRAIT_NAMES:
		lines.append("%s: %.2f / %.2f" % [trait_name, float(world.player_profile.traits[trait_name]), float(world.echo_profile.traits[trait_name])])
	lines.append("Echo seed: %d; distortion <= %.3f" % [world.echo_seed, EchoBehaviorProfile.MAX_DISTORTION])
	lines.append("\nGLOBAL REPUTATION")
	for value_name in ReputationSystem.VALUE_NAMES:
		lines.append("%s: %.2f" % [value_name, float(world.reputation.values[value_name])])
	lines.append("\nSELECTED: %s (%s)" % [npc.display_name, npc.role])
	lines.append("Mood: %s | Memory Collision: %s" % [str(npc.current_state["mood"]), npc.collision_state])
	lines.append("%s / %s / %s" % [str(npc.current_state["location_id"]), str(npc.current_state["activity"]), npc.activity_level])
	for value_name in NPCRelationship.VALUE_NAMES:
		lines.append("%s: %.2f" % [value_name, float(npc.relationship.values[value_name])])
	lines.append("Important/recent memories (%d retained):" % npc.memories.size())
	for memory in MemorySystem.relevant_memories(npc, Time.get_unix_time_from_system()):
		lines.append("%s [perceived %s; actual %s; importance %.2f%s]" % [memory.summary, memory.perceived_actor_id, memory.actual_source, memory.importance, "; answered" if memory.addressed else ""])
	lines.append("\nNEIGHBORS")
	for neighbor: NPCData in world.npcs.values():
		lines.append("%s: %s, %s, %s" % [neighbor.display_name, str(neighbor.current_state["location_id"]), neighbor.activity_level, neighbor.collision_state])
	lines.append("\nOFFLINE ECHO EVENTS")
	if world.last_offline_events.is_empty():
		lines.append("(none yet)")
	for action in world.last_offline_events:
		var target: NPCData = world.npcs[action.target_id]
		lines.append("%s -> %s | actual %s / perceived %s" % [action.action_type, target.display_name, action.actual_source, action.perceived_actor_id])
	if not world.last_decisions.is_empty():
		var decision: Dictionary = world.last_decisions.back()
		lines.append("\nLATEST UTILITY DECISION")
		lines.append("Target: %s | SELECTED: %s" % [str(decision["target_id"]), str(decision["action_type"])])
		for row: Dictionary in decision["action_scores"]:
			lines.append("%s %.3f" % [str(row["action_type"]), float(row["score"])])
		lines.append("Target scores:")
		for row: Dictionary in decision["target_scores"]:
			lines.append("%s %.3f" % [str(row["target_name"]), float(row["target_score"])])
		var ranked_actions: Array = decision["action_scores"]
		if not ranked_actions.is_empty():
			lines.append("Selected action factors:")
			var factors: Dictionary = ranked_actions[0]["factors"]
			for factor: String in factors:
				lines.append("%s %.3f" % [factor, float(factors[factor])])
	text_label.text = "\n".join(lines)


func _picked(_index: int) -> void:
	refresh()


func _build() -> void:
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.97)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_bottom = 1.0
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = 372
	panel.offset_bottom = -76
	panel.visible = false
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var title := Label.new()
	title.text = "ECHO ME DEBUG — F3 hide | Esc cursor"
	title.add_theme_font_size_override("font_size", 14)
	content.add_child(title)
	npc_picker = OptionButton.new()
	npc_picker.item_selected.connect(_picked)
	content.add_child(npc_picker)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	text_label = Label.new()
	text_label.custom_minimum_size.x = 318
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 14)
	scroll.add_child(text_label)
