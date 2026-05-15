extends Node

@export var jump_velocity: float = 4.5
@export var gravity: float = 18.0
@export var extra_jumps: int = 1

var jumps_left: int = 0


func apply_vertical_velocity(player: CharacterBody3D, delta: float, wants_jump: bool) -> void:
	if player.is_on_floor():
		jumps_left = extra_jumps
		if player.velocity.y < 0.0:
			player.velocity.y = 0.0
		if wants_jump:
			player.velocity.y = jump_velocity
	else:
		if wants_jump and jumps_left > 0:
			player.velocity.y = jump_velocity
			jumps_left -= 1
		player.velocity.y -= gravity * delta
