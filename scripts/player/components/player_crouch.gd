extends Node

@export var collision_shape: CollisionShape3D
@export var camera_pivot: Node3D
@export var visual_capsule: Node3D
@export var crawl_hold_time: float = 0.5
@export var standing_height: float = 1.8
@export var crouch_height: float = 0.9
@export var crawl_height: float = 0.75
@export var standing_camera_height: float = 0.65
@export var crouch_camera_height: float = 0.35
@export var crawl_camera_height: float = 0.15
@export var crouch_speed_multiplier: float = 0.55
@export var crawl_speed_multiplier: float = 0.25
@export var clearance_margin: float = 0.05
@export var crawl_visual_height_offset: float = -0.45
@export var debug_stance: bool = false

enum Stance {
	STANDING,
	CROUCHING,
	CRAWLING
}

var current_stance: int = Stance.STANDING
var crouch_hold_timer: float = 0.0
var can_hold_to_crawl: bool = false
var default_visual_transform: Transform3D


func _ready() -> void:
	if visual_capsule != null:
		default_visual_transform = visual_capsule.transform


func update_stance(player: CharacterBody3D, delta: float, is_crouch_pressed: bool, is_crouch_held: bool) -> void:
	if is_crouch_pressed:
		_handle_crouch_pressed(player)

	if can_hold_to_crawl and is_crouch_held:
		crouch_hold_timer += delta
		if crouch_hold_timer > crawl_hold_time and current_stance == Stance.CROUCHING:
			_set_stance(Stance.CRAWLING)
		return

	if not is_crouch_held:
		crouch_hold_timer = 0.0
		can_hold_to_crawl = false


func try_stand_for_jump(player: CharacterBody3D) -> bool:
	crouch_hold_timer = 0.0
	can_hold_to_crawl = false

	if current_stance == Stance.STANDING:
		return true

	return _try_set_stance_with_clearance(player, Stance.STANDING)


func get_speed_multiplier() -> float:
	if current_stance == Stance.CROUCHING:
		return crouch_speed_multiplier
	if current_stance == Stance.CRAWLING:
		return crawl_speed_multiplier
	return 1.0


func can_sprint() -> bool:
	return current_stance == Stance.STANDING


func get_current_stance_name() -> String:
	if current_stance == Stance.CROUCHING:
		return "CROUCHING"
	if current_stance == Stance.CRAWLING:
		return "CRAWLING"
	return "STANDING"


func reset_after_ledge_climb(player: CharacterBody3D) -> void:
	crouch_hold_timer = 0.0
	can_hold_to_crawl = false
	_try_return_to_highest_valid_stance(player)


func _handle_crouch_pressed(player: CharacterBody3D) -> void:
	crouch_hold_timer = 0.0

	if current_stance == Stance.STANDING:
		can_hold_to_crawl = true
		_debug_print("Requested stance change: STANDING -> CROUCHING")
		_set_stance(Stance.CROUCHING)
	elif current_stance == Stance.CROUCHING:
		can_hold_to_crawl = false
		_debug_print("Requested stance change: CROUCHING -> STANDING")
		_try_set_stance_with_clearance(player, Stance.STANDING)
	elif current_stance == Stance.CRAWLING:
		can_hold_to_crawl = false
		_debug_print("Requested stance change: CRAWLING -> CROUCHING")
		_try_set_stance_with_clearance(player, Stance.CROUCHING)


func _try_return_to_highest_valid_stance(player: CharacterBody3D) -> void:
	if _try_set_stance_with_clearance(player, Stance.STANDING):
		return
	if _try_set_stance_with_clearance(player, Stance.CROUCHING):
		return
	_set_stance(Stance.CRAWLING)


func _try_set_stance_with_clearance(player: CharacterBody3D, stance: int) -> bool:
	var target_height: float = _get_height_for_stance(stance)
	var clearance_result: Dictionary = _get_clearance_for_height(player, target_height)

	if not clearance_result["is_clear"]:
		_debug_blocked_stance(stance, clearance_result)
		return false

	_debug_print("Clearance passed for %s" % _get_stance_name(stance))
	_set_stance(stance)
	return true


