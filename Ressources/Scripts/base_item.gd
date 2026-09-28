extends Resource
class_name ItemData

@export var item_name: String
@export var texture: Texture2D

@export_group("Placement")
@export var tile_source_id: int = -1
@export var tile_atlas_coords: Array[Vector2i] = []
