extends Node

@export var weapon_range: float = 50.0
@export var fire_cooldown: float = 0.25
@export var damage: int = 1
@export var debug_draw_shots: bool = false
@export var camera: Camera3D
@export var weapon_origin: Node3D

var cooldown_timer: float = 0.0

const DEBUG_OBJECT_LIFETIME := 0.75


func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if Input.is_action_just_pressed("shoot"):
		shoot()


func shoot() -> void:
	if cooldown_timer > 0.0:
		return
	if camera == null or weapon_origin == null:
		return

	cooldown_timer = fire_cooldown

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var player: Node = owner
	var camera_aim: Dictionary = _get_camera_aim(space_state, player)
	var target_point: Vector3 = camera_aim["target_point"]
	var weapon_shot: Dictionary = _cast_weapon_ray(space_state, target_point, player)
	var shot_result: Dictionary = weapon_shot["result"]

	if shot_result.is_empty():
		print("Shot missed")
		_debug_show_shot(camera_aim, weapon_shot)
		return

	var hit_object: Object = shot_result["collider"]
	var hit_position: Vector3 = shot_result["position"]
	print("Shot hit: %s at %s" % [hit_object, hit_position])
	_debug_show_shot(camera_aim, weapon_shot)

	if hit_object != null and hit_object.has_method("take_damage"):
		hit_object.call("take_damage", damage)


func _get_camera_aim(space_state: PhysicsDirectSpaceState3D, player: Node) -> Dictionary:
	var camera_start: Vector3 = camera.global_position
	var camera_end: Vector3 = camera_start + (-camera.global_transform.basis.z * weapon_range)
	var query := PhysicsRayQueryParameters3D.create(camera_start, camera_end)
	query.exclude = [player]

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return {
			"start": camera_start,
			"end": camera_end,
			"target_point": camera_end,
			"result": result
		}

	return {
		"start": camera_start,
		"end": camera_end,
		"target_point": result["position"],
		"result": result
	}


func _cast_weapon_ray(space_state: PhysicsDirectSpaceState3D, target_point: Vector3, player: Node) -> Dictionary:
	var shot_start: Vector3 = weapon_origin.global_position
	var shot_direction: Vector3 = target_point - shot_start
	if shot_direction.length() <= 0.01:
		shot_direction = -weapon_origin.global_transform.basis.z
	else:
		shot_direction = shot_direction.normalized()

	var shot_end: Vector3 = shot_start + (shot_direction * weapon_range)
	var query := PhysicsRayQueryParameters3D.create(shot_start, shot_end)
	query.exclude = [player]

	var result: Dictionary = space_state.intersect_ray(query)
	var final_point: Vector3 = shot_end
	if not result.is_empty():
		final_point = result["position"]

	return {
		"start": shot_start,
		"end": shot_end,
		"final_point": final_point,
		"result": result
	}


func _debug_show_shot(camera_aim: Dictionary, weapon_shot: Dictionary) -> void:
	if not debug_draw_shots:
		return

	print("Camera aim ray: %s -> %s, result: %s" % [camera_aim["start"], camera_aim["target_point"], camera_aim["result"]])
	print("Weapon shot ray: %s -> %s, result: %s" % [weapon_shot["start"], weapon_shot["final_point"], weapon_shot["result"]])
	_spawn_debug_line(weapon_shot["start"], weapon_shot["final_point"], Color(1.0, 0.85, 0.1, 1.0))
	_spawn_debug_marker(weapon_shot["final_point"])


func _spawn_debug_marker(position: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	marker.mesh = mesh
	marker.top_level = true
	marker.material_override = _create_debug_material(Color(1.0, 0.0, 0.0, 1.0))
	_add_temporary_debug_node(marker)
	marker.global_position = position


func _spawn_debug_line(start: Vector3, end: Vector3, color: Color) -> void:
	var shot_vector: Vector3 = end - start
	var shot_length: float = shot_vector.length()
	if shot_length <= 0.01:
		return

	var line := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = shot_length
	mesh.radial_segments = 12
	line.mesh = mesh
	line.top_level = true
	line.material_override = _create_debug_material(color)
	_add_temporary_debug_node(line)
	line.global_transform = Transform3D(_basis_from_y_axis(shot_vector.normalized()), start + shot_vector * 0.5)
	print("Debug shot line spawned from %s to %s, length: %s" % [start, end, shot_length])


func _create_debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _basis_from_y_axis(y_axis: Vector3) -> Basis:
	var helper_axis := Vector3.UP
	if absf(y_axis.dot(helper_axis)) > 0.95:
		helper_axis = Vector3.RIGHT

	var x_axis: Vector3 = helper_axis.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _add_temporary_debug_node(node: Node3D) -> void:
	var debug_parent: Node = get_tree().current_scene
	if debug_parent == null:
		debug_parent = owner
	debug_parent.add_child(node)
	get_tree().create_timer(DEBUG_OBJECT_LIFETIME).timeout.connect(Callable(node, "queue_free"))
