extends VBoxContainer
class_name QuestPage


@export var objective_row_scene: PackedScene
@export_range(1, 99, 1) var total_quests: int = 6

@onready var progress_label: Label = $Progress
@onready var quest_title: Label = $QuestScroll/QuestContent/QuestTitle
@onready var description: Label = $QuestScroll/QuestContent/Description
@onready var objectives_container: VBoxContainer = $QuestScroll/QuestContent/Objectives
@onready var rewards_container: VBoxContainer = $QuestScroll/QuestContent/Rewards

var objective_rows: Array[QuestObjectiveRow] = []
var displayed_quest: QuestData


func _ready() -> void:
	Quests.quest_changed.connect(display_quest)
	Quests.progress_changed.connect(update_progress)

	display_quest(Quests.active_quest, Quests.quantities, Quests.completed_quests.size())


func display_quest(quest: QuestData, quantities: Array[int], completed_quests: int) -> void:
	displayed_quest = quest
	display_rewards(quest)
	progress_label.text = "Completed quests : %d / %d" % [completed_quests, total_quests]

	for child in objectives_container.get_children():
		objectives_container.remove_child(child)
		child.queue_free()

	objective_rows.clear()

	if quest == null:
		quest_title.text = "No active quest."
		description.text = ""
		return

	quest_title.text = quest.title
	description.text = quest.description

	assert(objective_row_scene != null, "Assigne la scène de ligne d’objectif.")

	for index in range(quest.objectives.size()):
		var objective: QuestObjective = quest.objectives[index]
		assert(objective != null, "Un objectif de la quête est vide.")

		var row := objective_row_scene.instantiate() as QuestObjectiveRow
		assert(row != null, "La scène doit utiliser le script QuestObjectiveRow.")

		objectives_container.add_child(row)
		objective_rows.append(row)

	update_progress(quantities, completed_quests)

func display_rewards(quest: QuestData) -> void:
	for child in rewards_container.get_children():
		rewards_container.remove_child(child)
		child.queue_free()

	rewards_container.hide()

	if quest == null:
		return

	for recipe: CraftRecipe in quest.unlocked_recipes:
		if recipe == null or recipe.result == null:
			continue

		var row := objective_row_scene.instantiate() as QuestObjectiveRow
		assert(row != null, "La scène doit utiliser le script QuestObjectiveRow.")

		rewards_container.add_child(row)
		row.display_reward(recipe)

	rewards_container.visible = rewards_container.get_child_count() > 0


func update_progress(quantities: Array[int], completed_quests: int) -> void:
	progress_label.text = "Completed quests : %d / %d" % [completed_quests, total_quests]

	if displayed_quest == null:
		return

	for index in range(objective_rows.size()):
		var quantity: int = quantities[index] if index < quantities.size() else 0
		objective_rows[index].display(displayed_quest.objectives[index], quantity)
