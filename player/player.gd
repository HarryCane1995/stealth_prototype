extends CharacterBody3D

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025
@export var starting_camera_pitch_degrees := -10.0
@export var gravity := 18.0

@onready var camera_pivot: Node3D = $CameraPivot

const MIN_CAMERA_PITCH := deg_to_rad(-65.0)
const MAX_CAMERA_PITCH := deg_to_rad(35.0)


func _ready() -> void:
	camera_pivot.rotation.x = deg_to_rad(starting_camera_pitch_degrees)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		input_direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_direction.x += 1.0

	input_direction = input_direction.normalized()

	var move_direction := (global_transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)).normalized()
	var current_speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed

	velocity.x = move_direction.x * current_speed
	velocity.z = move_direction.z * current_speed

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	move_and_slide()
