extends Resource
class_name ItemData

@export var item_name: String
@export var texture: Texture2D
@export var behavior: ItemBehavior

@export_group("Placement")
@export var tile_source_id: int = -1
@export var tile_atlas_coords: Array[Vector2i] = []

@export_group("Récolte")
@export var drop_source_id: int = -1
@export var drop_atlas_coords: Array[Vector2i] = []
