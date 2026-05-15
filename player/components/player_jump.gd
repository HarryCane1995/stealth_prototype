extends Node

@export var jump_velocity := 4.5
@export var gravity := 18.0


func apply_vertical_velocity(player: CharacterBody3D, delta: float, wants_jump: bool) -> void:
	if player.is_on_floor():
		if player.velocity.y < 0.0:
			player.velocity.y = 0.0
		if wants_jump:
			player.velocity.y = jump_velocity
	else:
		player.velocity.y -= gravity * delta
