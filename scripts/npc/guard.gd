extends CharacterBody3D

signal player_detected
signal chase_started
signal chase_ended

@export var player_path: NodePath = NodePath("")
@export var wander_speed: float = 2.0
@export var chase_speed: float = 4.5
@export var gravity: float = 18.0
@export var vision_range: float = 6.0
@export var vision_angle_degrees: float = 70.0
@export var catch_distance: float = 1.1
@export var wander_area_half_size: Vector2 = Vector2(20.0, 20.0)
@export var new_wander_target_distance: float = 0.5
@export var collision_turn_distance: float = 4.0
@export var forget_player_after_seconds: float = 5.0
@export var detection_pause_seconds: float = 1.0
@export var health: int = 1

@onready var guard_vision: GuardVision = $GuardVision
@onready var vision_debug: Node = get_node_or_null("VisionDebug")

var player: Node3D = null
var spawn_position: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO
var is_chasing: bool = false
var wait_timer: float = 0.0
var collision_turn_cooldown: float = 0.0
var time_since_player_seen: float = 0.0
var detection_pause_timer: float = 0.0
var has_started_chase: bool = false
var is_knocked_out: bool = false


func _ready() -> void:
	spawn_position = global_position
	if vision_debug != null:
		vision_debug.call("update_vision", vision_range, vision_angle_degrees)
	if not player_path.is_empty():
		player = get_node_or_null(player_path) as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	_pick_new_wander_target()


func _physics_process(delta: float) -> void:
	if is_knocked_out:
		return
	if player == null:
		return

	if collision_turn_cooldown > 0.0:
		collision_turn_cooldown -= delta

	var can_see_player: bool = guard_vision.can_see_player(self, player, vision_range, vision_angle_degrees)
	if can_see_player:
		if not is_chasing:
			_start_detection_pause()
		time_since_player_seen = 0.0
	elif is_chasing:
		time_since_player_seen += delta
		if time_since_player_seen >= forget_player_after_seconds:
			_forget_player()

	if is_chasing:
		_update_chase(delta)
	else:
		_wander(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()
	if not is_chasing:
		_turn_90_degrees_after_collision()

	if is_chasing and global_position.distance_to(player.global_position) <= catch_distance:
		get_tree().reload_current_scene()


func take_damage(amount: int) -> void:
	if is_knocked_out:
		return

	health -= amount
	print("Guard took %s damage. Health: %s" % [amount, health])
	if health <= 0:
		_knock_out()


func _knock_out() -> void:
	is_knocked_out = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	hide()
	$CollisionShape3D.set_deferred("disabled", true)
	print("Guard knocked out")


func _wander(delta: float) -> void:
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return

	_move_toward(wander_target, wander_speed)

	if global_position.distance_to(wander_target) <= new_wander_target_distance:
		wait_timer = randf_range(0.4, 1.2)
		_pick_new_wander_target()


func _chase_player() -> void:
	_move_toward(player.global_position, chase_speed)


func _start_detection_pause() -> void:
	is_chasing = true
	has_started_chase = false
	detection_pause_timer = detection_pause_seconds
	velocity.x = 0.0
	velocity.z = 0.0
	player_detected.emit()


func _update_chase(delta: float) -> void:
	if detection_pause_timer > 0.0:
		detection_pause_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return

	if not has_started_chase:
		has_started_chase = true
		chase_started.emit()

	_chase_player()


func _forget_player() -> void:
	is_chasing = false
	has_started_chase = false
	detection_pause_timer = 0.0
	time_since_player_seen = 0.0
	_pick_new_wander_target()
	chase_ended.emit()


func _move_toward(target: Vector3, speed: float) -> void:
	var direction: Vector3 = target - global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	direction = direction.normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	look_at(global_position + direction, Vector3.UP)


func _pick_new_wander_target() -> void:
	var random_offset: Vector3 = Vector3(
		randf_range(-wander_area_half_size.x, wander_area_half_size.x),
		0.0,
		randf_range(-wander_area_half_size.y, wander_area_half_size.y)
	)
	wander_target = spawn_position + random_offset


func _turn_90_degrees_after_collision() -> void:
	if collision_turn_cooldown > 0.0:
		return
	if not _has_wall_collision():
		return

	var turn_direction: float = 1.0 if randf() > 0.5 else -1.0
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var new_direction: Vector3 = forward.rotated(Vector3.UP, deg_to_rad(90.0) * turn_direction)
	wander_target = global_position + new_direction * collision_turn_distance
	wait_timer = 0.0
	collision_turn_cooldown = 0.4


func _has_wall_collision() -> bool:
	for index in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(index)
		if absf(collision.get_normal().y) < 0.5:
			return true

	return false
