extends Control

@export_file var intro_path: String
@export_file("*.tscn") var world_scene_path: String

@onready var world_selection = $WorldSelection
@onready var start: Button = $CenterContainer/VBoxContainer/Start
@onready var settings: Button = $CenterContainer/VBoxContainer/Settings
@onready var center_container: CenterContainer = $CenterContainer 

var is_ready := false

func _ready() -> void:
	SoundManager.play_music(SoundManager.menu_music)

	world_selection.hide()
	world_selection.back_requested.connect(_on_world_selection_back)
	world_selection.world_requested.connect(_on_world_requested)
	world_selection.new_world_requested.connect(_on_new_world_requested)

func change_scene(scene_path: String):
	await Transition.play_transition(get_tree().change_scene_to_file, scene_path)


func set_ui_enabled(is_enabled: bool):
	mouse_filter = Control.MOUSE_FILTER_STOP if is_enabled else Control.MOUSE_FILTER_IGNORE

func focus_settings_button() -> void:
	settings.grab_focus()

func _on_start_pressed() -> void:
	center_container.hide()
	world_selection.open()
	
func _on_settings_pressed() -> void:
	Hud.show_settings_menu(false)
	


func _on_leave_pressed() -> void:
	get_tree().quit()
	

func _on_world_selection_back() -> void:
	center_container.show()
	start.grab_focus()


func _on_world_requested(world_id: String) -> void:
	if world_scene_path.is_empty() or not ResourceLoader.exists(world_scene_path):
		world_selection.show_error("The world scene is not configured.")
		return

	var error: Error = WorldSaveManager.select_world(world_id)

	if error != OK:
		world_selection.show_error("Unable to read this save.")
		return

	SoundManager.stop_music()
	await change_scene(world_scene_path)

func _on_new_world_requested(world_name: String, seed: int) -> void:
	if intro_path.is_empty() or not ResourceLoader.exists(intro_path):
		world_selection.show_creation_error("The introduction scene is not configured.")
		return

	var error: Error = WorldSaveManager.create_world(world_name, seed)

	if error != OK:
		world_selection.show_creation_error("Unable to create the world. Error: %s" % error)
		return

	SoundManager.stop_music()
	await change_scene(intro_path)
