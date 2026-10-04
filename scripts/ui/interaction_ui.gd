extends CanvasLayer
class_name InteractionUI

signal action_requested(action_type: String, target_id: String, response_to: String)
signal modal_changed(open: bool)

var menu_panel: PanelContainer
var menu_title: Label
var dialogue_label: Label
var action_grid: GridContainer
var prompt: Label
var toast: Label
var toast_timer: Timer
var clock_label: Label
var summary_panel: PanelContainer
var summary_text: Label
var summary_debug: Label
var summary_debug_scroll: ScrollContainer
var menu_target_id := ""
var _summary_toggle: CheckButton


func _ready() -> void:
	_build()


func is_modal() -> bool:
	return menu_panel.visible or summary_panel.visible


func set_nearby(npc: NPCData) -> void:
	prompt.visible = npc != null and not is_modal()
	if npc != null:
		prompt.text = "E — Interact with " + npc.display_name


func update_clock(world: WorldState) -> void:
	var minute := int(fmod(world.game_minutes, 1440.0))
	clock_label.text = "%02d:%02d | %s" % [minute / 60, minute % 60, str(world.locations[world.last_player_location]["display_name"])]


func open_for_npc(npc: NPCData) -> void:
	menu_target_id = npc.id
	menu_title.text = "%s — %s" % [npc.display_name, npc.role]
	var accusation := MemorySystem.unresolved_accusation(npc, Time.get_unix_time_from_system())
	dialogue_label.text = DialogueResolver.accusation(npc, accusation) if accusation != null else DialogueResolver.greeting(npc)
	for child in action_grid.get_children():
		action_grid.remove_child(child)
		child.queue_free()
	var action_names: Array[String] = ActionCatalog.RESPONSES if accusation != null else ActionCatalog.PRIMARY_ACTIONS
	var response_to := accusation.id if accusation != null else ""
	for action_type in action_names:
		var button := Button.new()
		button.text = ActionCatalog.label(action_type)
		button.custom_minimum_size = Vector2(180, 36)
		button.pressed.connect(_choose_action.bind(action_type, npc.id, response_to))
		action_grid.add_child(button)
	menu_panel.visible = true
	prompt.visible = false
	modal_changed.emit(true)
	(action_grid.get_child(0) as Button).grab_focus()


func close_menu() -> void:
	menu_panel.visible = false
	menu_target_id = ""
	modal_changed.emit(is_modal())


func close_all() -> void:
	menu_panel.visible = false
	menu_target_id = ""
	summary_panel.visible = false
	modal_changed.emit(false)


func show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	toast_timer.start()


func show_offline_summary(world: WorldState, events: Array[WorldAction]) -> void:
	var affected: Dictionary = {}
	var exact_lines: Array[String] = []
	for action in events:
		var npc: NPCData = world.npcs[action.target_id]
		affected[npc.id] = npc
		exact_lines.append("%s: %s [actual ECHO, perceived PLAYER; utility %.3f]" % [npc.display_name, action.action_type, float(action.metadata.get("utility_score", 0.0))])
	var consequence_lines: Array[String] = ["%d event(s) happened while you were away." % events.size(), ""]
	for npc: NPCData in affected.values():
		var consequence := "remembers you differently."
		if npc.collision_state == "STRONG":
			consequence = "seems confused by you."
		elif str(npc.current_state["mood"]) == "AFRAID":
			consequence = "seems afraid of you."
		elif str(npc.current_state["mood"]) in ["ANGRY", "SUSPICIOUS"]:
			consequence = "is upset with you."
		else:
			var net_trust := 0.0
			for action in events:
				if action.target_id == npc.id:
					net_trust += float(action.relationship_effects.get("trust", 0.0))
			consequence = "trusts you less." if net_trust < 0.0 else "seems warmer toward you."
		consequence_lines.append("- %s %s" % [npc.display_name, consequence])
	summary_text.text = "\n".join(consequence_lines)
	summary_debug.text = "\n".join(exact_lines)
	_summary_toggle.button_pressed = false
	summary_debug_scroll.visible = false
	summary_panel.visible = true
	prompt.visible = false
	modal_changed.emit(true)


func _choose_action(action_type: String, npc_id: String, response_to: String) -> void:
	close_menu()
	action_requested.emit(action_type, npc_id, response_to)


func _hide_toast() -> void:
	toast.visible = false


func _toggle_summary_debug(enabled: bool) -> void:
	summary_debug_scroll.visible = enabled


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var hint := Label.new()
	hint.text = "WASD Move  |  Mouse Look  |  E Interact  |  Esc Cursor  |  F3 Debug  |  F10 Save & Quit"
	hint.add_theme_font_size_override("font_size", 14)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 14
	hint.anchor_right = 1.0
	hint.offset_right = -14
	hint.offset_top = -36
	hint.offset_bottom = -6
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	clock_label = Label.new()
	clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock_label.offset_left = -350
	clock_label.offset_right = -14
	clock_label.offset_top = 12
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clock_label)
	prompt = Label.new()
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -300
	prompt.offset_right = 300
	prompt.offset_top = -65
	prompt.offset_bottom = -35
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt)
	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -340
	toast.offset_right = 340
	toast.offset_top = -150
	toast.offset_bottom = -78
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_font_size_override("font_size", 18)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	root.add_child(toast)
	toast_timer = Timer.new()
	toast_timer.wait_time = 7
	toast_timer.one_shot = true
	toast_timer.timeout.connect(_hide_toast)
	add_child(toast_timer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(420, 0)
	_style_panel(menu_panel)
	menu_panel.visible = false
	center.add_child(menu_panel)
	var content := _padded_content(menu_panel)
	menu_title = Label.new()
	menu_title.add_theme_font_size_override("font_size", 20)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(menu_title)
	dialogue_label = Label.new()
	dialogue_label.custom_minimum_size.x = 390
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(dialogue_label)
	action_grid = GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 12)
	action_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(action_grid)
	var cancel := Button.new()
	cancel.text = "Leave (Esc)"
	cancel.pressed.connect(close_menu)
	content.add_child(cancel)
	var summary_center := CenterContainer.new()
	summary_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(summary_center)
	summary_panel = PanelContainer.new()
	summary_panel.custom_minimum_size.x = 510
	_style_panel(summary_panel)
	summary_panel.visible = false
	summary_center.add_child(summary_panel)
	var summary_content := _padded_content(summary_panel)
	var title := Label.new()
	title.text = "WHILE YOU WERE GONE"
	title.add_theme_font_size_override("font_size", 22)
	summary_content.add_child(title)
	summary_text = Label.new()
	summary_text.custom_minimum_size.x = 470
	summary_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_content.add_child(summary_text)
	_summary_toggle = CheckButton.new()
	_summary_toggle.text = "Show exact events (development debug)"
	_summary_toggle.toggled.connect(_toggle_summary_debug)
	summary_content.add_child(_summary_toggle)
	summary_debug_scroll = ScrollContainer.new()
	summary_debug_scroll.custom_minimum_size = Vector2(470, 160)
	summary_content.add_child(summary_debug_scroll)
	summary_debug = Label.new()
	summary_debug.custom_minimum_size.x = 450
	summary_debug.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_debug.add_theme_font_size_override("font_size", 14)
	summary_debug_scroll.add_child(summary_debug)
	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(close_all)
	summary_content.add_child(continue_button)


func _padded_content(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	return content


func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.97)
	panel.add_theme_stylebox_override("panel", style)
