extends Node

@export var collision_shape: CollisionShape3D
@export var camera_pivot: Node3D
@export var standing_height: float = 1.8
@export var crouching_height: float = 0.9
@export var standing_camera_height: float = 0.65
@export var crouching_camera_height: float = 0.35


func update_crouch(is_crouching: bool) -> void:
	var current_height: float = crouching_height if is_crouching else standing_height
	var current_camera_height: float = crouching_camera_height if is_crouching else standing_camera_height

	_set_capsule_height(collision_shape.shape, current_height)
	camera_pivot.position.y = current_camera_height


func _set_capsule_height(capsule: Resource, height: float) -> void:
	if capsule == null:
		return
	capsule.height = height
