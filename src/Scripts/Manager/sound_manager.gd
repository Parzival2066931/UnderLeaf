extends Node

@export_group("Musiques")
@export var menu_music: AudioStream
@export var surface_music: AudioStream
@export var depths_music: AudioStream

@export_group("Effets sonores")
@export var item_collected_sound: AudioStream
@export var dirt_break_sound: AudioStream
@export var vegetation_break_sound: AudioStream
@export var block_place_sound: AudioStream
@export var game_over_sound: AudioStream
@export var quest_completed_sound: AudioStream

@export_group("Transitions")
@export_range(0.1, 5.0, 0.1) var fade_duration: float = 1.5

@onready var music_a: AudioStreamPlayer = $MusicA
@onready var music_b: AudioStreamPlayer = $MusicB

var active_player: AudioStreamPlayer
var inactive_player: AudioStreamPlayer
var current_music: AudioStream
var music_tween: Tween


func _ready() -> void:
	active_player = music_a
	inactive_player = music_b


func play_music(stream: AudioStream) -> void:
	if stream == null:
		return

	if stream == current_music and active_player.playing:
		return

	if music_tween != null:
		music_tween.kill()

	var old_player: AudioStreamPlayer = active_player
	var new_player: AudioStreamPlayer = inactive_player

	new_player.stop()
	new_player.stream = stream
	new_player.volume_linear = 0.0
	new_player.play()

	active_player = new_player
	inactive_player = old_player
	current_music = stream

	music_tween = create_tween()
	music_tween.set_parallel(true)
	music_tween.tween_property(old_player, "volume_linear", 0.0, fade_duration)
	music_tween.tween_property(new_player, "volume_linear", 1.0, fade_duration)
	music_tween.chain().tween_callback(old_player.stop)

func play_sound(stream: AudioStream, volume_db: float = -6.0) -> void:
	if stream == null:
		return

	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.bus = &"SFX"
	sound.volume_db = volume_db

	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()


func stop_music() -> void:
	if music_tween != null:
		music_tween.kill()

	music_a.stop()
	music_b.stop()
	current_music = null
