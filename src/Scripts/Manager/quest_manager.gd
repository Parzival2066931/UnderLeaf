extends Node

signal quest_changed(quest: QuestData, quantities: Array[int], completed_count: int)
signal progress_changed(quantities: Array[int], completed_count: int)
signal quest_completed(quest: QuestData)

@export var quests: Array[QuestData] = []

var active_quest: QuestData
var quantities: Array[int] = []
var completed_quests: Array[QuestData] = []

signal recipes_changed()

func start_new_game() -> void:
	active_quest = null
	quantities.clear()
	completed_quests.clear()

	activate_next_quest()
	recipes_changed.emit()


func activate_next_quest() -> void:
	active_quest = null
	quantities.clear()

	for quest in quests:
		if quest == null or quest in completed_quests:
			continue

		if quest.prerequisite != null and quest.prerequisite not in completed_quests:
			continue

		active_quest = quest
		quantities.resize(quest.objectives.size())
		quantities.fill(0)
		break

	quest_changed.emit(active_quest, quantities.duplicate(), completed_quests.size())


func record_item_collected(item: ItemData, quantity: int = 1) -> void:
	if active_quest == null or item == null or quantity <= 0:
		return

	var changed: bool = false

	for index in range(active_quest.objectives.size()):
		var objective: QuestObjective = active_quest.objectives[index]

		if objective == null:
			continue

		if objective.type != QuestObjective.Type.COLLECT_ITEM:
			continue

		if objective.target_item != item:
			continue

		var new_quantity: int = mini(quantities[index] + quantity, objective.required_quantity)

		if new_quantity != quantities[index]:
			quantities[index] = new_quantity
			changed = true

	if changed:
		progress_changed.emit(quantities.duplicate(), completed_quests.size())
		check_completion()

func record_item_placed(item: ItemData, depth: int) -> void:
	if active_quest == null or item == null:
		return

	var changed: bool = false

	for index in range(active_quest.objectives.size()):
		var objective: QuestObjective = active_quest.objectives[index]

		if objective == null:
			continue

		if objective.type != QuestObjective.Type.PLACE_ITEM_UNDERGROUND:
			continue

		if objective.target_item != item:
			continue

		if depth <= 0 or depth < objective.minimum_depth:
			continue

		var new_quantity: int = mini(quantities[index] + 1, objective.required_quantity)

		if new_quantity != quantities[index]:
			quantities[index] = new_quantity
			changed = true

	if changed:
		progress_changed.emit(quantities.duplicate(), completed_quests.size())
		check_completion()

func record_enemy_defeated(enemy: Enemy) -> void:
	if active_quest == null or not is_instance_valid(enemy):
		return

	var changed: bool = false

	for index in range(active_quest.objectives.size()):
		var objective: QuestObjective = active_quest.objectives[index]

		if objective == null:
			continue

		if objective.type != QuestObjective.Type.DEFEAT_ENEMY:
			continue

		if objective.target_enemy == null:
			continue

		if objective.target_enemy.resource_path != enemy.scene_file_path:
			continue

		var new_quantity: int = mini(quantities[index] + 1, objective.required_quantity)

		if new_quantity != quantities[index]:
			quantities[index] = new_quantity
			changed = true

	if changed:
		progress_changed.emit(quantities.duplicate(), completed_quests.size())
		check_completion()

func record_item_crafted(item: ItemData, quantity: int = 1) -> void:
	if active_quest == null or item == null or quantity <= 0:
		return

	var changed: bool = false

	for index in range(active_quest.objectives.size()):
		var objective: QuestObjective = active_quest.objectives[index]

		if objective == null:
			continue

		if objective.type != QuestObjective.Type.CRAFT_ITEM:
			continue

		if objective.target_item != item:
			continue

		var new_quantity: int = mini(quantities[index] + quantity, objective.required_quantity)

		if new_quantity != quantities[index]:
			quantities[index] = new_quantity
			changed = true

	if changed:
		progress_changed.emit(quantities.duplicate(), completed_quests.size())
		check_completion()

func record_item_used(item: ItemData) -> void:
	if active_quest == null or item == null:
		return

	var changed: bool = false

	for index in range(active_quest.objectives.size()):
		var objective: QuestObjective = active_quest.objectives[index]

		if objective == null:
			continue

		if objective.type != QuestObjective.Type.USE_ITEM:
			continue

		if objective.target_item != item:
			continue

		var new_quantity: int = mini(quantities[index] + 1, objective.required_quantity)

		if new_quantity != quantities[index]:
			quantities[index] = new_quantity
			changed = true

	if changed:
		progress_changed.emit(quantities.duplicate(), completed_quests.size())
		check_completion()

