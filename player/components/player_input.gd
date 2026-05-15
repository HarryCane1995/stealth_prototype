extends Node


func get_move_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint")


func wants_jump() -> bool:
	return Input.is_action_pressed("jump")


func is_crouching() -> bool:
	return Input.is_action_pressed("crouch")
