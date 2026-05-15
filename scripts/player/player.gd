extends CharacterBody3D

@onready var player_input = $Components/PlayerInput
@onready var player_movement = $Components/PlayerMovement
@onready var player_jump = $Components/PlayerJump
@onready var player_mouse_look = $Components/PlayerMouseLook
@onready var player_crouch = $Components/PlayerCrouch


func _ready() -> void:
	player_mouse_look.setup()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	player_mouse_look.handle_mouse_look(self, event)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	player_crouch.update_crouch(player_input.is_crouching())
	player_movement.apply_horizontal_velocity(self, player_input.get_move_direction(), player_input.is_sprinting())
	player_jump.apply_vertical_velocity(self, delta, player_input.wants_jump())
	move_and_slide()