func record_depth_reached(depth: int) -> void:
	if active_quest == null:
		return

	var changed: bool = false

	for index in range(active_quest.objectives.size()):
		var objective: QuestObjective = active_quest.objectives[index]

		if objective == null:
			continue

		if objective.type != QuestObjective.Type.REACH_DEPTH:
			continue

		var new_quantity: int = clampi(depth, 0, objective.minimum_depth)

		if new_quantity > quantities[index]:
			quantities[index] = new_quantity
			changed = true

	if changed:
		progress_changed.emit(quantities.duplicate(), completed_quests.size())
		check_completion()

func is_recipe_unlocked(recipe: CraftRecipe) -> bool:
	if recipe == null:
		return false

	var requires_quest: bool = false

	for quest in quests:
		if quest == null:
			continue

		if recipe not in quest.unlocked_recipes:
			continue

		requires_quest = true

		if quest in completed_quests:
			return true

	return not requires_quest

func check_completion() -> void:
	if active_quest == null or active_quest.objectives.is_empty():
		return

	for index in range(active_quest.objectives.size()):
		var objective: QuestObjective = active_quest.objectives[index]

		if objective == null:
			return

		var required: int = objective.required_quantity

		if objective.type == QuestObjective.Type.REACH_DEPTH:
			required = objective.minimum_depth

		if quantities[index] < required:
			return

	var finished_quest: QuestData = active_quest
	completed_quests.append(finished_quest)
	active_quest = null
	
	recipes_changed.emit()
	quest_completed.emit(finished_quest)
	activate_next_quest()

func restore_save_data(data: Dictionary) -> Error:
	var quests_by_id: Dictionary = {}

	for quest in quests:
		if quest == null:
			continue

		var quest_id: String = String(quest.id)

		if quest_id.is_empty() or quests_by_id.has(quest_id):
			push_error("Les quêtes doivent avoir des identifiants uniques et non vides.")
			return ERR_INVALID_DATA

		quests_by_id[quest_id] = quest

	var restored_completed: Array[QuestData] = []

	for saved_id in data.get("completed_quest_ids", []):
		var quest_id: String = String(saved_id)

		if not quests_by_id.has(quest_id):
			push_error("Quête sauvegardée introuvable : " + quest_id)
			return ERR_FILE_CORRUPT

		var quest: QuestData = quests_by_id[quest_id]

		if quest not in restored_completed:
			restored_completed.append(quest)

	var active_id: String = String(data.get("active_quest_id", ""))
	var restored_active: QuestData = null
	var restored_quantities: Array[int] = []

	if not active_id.is_empty():
		if not quests_by_id.has(active_id):
			push_error("Quête active introuvable : " + active_id)
			return ERR_FILE_CORRUPT

		restored_active = quests_by_id[active_id]

		if restored_active in restored_completed:
			return ERR_FILE_CORRUPT

		var saved_quantities: Array = data.get("quantities", [])

		if saved_quantities.size() != restored_active.objectives.size():
			push_error("Les objectifs de la quête ont changé depuis la sauvegarde.")
			return ERR_FILE_CORRUPT

		for quantity in saved_quantities:
			restored_quantities.append(maxi(0, int(quantity)))

	active_quest = restored_active
	completed_quests = restored_completed
	quantities = restored_quantities

	quest_changed.emit(active_quest, quantities.duplicate(), completed_quests.size())
	recipes_changed.emit()
	return OK

func get_save_data() -> Dictionary:
	var saved_completed_quests: Array = []
	var active_quest_id: String = ""

	if active_quest != null:
		if active_quest.id == &"":
			push_error("La quête active n'a pas d'identifiant.")
			return {}

		active_quest_id = String(active_quest.id)

	for quest in completed_quests:
		if quest.id == &"":
			push_error("Une quête terminée n'a pas d'identifiant.")
			return {}

		saved_completed_quests.append(String(quest.id))

	return {
		"active_quest_id": active_quest_id,
		"quantities": quantities.duplicate(),
		"completed_quest_ids": saved_completed_quests
	}
