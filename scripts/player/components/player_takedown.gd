extends Node

@export var takedown_range: float = 2.0
@export var behind_threshold: float = -0.35
@export var debug_enabled: bool = false

var nearby_guards: Array[Node3D] = []
var takedown_area: Area3D = null


func _ready() -> void:
	takedown_area = get_node_or_null("../../TakedownArea") as Area3D
	if takedown_area == null:
		push_warning("PlayerTakedown could not find ../../TakedownArea.")
		return

	takedown_area.monitoring = true
	takedown_area.body_entered.connect(_on_takedown_area_body_entered)
	takedown_area.body_exited.connect(_on_takedown_area_body_exited)

	for body in takedown_area.get_overlapping_bodies():
		_on_takedown_area_body_entered(body)


func try_takedown(player: CharacterBody3D) -> bool:
	var guard := _get_nearest_valid_guard(player)
	if guard == null:
		if debug_enabled:
			print("No valid takedown target.")
		return false

	if guard.has_method("take_takedown"):
		guard.call("take_takedown")
		if debug_enabled:
			print("Takedown used on: ", guard.name)
		return true

	return false


func has_valid_target(player: CharacterBody3D) -> bool:
	return _get_nearest_valid_guard(player) != null


func _on_takedown_area_body_entered(body: Node3D) -> void:
	if not _is_guard_candidate(body):
		return
	if not nearby_guards.has(body):
		nearby_guards.append(body)


func _on_takedown_area_body_exited(body: Node3D) -> void:
	nearby_guards.erase(body)


func _get_nearest_valid_guard(player: CharacterBody3D) -> Node3D:
	var nearest_guard: Node3D = null
	var nearest_distance: float = INF

	for guard in nearby_guards:
		if not is_instance_valid(guard):
			continue
		if not _is_valid_takedown_target(player, guard):
			continue

		var distance := player.global_position.distance_to(guard.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_guard = guard

	return nearest_guard


func _is_valid_takedown_target(player: CharacterBody3D, guard: Node3D) -> bool:
	if not _is_guard_candidate(guard):
		return false
	if guard.get("is_knocked_out") == true:
		return false
	if player.global_position.distance_to(guard.global_position) > takedown_range:
		return false

	var guard_forward := -guard.global_transform.basis.z
	guard_forward.y = 0.0
	if guard_forward.length() <= 0.01:
		return false
	guard_forward = guard_forward.normalized()

	var to_player := player.global_position - guard.global_position
	to_player.y = 0.0
	if to_player.length() <= 0.01:
		return false
	to_player = to_player.normalized()

	return guard_forward.dot(to_player) < behind_threshold


func _is_guard_candidate(body: Node) -> bool:
	if body == null:
		return false
	return body.is_in_group("guards") and body.has_method("take_takedown")
