extends TileMapLayer

@export var world_generator: Node2D
@export_range(1, 30, 1) var fade_depth: int = 5
@export_range(0.0, 1.0, 0.05) var minimum_brightness: float = 0.25

func _use_tile_data_runtime_update(_coords: Vector2i) -> bool:
	return is_instance_valid(world_generator)

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	var surface_y: int = world_generator.get_surface_y(coords.x)
	var depth: int = maxi(coords.y - surface_y, 0)

	var progress: float = clampf(float(depth) / float(fade_depth), 0.0, 1.0)
	var brightness: float = lerpf(1.0, minimum_brightness, progress)

	tile_data.modulate = Color(brightness, brightness, brightness, 1.0)
