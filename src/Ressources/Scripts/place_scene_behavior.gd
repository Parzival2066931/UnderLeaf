extends ItemBehavior
class_name PlaceSceneBehavior


@export var scene: PackedScene


func use(player: Player, target_cell: Vector2i) -> bool:
	return Generator.try_place_scene(scene, target_cell, player.get_selected_item())
