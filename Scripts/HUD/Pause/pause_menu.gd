extends Control

@onready var replay: Button = $PanelContainer/VBoxContainer/Replay



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_replay_pressed() -> void:
	print("Replay")
	get_tree().paused = false
	get_parent().show_player_control()


func _on_settings_pressed() -> void:
	get_parent().get_node("settings").go_back_to = "pause"
	get_parent().show_settings_menu()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_parent().hide_all_menu()
	GameMaster.transition_to_music(GameMaster.menu_music)
	await Transition.play_transition(get_tree().change_scene_to_file, get_parent().menu_scene)


func _on_leave_pressed() -> void:
	get_tree().quit()


func _on_restart_pressed() -> void:
	get_parent().show_player_control()
	await Transition.play_transition(get_tree().reload_current_scene)
