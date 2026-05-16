extends Node

@export var walk_speed := 5.0
@export var sprint_speed := 8.0


func apply_horizontal_velocity(
	player: CharacterBody3D,
	input_direction: Vector2,
	is_sprinting: bool,
	speed_multiplier: float = 1.0
) -> void:
	var move_direction := (player.global_transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)).normalized()
	var current_speed := sprint_speed if is_sprinting else walk_speed
	current_speed *= speed_multiplier

	player.velocity.x = move_direction.x * current_speed
	player.velocity.z = move_direction.z * current_speed
