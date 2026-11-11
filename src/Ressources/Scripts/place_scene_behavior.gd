extends ItemBehavior
class_name PlaceSceneBehavior


@export var scene: PackedScene
@export var footprint: Vector2i = Vector2i.ONE


func use(player: Player, target_cell: Vector2i) -> bool:
	var item: ItemData = player.get_selected_item()

	if not Generator.try_place_scene(scene, target_cell, item, footprint):
		return false

	var surface_y: int = Generator.get_surface_y(target_cell.x)
	var depth: int = target_cell.y - surface_y

	Quests.record_item_placed(item, depth)
	return true
