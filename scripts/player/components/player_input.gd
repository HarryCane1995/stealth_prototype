extends Node


func get_move_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint")


func wants_jump() -> bool:
	return Input.is_action_just_pressed("jump")


func wants_interact() -> bool:
	return Input.is_action_just_pressed("interact")


func wants_crouch_drop() -> bool:
	return Input.is_action_just_pressed("crouch")


func wants_crouch_pressed() -> bool:
	return Input.is_action_just_pressed("crouch")


func is_crouch_held() -> bool:
	return Input.is_action_pressed("crouch")


func is_crouching() -> bool:
	return is_crouch_held()


func is_aiming() -> bool:
	return Input.is_action_pressed("aim")
