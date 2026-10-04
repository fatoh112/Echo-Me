extends CharacterBody3D
class_name PlayerController

const MOVE_SPEED := 5.0
const MOUSE_SENSITIVITY := 0.0025
const MIN_PITCH := -0.65
const MAX_PITCH := 0.28
var controls_enabled := true

@onready var camera_pivot: Node3D = $CameraPivot
@onready var body_visual: Node3D = $Body


func _ready() -> void:
	_ensure_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY,
			MIN_PITCH,
			MAX_PITCH
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls_enabled else Vector2.ZERO
	var camera_yaw := camera_pivot.rotation.y
	var move_basis := Basis(Vector3.UP, camera_yaw)
	var move_direction := move_basis * Vector3(input_vector.x, 0.0, input_vector.y)
	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()

	velocity.x = move_direction.x * MOVE_SPEED
	velocity.z = move_direction.z * MOVE_SPEED
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
	if move_direction.length_squared() > 0.001:
		body_visual.rotation.y = lerp_angle(
			body_visual.rotation.y,
			atan2(-move_direction.x, -move_direction.z),
			12.0 * delta
		)


func _ensure_input_actions() -> void:
	var key_actions: Dictionary = {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"interact": KEY_E,
	}
	for action_name: String in key_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(key_actions[action_name])
		InputMap.action_add_event(action_name, key_event)
