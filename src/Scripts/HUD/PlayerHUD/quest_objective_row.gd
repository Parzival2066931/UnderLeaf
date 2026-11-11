extends HBoxContainer
class_name QuestObjectiveRow


@onready var icon: TextureRect = $Icon
@onready var objective_name: Label = $ObjectiveName
@onready var counter: Label = $Counter


func display(objective: QuestObjective, current_quantity: int) -> void:
	objective_name.text = objective.description

	var required: int = objective.required_quantity
	if objective.type == QuestObjective.Type.REACH_DEPTH:
		required = objective.minimum_depth

	counter.text = "%d / %d" % [mini(current_quantity, required), required]

	icon.texture = objective.icon

	if icon.texture == null and objective.target_item != null:
		icon.texture = objective.target_item.texture

	icon.visible = icon.texture != null

	var completed: bool = current_quantity >= required
	objective_name.theme_type_variation = &"CompletedObjective" if completed else &"ObjectiveText"
	counter.theme_type_variation = &"CompletedObjective" if completed else &"ObjectiveCounter"


func display_reward(recipe: CraftRecipe) -> void:
	icon.texture = recipe.result.texture
	icon.visible = icon.texture != null

	objective_name.text = "Unlocks : %s" % recipe.result.item_name
	objective_name.theme_type_variation = &"ObjectiveText"

	counter.hide()
