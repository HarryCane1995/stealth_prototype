extends Node

@export var collision_shape: CollisionShape3D
@export var enabled: bool = true

@export_group("Detection")
@export var min_ledge_height: float = 0.45
@export var max_ledge_height: float = 2.25
@export var wall_check_height: float = 0.45
@export var wall_check_distance: float = 0.75
@export var top_check_extra_height: float = 0.35
@export var max_landing_slope_degrees: float = 30.0
@export var max_wall_normal_y: float = 0.2
@export var min_wall_facing_dot: float = 0.55
@export var auto_climb_max_height: float = 0.85
@export var landing_probe_start_offset: float = 0.05
@export var landing_probe_end_offset: float = 2.0
@export var landing_probe_steps: int = 6

@export_group("Movement")
@export var climb_duration: float = 0.35
@export var landing_floor_clearance: float = 0.05
@export var post_climb_cooldown: float = 0.25
@export var hang_wall_offset: float = 0.42
@export var hang_below_top: float = 0.65
@export var hang_side_speed: float = 2.0
@export var drop_push_back_speed: float = 1.5

@export_group("Debug")
@export var debug_prints: bool = false

enum LedgeState {
	FREE,
	HANGING,
	CLIMBING
}

var _state: int = LedgeState.FREE
var _climb_time: float = 0.0
var _cooldown_left: float = 0.0
var _climb_start_position: Vector3 = Vector3.ZERO
var _climb_target_position: Vector3 = Vector3.ZERO
var _hanging_ledge: Dictionary = {}
var _hang_wall_normal: Vector3 = Vector3.ZERO
var _hang_side_direction: Vector3 = Vector3.ZERO

const CLIMB_TYPE_AUTO := "auto_climb"
const CLIMB_TYPE_HANG := "hang_climb"
const CLIMB_TYPE_DIRECT := "direct_climb"


func is_climbing() -> bool:
	return _state == LedgeState.CLIMBING


func is_hanging() -> bool:
	return _state == LedgeState.HANGING


func is_active() -> bool:
	return _state != LedgeState.FREE


func is_auto_climb_ledge(ledge: Dictionary) -> bool:
	return _get_ledge_climb_type(ledge) == CLIMB_TYPE_AUTO and _get_ledge_height(ledge) <= auto_climb_max_height


func is_hang_climb_ledge(ledge: Dictionary) -> bool:
	return _get_ledge_climb_type(ledge) == CLIMB_TYPE_HANG


func is_direct_climb_ledge(ledge: Dictionary) -> bool:
	return _get_ledge_climb_type(ledge) == CLIMB_TYPE_DIRECT


func update_active_movement(player: CharacterBody3D, delta: float, input_direction: Vector2, wants_drop: bool) -> bool:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if _state == LedgeState.HANGING:
		_update_hang(player, delta, input_direction, wants_drop)
		return true

	if _state == LedgeState.CLIMBING:
		_update_climb(player, delta)
		return true

	return false


func get_climbable_ledge(player: CharacterBody3D, input_direction: Vector2) -> Dictionary:
	if not enabled or _state != LedgeState.FREE or _cooldown_left > 0.0:
		return {}

	var climb_direction := _get_climb_direction(player, input_direction)
	if climb_direction == Vector3.ZERO:
		return {}

	return _find_ledge(player, climb_direction)


func grab_ledge(player: CharacterBody3D, ledge: Dictionary) -> bool:
	if ledge.is_empty():
		return false

	_state = LedgeState.HANGING
	_hanging_ledge = ledge
	_hang_wall_normal = ledge["wall_normal"]
	_hang_side_direction = ledge["side_direction"]

	player.global_position = ledge["hang_position"]
	player.velocity = Vector3.ZERO

	if debug_prints:
		print("Grabbed ledge. Height: ", snappedf(ledge["height"], 0.01))

	return true


func start_climb(player: CharacterBody3D, ledge: Dictionary = {}) -> bool:
	var climb_ledge := ledge
	if climb_ledge.is_empty():
		climb_ledge = _hanging_ledge
	if climb_ledge.is_empty():
		return false

	var target_position: Vector3 = climb_ledge["target_position"]
	var ledge_height: float = climb_ledge["height"]

	_state = LedgeState.CLIMBING
	_climb_time = 0.0
	_climb_start_position = player.global_position
	_climb_target_position = target_position
	player.velocity = Vector3.ZERO

	if debug_prints:
		print("Started ledge climb. Height: ", snappedf(ledge_height, 0.01))

	return true


