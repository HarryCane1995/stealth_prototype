extends CharacterBody3D

@onready var player_input = $Components/PlayerInput
@onready var player_movement = $Components/PlayerMovement
@onready var player_jump = $Components/PlayerJump
@onready var player_mouse_look = $Components/PlayerMouseLook
@onready var player_crouch = $Components/PlayerCrouch
@onready var player_ledge_climb = $Components/PlayerLedgeClimb
@onready var player_takedown = $Components/PlayerTakedown
@onready var ledge_climb_prompt = $InteractionPrompt
@onready var ledge_climb_prompt_label = $InteractionPrompt/PromptLabel

const TAKEDOWN_PROMPT_TEXT := "F - Оглушить"
const GRAB_PROMPT_TEXT := "Повиснуть - F"
const CLIMB_PROMPT_TEXT := "Взобраться - F"


func _ready() -> void:
	player_mouse_look.setup()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_ledge_climb_prompt_visible(false)


func _unhandled_input(event: InputEvent) -> void:
	player_mouse_look.handle_mouse_look(self, event)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	var move_direction: Vector2 = player_input.get_move_direction()
	var wants_jump: bool = player_input.wants_jump()
	var wants_interact: bool = player_input.wants_interact()
	var wants_crouch_drop: bool = player_input.wants_crouch_drop()
	var wants_crouch_pressed: bool = player_input.wants_crouch_pressed()
	var wants_drop: bool = wants_jump or move_direction.y > 0.5

	if player_ledge_climb.is_hanging():
		_update_aim_camera(delta, false)
		_set_ledge_climb_prompt(CLIMB_PROMPT_TEXT, true)
		if wants_crouch_drop:
			_set_ledge_climb_prompt("", false)
			player_ledge_climb.drop_from_ledge(self, false)
			return
		if wants_interact:
			if player_ledge_climb.start_climb(self):
				return
		player_ledge_climb.update_active_movement(self, delta, move_direction, wants_drop)
		return

	var was_climbing: bool = player_ledge_climb.is_climbing()
	if player_ledge_climb.update_active_movement(self, delta, move_direction, false):
		_update_aim_camera(delta, false)
		if was_climbing and not player_ledge_climb.is_climbing():
			player_crouch.reset_after_ledge_climb(self)
		_set_ledge_climb_prompt("", false)
		return

	var can_takedown: bool = player_takedown.has_valid_target(self)
	if can_takedown and wants_interact and player_takedown.try_takedown(self):
		_set_ledge_climb_prompt("", false)
		return

	player_crouch.update_stance(self, delta, wants_crouch_pressed, player_input.is_crouch_held())
	_update_aim_camera(delta, _can_use_aim_camera())
	var climbable_ledge: Dictionary = player_ledge_climb.get_climbable_ledge(self, move_direction)
	var can_auto_climb: bool = move_direction.length() > 0.1 and player_ledge_climb.is_auto_climb_ledge(climbable_ledge)
	var can_hang_climb: bool = player_ledge_climb.is_hang_climb_ledge(climbable_ledge)
	var can_direct_climb: bool = player_ledge_climb.is_direct_climb_ledge(climbable_ledge)

	if can_auto_climb:
		_set_ledge_climb_prompt("", false)
		if player_ledge_climb.start_climb(self, climbable_ledge):
			return

	if can_takedown:
		_set_ledge_climb_prompt(TAKEDOWN_PROMPT_TEXT, true)
	elif can_hang_climb:
		_set_ledge_climb_prompt(GRAB_PROMPT_TEXT, true)
	elif can_direct_climb:
		_set_ledge_climb_prompt(CLIMB_PROMPT_TEXT, true)
	else:
		_set_ledge_climb_prompt("", false)

	if can_hang_climb and wants_interact:
		_set_ledge_climb_prompt(CLIMB_PROMPT_TEXT, true)
		if player_ledge_climb.grab_ledge(self, climbable_ledge):
			return

	if can_direct_climb and wants_interact:
		_set_ledge_climb_prompt("", false)
		if player_ledge_climb.start_climb(self, climbable_ledge):
			return

	if wants_jump and not player_crouch.can_sprint():
		wants_jump = player_crouch.try_stand_for_jump(self)

	var stance_speed_multiplier: float = player_crouch.get_speed_multiplier()
	var can_sprint: bool = player_input.is_sprinting() and player_crouch.can_sprint()
	player_movement.apply_horizontal_velocity(self, move_direction, can_sprint, stance_speed_multiplier)
	player_jump.apply_vertical_velocity(self, delta, wants_jump)
	move_and_slide()


func _set_ledge_climb_prompt(text: String, is_visible: bool) -> void:
	if text != "":
		ledge_climb_prompt_label.text = text
	ledge_climb_prompt.visible = is_visible


func _set_ledge_climb_prompt_visible(is_visible: bool) -> void:
	_set_ledge_climb_prompt("", is_visible)


func _update_aim_camera(delta: float, can_aim: bool) -> void:
	player_mouse_look.update_aim_camera(delta, can_aim and player_input.is_aiming())


func _can_use_aim_camera() -> bool:
	return not player_crouch.is_crawling()
