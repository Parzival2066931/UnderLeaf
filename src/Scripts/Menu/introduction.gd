extends Control
class_name Introduction
@export_file var world_path : String


@onready var video_stream_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_button: Button = $SkipButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Hud.hide_all_menu()
	skip_button.grab_focus()
	video_stream_player.play()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not get_tree().paused:
		Hud.hide_all_menu()


func change_scene(scene_path: String):
	if video_stream_player.is_playing():
		video_stream_player.stop()
		
	await Transition.play_intro_transition(get_tree().change_scene_to_file, scene_path)
	

func _on_skip_button_pressed() -> void:
	change_scene(world_path)

func _on_video_stream_player_finished() -> void:
	change_scene(world_path)