func drop_from_ledge(player: CharacterBody3D, apply_push_back: bool = true) -> void:
	_state = LedgeState.FREE
	_hanging_ledge = {}
	_cooldown_left = post_climb_cooldown
	player.velocity = _hang_wall_normal * drop_push_back_speed if apply_push_back else Vector3.ZERO

	if debug_prints:
		print("Dropped from ledge.")


func _update_hang(player: CharacterBody3D, delta: float, input_direction: Vector2, wants_drop: bool) -> void:
	player.velocity = Vector3.ZERO

	if wants_drop:
		drop_from_ledge(player)
		return

	if not _refresh_hanging_ledge(player):
		drop_from_ledge(player)
		return

	var side_input := input_direction.x
	if absf(side_input) > 0.1 and _hang_side_direction != Vector3.ZERO:
		var motion := -_hang_side_direction * side_input * hang_side_speed * delta
		if _can_shimmy(player, motion):
			player.global_position += motion
			_refresh_hanging_ledge(player)


func _can_shimmy(player: CharacterBody3D, motion: Vector3) -> bool:
	if player.test_move(player.global_transform, motion):
		return false

	var original_position: Vector3 = player.global_position
	player.global_position += motion
	var has_ledge: bool = _refresh_hanging_ledge(player)
	player.global_position = original_position

	return has_ledge


func _update_climb(player: CharacterBody3D, delta: float) -> void:
	_climb_time += delta
	var duration := maxf(climb_duration, 0.01)
	var progress := clampf(_climb_time / duration, 0.0, 1.0)
	var eased_progress := smoothstep(0.0, 1.0, progress)

	player.global_position = _climb_start_position.lerp(_climb_target_position, eased_progress)
	player.velocity = Vector3.ZERO

	if progress >= 1.0:
		_finish_climb(player)


func _finish_climb(player: CharacterBody3D) -> void:
	_state = LedgeState.FREE
	_hanging_ledge = {}
	_cooldown_left = post_climb_cooldown
	player.global_position = _climb_target_position
	player.velocity = Vector3.ZERO

	if debug_prints:
		print("Finished ledge climb.")


func _get_climb_direction(player: CharacterBody3D, input_direction: Vector2) -> Vector3:
	if input_direction.length() > 0.1:
		var desired_direction := player.global_transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)
		desired_direction.y = 0.0
		if desired_direction.length() > 0.001:
			return desired_direction.normalized()

	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() > 0.001:
		return forward.normalized()

	return Vector3.ZERO


func _find_ledge(player: CharacterBody3D, climb_direction: Vector3) -> Dictionary:
	var space_state := player.get_world_3d().direct_space_state
	var player_foot_y := _get_player_foot_y(player)

	var wall_ray_start := Vector3(player.global_position.x, player_foot_y + wall_check_height, player.global_position.z)
	var wall_ray_end := wall_ray_start + climb_direction * wall_check_distance
	var wall_hit := _raycast(space_state, player, wall_ray_start, wall_ray_end)

	if wall_hit.is_empty():
		return {}

	var ledge_body: Node = wall_hit["collider"] as Node
	var climb_type := _get_climb_type_for_body(ledge_body)
	if climb_type == "":
		return {}

	var wall_normal: Vector3 = wall_hit["normal"]
	if absf(wall_normal.y) > max_wall_normal_y:
		return {}
	if wall_normal.dot(-climb_direction) < min_wall_facing_dot:
		return {}

	var wall_position: Vector3 = wall_hit["position"]
	var side_direction := wall_normal.cross(Vector3.UP).normalized()
	var upper_ray_y := player_foot_y + max_ledge_height + 0.05
	var upper_ray_start := Vector3(player.global_position.x, upper_ray_y, player.global_position.z)
	var upper_ray_end := upper_ray_start + climb_direction * wall_check_distance
	if not _raycast(space_state, player, upper_ray_start, upper_ray_end).is_empty():
		return {}

	var landing: Dictionary = _find_landing_point(space_state, player, player_foot_y, wall_position, climb_direction, ledge_body, climb_type)
	if landing.is_empty():
		return {}

	var top_position: Vector3 = landing["position"]
	var ledge_height: float = landing["height"]
	var target_position: Vector3 = _get_landing_position(top_position)

	return {
		"height": ledge_height,
		"target_position": target_position,
		"hang_position": _get_hang_position(wall_position, top_position, wall_normal),
		"wall_normal": wall_normal,
		"side_direction": side_direction,
		"climb_type": climb_type,
		"climb_body": ledge_body
	}


