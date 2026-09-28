extends Node2D
class_name GameManager


@export var world_map := "res://scenes/Levels/World_map/world_map.tscn"
@export_file("*.ogg") var world_music: String
@export_file("*.ogg") var menu_music: String
@export var music_fade_duration := 1.0
@export var hand_tracking_camera_index := 0
@export var default_music_volume := -20.0



@onready var previous_music: AudioStreamPlayer = $PreviousMusic
@onready var next_music: AudioStreamPlayer = $NextMusic

#python

var current_music_path := ""
var active_music_player: AudioStreamPlayer
var inactive_music_player: AudioStreamPlayer
var player_hp: float
var music_volume: float


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	#music_volume = default_music_volume
	#
	#active_music_player = previous_music
	#inactive_music_player = next_music
	#
	#Hud.settings_menu.volume_changed.connect(_on_volume_changed)
	#previous_music.finished.connect(_on_music_finished.bind(previous_music))
	#next_music.finished.connect(_on_music_finished.bind(next_music))
	#transition_to_music(menu_music)




# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	pass

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_volume_changed(value: float):
	music_volume = value
	active_music_player.volume_db = value

func transition_to_music(music_path: String) -> void:
	if music_path == "" or music_path == current_music_path:
		return

	current_music_path = music_path

	var stream := load(music_path)
	if stream == null:
		return

	var old_player := active_music_player
	var new_player := inactive_music_player

	new_player.stream = stream
	new_player.volume_db = music_volume
	new_player.play()

	active_music_player = new_player
	inactive_music_player = old_player

	var tween := create_tween()
	tween.tween_property(old_player, "volume_db", -40.0, music_fade_duration)
	tween.parallel().tween_property(new_player, "volume_db", music_volume, music_fade_duration)

	tween.finished.connect(func():
		old_player.stop()
		old_player.stream = null
	)

func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player != active_music_player:
		return

	if player.stream == null:
		return

	await get_tree().create_timer(5.0).timeout

	if player != active_music_player:
		return

	if player.stream == null:
		return

	player.play()
