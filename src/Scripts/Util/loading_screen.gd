extends Control

@export var spinner: AnimatedSprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func start_loading() -> void:
	show()
	spinner.play("Loading")

func finish_loading() -> void:
	hide()
	spinner.stop()
