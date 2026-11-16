extends Control

@onready var replay: Button = $PanelContainer/VBoxContainer/Replay
@onready var save_button: Button = $PanelContainer/VBoxContainer/Menu
@onready var save_error: Label = $PanelContainer/VBoxContainer/SaveError

var saving: bool = false


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
	Hud.show_settings_menu(true)


func _on_menu_pressed() -> void:
	if saving:
		return

	saving = true
	save_button.disabled = true
	save_error.text = ""

	var world: Node = get_tree().current_scene
	var player: Player = null

	if world != null:
		player = world.get("player") as Player

	var error: Error = WorldSaveManager.save_current_world(player)

	if error != OK:
		save_error.text = "Could not save the world. Please try again."
		push_error("Échec de la sauvegarde : %s" % error)
		save_button.disabled = false
		saving = false
		return

	await Transition.play_transition(_return_to_menu)

	save_button.disabled = false
	saving = false


func _on_leave_pressed() -> void:
	get_tree().quit()


func _on_restart_pressed() -> void:
	get_parent().show_player_control()
	await Transition.play_transition(get_tree().reload_current_scene)

func _return_to_menu() -> void:
	var error: Error = get_tree().change_scene_to_file(Hud.menu_scene)

	if error != OK:
		save_error.text = "World saved, but the main menu could not be opened."
		push_error("Impossible d'ouvrir le menu : %s" % error)
		return

	await get_tree().scene_changed

	WorldSaveManager.clear_current_world()
	Hud.hide_all_menu()
	get_tree().paused = false
	SoundManager.play_music(SoundManager.menu_music)