func _set_stance(next_stance: int) -> void:
	if current_stance == next_stance:
		return

	current_stance = next_stance
	_apply_stance_shape()


func _apply_stance_shape() -> void:
	var current_height: float = _get_height_for_stance(current_stance)
	var current_camera_height: float = _get_camera_height_for_stance(current_stance)

	collision_shape.position.y = _get_shape_center_y_for_height(current_height)
	_set_capsule_height(collision_shape.shape, current_height)
	camera_pivot.position.y = current_camera_height
	_apply_visual_stance()


func _get_height_for_stance(stance: int) -> float:
	if stance == Stance.CROUCHING:
		return crouch_height
	if stance == Stance.CRAWLING:
		return crawl_height
	return standing_height


func _get_camera_height_for_stance(stance: int) -> float:
	if stance == Stance.CROUCHING:
		return crouch_camera_height
	if stance == Stance.CRAWLING:
		return crawl_camera_height
	return standing_camera_height


func _set_capsule_height(capsule: Resource, height: float) -> void:
	if capsule == null:
		return
	capsule.height = height


func _get_shape_center_y_for_height(height: float) -> float:
	return (height - standing_height) * 0.5


func _apply_visual_stance() -> void:
	if visual_capsule == null:
		return

	visual_capsule.transform = default_visual_transform
	if current_stance == Stance.CROUCHING:
		visual_capsule.scale = default_visual_transform.basis.get_scale() * Vector3(1.0, 0.5, 1.0)
	elif current_stance == Stance.CRAWLING:
		visual_capsule.position.y += crawl_visual_height_offset
		visual_capsule.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))


func _get_clearance_for_height(player: CharacterBody3D, height: float) -> Dictionary:
	if collision_shape == null or collision_shape.shape == null:
		return {
			"is_clear": true,
			"blockers": []
		}

	var test_shape: Shape3D = _create_test_shape(height)
	if test_shape == null:
		return {
			"is_clear": true,
			"blockers": []
		}

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = test_shape
	query.transform = _get_shape_global_transform_for_height(player, height)
	query.exclude = _get_player_exclusion_rids(player)
	query.collision_mask = player.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var blockers: Array[Dictionary] = space_state.intersect_shape(query, 8)
	return {
		"is_clear": blockers.is_empty(),
		"blockers": blockers
	}


func _get_shape_global_transform_for_height(player: CharacterBody3D, height: float) -> Transform3D:
	var local_transform: Transform3D = collision_shape.transform
	local_transform.origin.y = _get_shape_center_y_for_height(height) + clearance_margin * 0.5
	return player.global_transform * local_transform


func _get_player_exclusion_rids(player: CharacterBody3D) -> Array[RID]:
	return [player.get_rid()]


func _create_test_shape(height: float) -> Shape3D:
	var current_capsule := collision_shape.shape as CapsuleShape3D
	if current_capsule != null:
		var test_capsule := CapsuleShape3D.new()
		test_capsule.radius = current_capsule.radius
		test_capsule.height = height + clearance_margin
		return test_capsule

	var current_box := collision_shape.shape as BoxShape3D
	if current_box != null:
		var test_box := BoxShape3D.new()
		test_box.size = Vector3(current_box.size.x, height + clearance_margin, current_box.size.z)
		return test_box

	return null


func _debug_blocked_stance(stance: int, clearance_result: Dictionary) -> void:
	if not debug_stance:
		return

	var blockers: Array = clearance_result["blockers"]
	var blocker_text := "unknown blocker"
	if not blockers.is_empty():
		var first_blocker: Dictionary = blockers[0]
		blocker_text = str(first_blocker.get("collider", "unknown blocker"))

	print("Stance blocked: %s by %s" % [_get_stance_name(stance), blocker_text])


func _debug_print(message: String) -> void:
	if debug_stance:
		print(message)


func _get_stance_name(stance: int) -> String:
	if stance == Stance.CROUCHING:
		return "CROUCHING"
	if stance == Stance.CRAWLING:
		return "CRAWLING"
	return "STANDING"
