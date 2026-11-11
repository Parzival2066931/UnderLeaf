extends Resource
class_name QuestData


@export var id: StringName
@export var title: String
@export_multiline var description: String

@export_group("Objectifs")
@export var objectives: Array[QuestObjective] = []

@export_group("Progression")
@export var prerequisite: QuestData
@export var unlocked_recipes: Array[CraftRecipe] = []
@export var is_final_quest: bool = false
