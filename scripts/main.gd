extends Node3D

@onready var stealth_music: AudioStreamPlayer = $Audio/StealthMusic
@onready var alarm_music: AudioStreamPlayer = $Audio/AlarmMusic
@onready var alarm_sound: AudioStreamPlayer = $Audio/AlarmSound
@onready var guards: Node3D = $Guards


func _ready() -> void:
	_play_stealth_music()

	var guard_nodes: Array[Node] = guards.get_children()
	for guard_index in range(guard_nodes.size()):
		var guard_node: Node = guard_nodes[guard_index]
		guard_node.connect("player_detected", Callable(self, "_on_guard_player_detected"))
		guard_node.connect("chase_started", Callable(self, "_on_guard_chase_started"))
		guard_node.connect("chase_ended", Callable(self, "_on_guard_chase_ended"))


func _on_guard_player_detected() -> void:
	alarm_sound.play()


func _on_guard_chase_started() -> void:
	_play_alarm_music()


func _on_guard_chase_ended() -> void:
	_play_stealth_music()


func _play_stealth_music() -> void:
	alarm_music.stop()
	if not stealth_music.playing:
		stealth_music.play()


func _play_alarm_music() -> void:
	stealth_music.stop()
	if not alarm_music.playing:
		alarm_music.play()
