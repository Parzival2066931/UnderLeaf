extends Control
class_name Outroduction

signal cinematic_finished()

@onready var video_stream_player: VideoStreamPlayer = $VideoStreamPlayer

var finished: bool = false


func _ready() -> void:
	video_stream_player.play()


func _on_video_stream_player_finished() -> void:
	if finished:
		return

	finished = true
	cinematic_finished.emit()
