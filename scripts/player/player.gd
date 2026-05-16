extends CharacterBody3D

@onready var player_input = $Components/PlayerInput
@onready var player_movement = $Components/PlayerMovement
@onready var player_jump = $Components/PlayerJump
@onready var player_mouse_look = $Components/PlayerMouseLook
@onready var player_crouch = $Components/PlayerCrouch
@onready var player_ledge_climb = $Components/PlayerLedgeClimb
@onready var ledge_climb_prompt = $InteractionPrompt
@onready var ledge_climb_prompt_label = $InteractionPrompt/PromptLabel

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
	var wants_drop: bool = wants_jump or move_direction.y > 0.5

	if player_ledge_climb.is_hanging():
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

	if player_ledge_climb.update_active_movement(self, delta, move_direction, false):
		_set_ledge_climb_prompt("", false)
		return

	player_crouch.update_crouch(player_input.is_crouching())
	var climbable_ledge: Dictionary = player_ledge_climb.get_climbable_ledge(self, move_direction)
	var can_auto_climb: bool = move_direction.length() > 0.1 and player_ledge_climb.is_auto_climb_ledge(climbable_ledge)
	var can_hang_climb: bool = player_ledge_climb.is_hang_climb_ledge(climbable_ledge)
	var can_direct_climb: bool = player_ledge_climb.is_direct_climb_ledge(climbable_ledge)

	if can_auto_climb:
		_set_ledge_climb_prompt("", false)
		if player_ledge_climb.start_climb(self, climbable_ledge):
			return

	if can_hang_climb:
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

	player_movement.apply_horizontal_velocity(self, move_direction, player_input.is_sprinting())
	player_jump.apply_vertical_velocity(self, delta, wants_jump)
	move_and_slide()


func _set_ledge_climb_prompt(text: String, is_visible: bool) -> void:
	if text != "":
		ledge_climb_prompt_label.text = text
	ledge_climb_prompt.visible = is_visible


func _set_ledge_climb_prompt_visible(is_visible: bool) -> void:
	_set_ledge_climb_prompt("", is_visible)
