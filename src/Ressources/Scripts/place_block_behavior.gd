extends ItemBehavior
class_name PlaceBlockBehavior


func use(player: Player, target_cell: Vector2i) -> bool:
	return Generator.try_place_block(player.get_selected_item(), target_cell)
