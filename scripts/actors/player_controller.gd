extends CharacterBody3D
class_name PlayerController

# A brisk walk and 1.7x run. Cadence is matched to actual displacement by PlayerVisual.
@export_range(0.5, 8.0, 0.1) var walk_speed := 3.4
@export_range(1.6, 1.9, 0.05) var run_multiplier := 1.7
@export_range(2.0, 10.0, 0.1) var jump_velocity := 4.8
@export_range(1.0, 30.0, 0.5) var facing_response := 12.0
const MOUSE_SENSITIVITY := 0.0025
const MIN_PITCH := -0.65
const MAX_PITCH := 0.28
var controls_enabled := true
var preview_locked := false
var movement_input := Vector2.ZERO
var run_requested := false
var horizontal_speed := 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var body_visual: Node3D = $Body
@onready var visual: PlayerVisual = $Body/VisualRoot


func _ready() -> void:
	_ensure_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY,
			MIN_PITCH, MAX_PITCH
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Movement input cancels an animation preview immediately.
	if preview_locked and Input.get_vector("move_left", "move_right", "move_forward", "move_back").length_squared() > 0.01:
		visual.clear_preview()
	movement_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls_enabled and not preview_locked else Vector2.ZERO
	run_requested = controls_enabled and not preview_locked and Input.is_action_pressed("run")
	var direction := Basis(Vector3.UP, camera_pivot.rotation.y) * Vector3(movement_input.x, 0.0, movement_input.y)
	var speed := walk_speed * (run_multiplier if run_requested else 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif controls_enabled and not preview_locked and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0
	move_and_slide()
	# Use resolved velocity so walking into a wall cannot keep running in place.
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.1:
		var yaw := atan2(-velocity.x, -velocity.z)
		body_visual.rotation.y = lerp_angle(body_visual.rotation.y, yaw, 1.0 - exp(-facing_response * delta))


func _ensure_input_actions() -> void:
	var key_actions: Dictionary = {
		"move_left": KEY_A, "move_right": KEY_D,
		"move_forward": KEY_W, "move_back": KEY_S,
		"interact": KEY_E, "run": KEY_SHIFT, "jump": KEY_SPACE,
	}
	for action_name: String in key_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(key_actions[action_name])
		if not InputMap.action_has_event(action_name, key_event):
			InputMap.action_add_event(action_name, key_event)