func _find_landing_point(
	space_state: PhysicsDirectSpaceState3D,
	player: CharacterBody3D,
	player_foot_y: float,
	wall_position: Vector3,
	climb_direction: Vector3,
	ledge_body: Node,
	climb_type: String
) -> Dictionary:
	var probe_count: int = landing_probe_steps if landing_probe_steps > 0 else 1
	var min_landing_normal_y: float = cos(deg_to_rad(max_landing_slope_degrees))

	for probe_index in range(probe_count):
		var offset: float = landing_probe_start_offset
		if probe_count > 1:
			var probe_progress: float = float(probe_index) / float(probe_count - 1)
			offset = lerpf(landing_probe_start_offset, landing_probe_end_offset, probe_progress)

		var probe_position: Vector3 = wall_position + climb_direction * offset
		var top_ray_start: Vector3 = Vector3(probe_position.x, player_foot_y + max_ledge_height + top_check_extra_height, probe_position.z)
		var top_ray_end: Vector3 = Vector3(probe_position.x, player_foot_y + min_ledge_height, probe_position.z)
		var top_hit: Dictionary = _raycast(space_state, player, top_ray_start, top_ray_end)

		if top_hit.is_empty():
			continue

		var landing_body: Node = top_hit["collider"] as Node
		if not _is_matching_climb_surface(landing_body, ledge_body, climb_type):
			continue

		var landing_normal: Vector3 = top_hit["normal"]
		if landing_normal.dot(Vector3.UP) < min_landing_normal_y:
			continue

		var top_position: Vector3 = top_hit["position"]
		var ledge_height: float = top_position.y - player_foot_y
		if ledge_height < min_ledge_height or ledge_height > max_ledge_height:
			continue

		var target_position: Vector3 = _get_landing_position(top_position)
		if not _has_landing_clearance(space_state, player, target_position):
			continue

		return {
			"position": top_position,
			"height": ledge_height
		}

	return {}


func _refresh_hanging_ledge(player: CharacterBody3D) -> bool:
	if _hang_wall_normal == Vector3.ZERO:
		return false

	var ledge := _find_ledge(player, -_hang_wall_normal)
	if ledge.is_empty() or not is_hang_climb_ledge(ledge):
		return false

	_hanging_ledge = ledge
	_hang_wall_normal = ledge["wall_normal"]
	_hang_side_direction = ledge["side_direction"]
	return true


func _raycast(space_state: PhysicsDirectSpaceState3D, player: CharacterBody3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)


func _has_landing_clearance(space_state: PhysicsDirectSpaceState3D, player: CharacterBody3D, target_position: Vector3) -> bool:
	if collision_shape == null or collision_shape.shape == null:
		return true

	var player_target_transform := player.global_transform
	player_target_transform.origin = target_position

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = player_target_transform * collision_shape.transform
	query.exclude = [player.get_rid()]
	query.collision_mask = player.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	return space_state.intersect_shape(query, 8).is_empty()


func _get_landing_position(landing_point: Vector3) -> Vector3:
	return landing_point + Vector3.UP * (_get_player_half_height() + landing_floor_clearance)


func _get_hang_position(wall_position: Vector3, top_position: Vector3, wall_normal: Vector3) -> Vector3:
	var hang_position := wall_position + wall_normal * hang_wall_offset
	hang_position.y = top_position.y - hang_below_top
	return hang_position


func _get_climb_type_for_body(body: Node) -> String:
	if body == null:
		return ""
	if body.is_in_group(CLIMB_TYPE_AUTO):
		return CLIMB_TYPE_AUTO
	if body.is_in_group(CLIMB_TYPE_HANG):
		return CLIMB_TYPE_HANG
	if body.is_in_group(CLIMB_TYPE_DIRECT):
		return CLIMB_TYPE_DIRECT
	return ""


func _is_matching_climb_surface(landing_body: Node, wall_body: Node, climb_type: String) -> bool:
	if landing_body == null:
		return false
	if landing_body == wall_body:
		return true
	return _get_climb_type_for_body(landing_body) == climb_type


func _get_ledge_climb_type(ledge: Dictionary) -> String:
	if ledge.has("climb_type"):
		var climb_type: String = ledge["climb_type"]
		return climb_type
	return ""


func _get_ledge_height(ledge: Dictionary) -> float:
	if ledge.has("height"):
		var height: float = ledge["height"]
		return height
	return INF


func _get_player_foot_y(player: CharacterBody3D) -> float:
	return player.global_position.y - _get_player_half_height()


func _get_player_half_height() -> float:
	if collision_shape != null:
		var capsule := collision_shape.shape as CapsuleShape3D
		if capsule != null:
			return capsule.height * 0.5

		var box := collision_shape.shape as BoxShape3D
		if box != null:
			return box.size.y * 0.5

	return 0.9
