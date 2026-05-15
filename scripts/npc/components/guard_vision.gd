class_name GuardVision
extends Node


func can_see_player(guard: CharacterBody3D, player: Node3D, vision_range: float, vision_angle_degrees: float) -> bool:
	var to_player: Vector3 = player.global_position - guard.global_position
	var flat_to_player: Vector3 = Vector3(to_player.x, 0.0, to_player.z)
	var distance_to_player: float = flat_to_player.length()

	if distance_to_player > vision_range:
		return false
	if distance_to_player <= 0.01:
		return true

	var forward: Vector3 = -guard.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var angle_to_player: float = forward.angle_to(flat_to_player.normalized())
	var half_vision_angle: float = deg_to_rad(vision_angle_degrees * 0.5)
	if angle_to_player > half_vision_angle:
		return false

	return _has_line_of_sight_to_player(guard, player)


func _has_line_of_sight_to_player(guard: CharacterBody3D, player: Node3D) -> bool:
	var space_state: PhysicsDirectSpaceState3D = guard.get_world_3d().direct_space_state
	var from: Vector3 = guard.global_position + Vector3.UP * 1.0
	var to: Vector3 = player.global_position + Vector3.UP * 1.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [guard]

	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	var collider: Object = hit.get("collider") as Object
	return _is_player_or_player_child(collider, player)


func _is_player_or_player_child(collider: Object, player: Node3D) -> bool:
	if collider == player:
		return true
	if not (collider is Node):
		return false

	var node: Node = collider as Node
	while node != null:
		if node == player:
			return true
		if node.is_in_group("player"):
			return true
		node = node.get_parent()

	return false
