extends Node

@export var collision_shape: CollisionShape3D
@export var visual_mesh: MeshInstance3D
@export var camera_pivot: Node3D
@export var standing_height := 1.8
@export var crouching_height := 0.9
@export var standing_camera_height := 0.65
@export var crouching_camera_height := 0.35


func update_crouch(is_crouching: bool) -> void:
	var current_height := crouching_height if is_crouching else standing_height
	var current_camera_height := crouching_camera_height if is_crouching else standing_camera_height

	_set_capsule_height(collision_shape.shape, current_height)
	_set_capsule_height(visual_mesh.mesh, current_height)
	camera_pivot.position.y = current_camera_height


func _set_capsule_height(capsule, height: float) -> void:
	if capsule == null:
		return
	capsule.height = height
