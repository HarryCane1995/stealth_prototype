extends Node

@export var camera_pivot: Node3D
@export var camera: Camera3D
@export var mouse_sensitivity := 0.0025
@export var starting_camera_pitch_degrees := -10.0
@export var normal_camera_position := Vector3(1.0488209, 0.65, 0.0)
@export var aim_camera_position := Vector3(1.35, 0.65, -1.25)
@export var normal_fov := 70.0
@export var aim_fov := 55.0
@export var aim_transition_speed := 8.0

const MIN_CAMERA_PITCH := deg_to_rad(-65.0)
const MAX_CAMERA_PITCH := deg_to_rad(35.0)


func setup() -> void:
	camera_pivot.rotation.x = deg_to_rad(starting_camera_pitch_degrees)
	camera_pivot.position = normal_camera_position
	if camera != null:
		camera.fov = normal_fov


func handle_mouse_look(player: CharacterBody3D, event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	player.rotate_y(-event.relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)


func update_aim_camera(delta: float, is_aiming: bool) -> void:
	if camera_pivot == null:
		return

	var target_position := aim_camera_position if is_aiming else normal_camera_position
	target_position.y = camera_pivot.position.y
	var transition_weight: float = 1.0 - exp(-aim_transition_speed * delta)
	camera_pivot.position = camera_pivot.position.lerp(target_position, transition_weight)

	if camera != null:
		var target_fov := aim_fov if is_aiming else normal_fov
		camera.fov = lerpf(camera.fov, target_fov, transition_weight)
