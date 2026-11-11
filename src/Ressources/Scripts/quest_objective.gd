extends Resource
class_name QuestObjective


enum Type {
	COLLECT_ITEM,
	CRAFT_ITEM,
	USE_ITEM,
	DEFEAT_ENEMY,
	REACH_DEPTH,
	PLACE_ITEM_UNDERGROUND
}

@export var description: String
@export var type: Type = Type.COLLECT_ITEM
@export_range(1, 999, 1) var required_quantity: int = 1

@export_group("Cible")
@export var target_item: ItemData
@export var target_enemy: PackedScene
@export var icon: Texture2D
@export_range(0, 1000, 1) var minimum_depth: int = 0
