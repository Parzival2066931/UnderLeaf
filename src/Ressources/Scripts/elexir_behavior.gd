extends ItemBehavior
class_name ElixirBehavior


func use(player: Player, _target_cell: Vector2i) -> bool:
	if player.health_component.is_dead():
		return false

	var quest: QuestData = Quests.active_quest

	if quest == null or not quest.is_final_quest:
		return false

	var item: ItemData = player.get_selected_item()

	for objective in quest.objectives:
		if objective == null:
			continue

		if objective.type == QuestObjective.Type.USE_ITEM and objective.target_item == item:
			return true

	return false
