extends Control

@export_file var intro_path: String

@onready var start: Button = $CenterContainer/VBoxContainer/Start
@onready var settings: Button = $CenterContainer/VBoxContainer/Settings
@onready var center_container: CenterContainer = $CenterContainer #boutons

var is_ready := false

func _ready() -> void:
	pass

func change_scene(scene_path: String):
	await Transition.play_transition(get_tree().change_scene_to_file, scene_path)


func set_ui_enabled(is_enabled: bool):
	mouse_filter = Control.MOUSE_FILTER_STOP if is_enabled else Control.MOUSE_FILTER_IGNORE

func focus_settings_button() -> void:
	settings.grab_focus()

func _on_start_pressed() -> void:
	#GameMaster.transition_to_music(GameMaster.world_music)
	change_scene(intro_path)
	Hud.player_ath.show()


func _on_settings_pressed() -> void:
	Hud.show_settings_menu(false)
	


func _on_leave_pressed() -> void:
	get_tree().quit()
	



	
