@tool
extends Node
class_name EnemyCatalog


@export_dir var enemies_folder: String = "res://Scenes/Enemy"
@export_tool_button("Actualiser les ennemis") var update_enemies_button: Callable:
	get:
		return Callable(self, "update_enemies")

@export_group("Apparition des ennemis")
@export var terrestrial_enemies: Array[PackedScene] = []
@export var underground_enemies: Array[PackedScene] = []



func update_enemies() -> void:
	if not Engine.is_editor_hint():
		return

	var directory := DirAccess.open(enemies_folder)

	if directory == null:
		push_error("Dossier des ennemis introuvable : " + enemies_folder)
		return

	var terrestrial: Array[PackedScene] = []
	var underground: Array[PackedScene] = []

	var files := directory.get_files()
	files.sort()

	for file_name in files:
		if file_name.get_extension() != "tscn":
			continue

		if file_name == "enemy.tscn":
			continue

		var scene_path := enemies_folder.path_join(file_name)
		var enemy_scene := load(scene_path) as PackedScene

		if enemy_scene == null:
			push_warning("Impossible de charger : " + scene_path)
			continue

		var habitat := get_scene_habitat(enemy_scene.get_state())

		match habitat:
			Enemy.Habitat.TERRESTRE:
				terrestrial.append(enemy_scene)

			Enemy.Habitat.SOUS_TERRAIN:
				underground.append(enemy_scene)

			_:
				push_warning("Habitat inconnu pour : " + scene_path)

	terrestrial_enemies = terrestrial
	underground_enemies = underground

	notify_property_list_changed()
	EditorInterface.mark_scene_as_unsaved()

func get_scene_habitat(state: SceneState) -> int:
	for node_index in range(state.get_node_count()):
		if state.get_node_path(node_index) != NodePath("."):
			continue

		for property_index in range(state.get_node_property_count(node_index)):
			if state.get_node_property_name(node_index, property_index) == &"habitat":
				return int(state.get_node_property_value(node_index, property_index))

	var parent_state := state.get_base_scene_state()

	if parent_state != null:
		return get_scene_habitat(parent_state)

	return Enemy.Habitat.TERRESTRE
