extends Node

@export var camera_pivot: Node3D
@export var mouse_sensitivity := 0.0025
@export var starting_camera_pitch_degrees := -10.0

const MIN_CAMERA_PITCH := deg_to_rad(-65.0)
const MAX_CAMERA_PITCH := deg_to_rad(35.0)


func setup() -> void:
	camera_pivot.rotation.x = deg_to_rad(starting_camera_pitch_degrees)


func handle_mouse_look(player: CharacterBody3D, event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	player.rotate_y(-event.relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
