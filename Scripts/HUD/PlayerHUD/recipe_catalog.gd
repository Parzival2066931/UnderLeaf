@tool
extends Node
class_name RecipeCatalog

@export_dir var recipes_folder: String = "res://Ressources/Recipes"

@export_tool_button("Actualiser les recettes") var update_recipes_button: Callable:
	get:
		return Callable(self, "update_recipes")

@export var recipes: Array[CraftRecipe] = []


func update_recipes() -> void:
	if not Engine.is_editor_hint():
		return

	var directory := DirAccess.open(recipes_folder)
	if directory == null:
		push_error("Dossier des recettes introuvable : " + recipes_folder)
		return

	var found_recipes: Array[CraftRecipe] = []
	var files := directory.get_files()
	files.sort()

	for file_name in files:
		if file_name.get_extension().to_lower() != "tres":
			continue

		var recipe := load(recipes_folder.path_join(file_name)) as CraftRecipe
		if recipe != null:
			found_recipes.append(recipe)

	recipes = found_recipes
	notify_property_list_changed()
	EditorInterface.mark_scene_as_unsaved()
