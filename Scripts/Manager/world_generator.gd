extends Node2D

@export var player_scene: PackedScene
@export var spawner: Node2D

@export var item_scene: PackedScene
@export var block_items: Array[ItemData] = []

@export_group("Sous-sol")
@export_range(20, 150, 1) var underground_depth: int = 150
@export_range(1, 20, 1) var surface_thickness: int = 5
@export var cave_seed: int = 12345
@export_range(0.005, 0.2, 0.005) var cave_frequency: float = 0.05
@export_range(-1.0, 1.0, 0.01) var cave_threshold: float = 0.25
@export_range(1, 200, 1) var min_pocket_size: int = 25
@export_range(8, 64, 1) var max_entrance_length: int = 32
@export_range(1, 10, 1) var entrance_spacing_chunks: int = 1

@onready var background: TileMapLayer = $Background
@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var block_highlight: Node2D = $BlockHighlight
@onready var mining_timer: Timer = $MiningTimer

const CAVE_NEIGHBORS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN
]

var entrance_thread := Thread.new()
var active_entrance_planner: EntrancePlanner
var pocket_request_pending: bool = false
var requested_pocket_start: int = 0
var requested_pocket_end: int = 0

var active_task_start: int = 0
var active_task_end: int = 0

enum GenerationTask {
	NONE,
	POCKETS,
	ENTRANCES
}

var active_generation_task: GenerationTask = GenerationTask.NONE
var entrance_request_pending: bool = false
var requested_entrance_start: int = 0
var requested_entrance_end: int = 0

var noise = FastNoiseLite.new()
var cave_noise := FastNoiseLite.new()

var chunk_cells: Dictionary = {}
var tunnel_cells: Dictionary = {}
var known_pocket_cells: Dictionary = {}
var known_pocket_anchors: Array[Vector2i] = []
var entrance_sectors: Dictionary = {}
var last_player_chunk: int = 0
var chunk_size = 16
var tile_size = 16
var tunnel_margin: int = 3
var render_distance = 4
var generated_chunks : Dictionary
var removed_blocks: Dictionary = {}
var mining_cell := Vector2i.ZERO
var placed_blocks: Dictionary = {}
var surface_height_cache: Dictionary = {}
var max_height: int = 360 / tile_size
var average_height: int = (360 / tile_size) - 1
var amp = 12
var player: CharacterBody2D

var highlighted_cell := Vector2i.ZERO
var has_highlighted_cell := false

var field_tileset_id = 0

var grass_tile = [
	Vector2i(4,6),
	Vector2i(5,6),
]

var dirt_tile = [
	Vector2i(6,6),
	Vector2i(7,6),
	Vector2i(8,6),
	Vector2i(6,7),
	Vector2i(7,7),
	Vector2i(8,7),
	Vector2i(6,8),
	Vector2i(7,8),
	Vector2i(8,8)
]

func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	noise.seed = -2030834033

	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	cave_noise.seed = cave_seed
	cave_noise.frequency = cave_frequency

	generate_tunnel()

	generate_starting_chunks()
	spawn_player()

func _process(_delta: float) -> void:
	update_chunks()
	update_entrance_thread()
	update_block_highlight()
	update_mining()

func _exit_tree() -> void:
	if entrance_thread.is_started():
		entrance_thread.wait_to_finish()

	active_entrance_planner = null

func get_surface_y(x: int) -> int:
	if surface_height_cache.has(x):
		return surface_height_cache[x]

	var value: float = noise.get_noise_1d(x)
	var surface_y: int = int(average_height + value * amp)
	var height: int = mini(surface_y, max_height)

	surface_height_cache[x] = height

	return height

func generate_chunk(chunk_x: int):
	if generated_chunks.has(chunk_x):
		return

	var start_x = chunk_x * chunk_size
	var end_x = start_x + chunk_size

	var cells: Array[Vector2i] = []

	for x in range(start_x, end_x):
		generate_column(x)

		var surface_y: int = get_surface_y(x)

		for y in range(surface_y, surface_y + underground_depth + 1):
			cells.append(Vector2i(x, y))

	chunk_cells[chunk_x] = cells

	for cell in placed_blocks:
		if get_chunk_x(cell.x) == chunk_x:
			var block: Dictionary = placed_blocks[cell]

			tile_map_layer.set_cell(
				cell,
				block["source_id"],
				block["atlas"]
			)

	generated_chunks[chunk_x] = true

func generate_starting_chunks() -> void:
	for chunk_x in range(-render_distance, render_distance + 1):
		generate_chunk(chunk_x)

func generate_column(x: int) -> void:
	var surface_y: int = get_surface_y(x)
	var grass: Vector2i = grass_tile.pick_random()
	var dirt: Vector2i = dirt_tile.pick_random()

	set_generated_cell(Vector2i(x, surface_y), field_tileset_id, grass)
	background.set_cell(Vector2i(x, surface_y), field_tileset_id, dirt)

	for depth in range(1, underground_depth + 1):
		var y = surface_y + depth
		var cell := Vector2i(x, y)
		dirt = dirt_tile.pick_random()

		background.set_cell(cell, field_tileset_id, dirt)

		if is_cave_cell(cell) or tunnel_cells.has(cell):
			continue

		set_generated_cell(cell, field_tileset_id, dirt)

func get_player_chunk() -> int:
	var chunk_pixel_size = chunk_size * tile_size
	return floori(player.global_position.x / chunk_pixel_size)

func spawn_player() -> void:
	var spawn_x = 5
	var surface_y = get_surface_y(spawn_x)

	var spawn_position = tile_map_layer.map_to_local(Vector2i(spawn_x, surface_y - 1))

	player = spawner.spawn(player_scene, spawn_position)
	player.place_block_requested.connect(try_place_block)

func update_chunks() -> void:
	if not is_instance_valid(player):
		return

	var player_chunk: int = get_player_chunk()
	var chunk_changed: bool = player_chunk != last_player_chunk

	if chunk_changed:
		last_player_chunk = player_chunk

		var planning_distance: int = render_distance + tunnel_margin
		var start_x: int = (player_chunk - planning_distance) * chunk_size
		var end_x: int = (player_chunk + planning_distance + 1) * chunk_size

		extend_tunnels(start_x, end_x)

	for chunk_x in range(player_chunk - render_distance, player_chunk + render_distance + 1):
		generate_chunk(chunk_x)

	for chunk_x in generated_chunks.keys():
		if absi(int(chunk_x) - player_chunk) > render_distance:
			unload_chunk(int(chunk_x))

func update_block_highlight() -> void:
	var mouse_local := tile_map_layer.to_local(get_global_mouse_position())
	var cell := tile_map_layer.local_to_map(mouse_local)

	if tile_map_layer.get_cell_source_id(cell) == -1:
		has_highlighted_cell = false
		block_highlight.hide()
		return

	highlighted_cell = cell
	has_highlighted_cell = true

	block_highlight.global_position = tile_map_layer.to_global(
		tile_map_layer.map_to_local(cell)
	)

	block_highlight.show()

func break_block() -> void:
	if not has_highlighted_cell:
		return

	if tile_map_layer.get_cell_source_id(highlighted_cell) == -1:
		return

	var drop := get_block_drop(highlighted_cell)

	var drop_position := tile_map_layer.to_global(
		tile_map_layer.map_to_local(highlighted_cell)
	)

	if drop != null:
		spawner.spawn(item_scene, drop_position, drop)

	placed_blocks.erase(highlighted_cell)

	removed_blocks[highlighted_cell] = true
	tile_map_layer.erase_cell(highlighted_cell)

	has_highlighted_cell = false
	block_highlight.hide()

func can_mine() -> bool:
	if not is_instance_valid(player):
		return false

	if not Input.is_action_pressed("attack"):
		return false

	if player.get_weapon() == "Bow":
		return false

	return has_highlighted_cell

func update_mining() -> void:
	if not can_mine():
		mining_timer.stop()
		return

	if highlighted_cell != mining_cell:
		mining_timer.stop()

	if mining_timer.is_stopped():
		mining_cell = highlighted_cell
		mining_timer.start()



func get_chunk_x(cell_x: int) -> int:
	return floori(float(cell_x) / chunk_size)

func set_generated_cell(cell: Vector2i, source_id: int, atlas: Vector2i) -> void:
	if removed_blocks.has(cell) or tunnel_cells.has(cell):
		return

	tile_map_layer.set_cell(cell, source_id, atlas)

func unload_chunk(chunk_x: int) -> void:
	if not generated_chunks.has(chunk_x):
		return

	var cells: Array[Vector2i] = chunk_cells[chunk_x]

	for cell in cells:
		tile_map_layer.erase_cell(cell)
		background.erase_cell(cell)

	# Les blocs posés peuvent se trouver au-dessus du terrain.
	for cell in placed_blocks:
		if get_chunk_x(cell.x) == chunk_x:
			tile_map_layer.erase_cell(cell)

	chunk_cells.erase(chunk_x)
	generated_chunks.erase(chunk_x)

func try_place_block() -> void:
	var data: ItemData = player.get_selected_item()

	if data == null:
		return

	if data.tile_source_id == -1 or data.tile_atlas_coords.is_empty():
		return

	var cell := tile_map_layer.local_to_map(
		tile_map_layer.to_local(get_global_mouse_position())
	)

	if tile_map_layer.get_cell_source_id(cell) != -1:
		return

	var atlas: Vector2i = data.tile_atlas_coords.pick_random()
	tile_map_layer.set_cell(cell, data.tile_source_id, atlas)

	placed_blocks[cell] = {
		"source_id": data.tile_source_id,
		"atlas": atlas
	}

	player.consume_selected_item()

func get_block_drop(cell: Vector2i) -> ItemData:
	var source_id := tile_map_layer.get_cell_source_id(cell)

	if source_id == -1:
		return null

	var atlas := tile_map_layer.get_cell_atlas_coords(cell)

	for data in block_items:
		if data == null:
			continue

		if data.tile_source_id == source_id \
				and atlas in data.tile_atlas_coords:
			return data

	return null

func is_cave_cell(cell: Vector2i) -> bool:
	var depth: int = cell.y - get_surface_y(cell.x)

	if depth <= surface_thickness:
		return false

	if depth > underground_depth - 3:
		return false

	var value: float = cave_noise.get_noise_2d(
		cell.x * 0.65,
		cell.y * 1.25
	)

	return value > cave_threshold

func find_cave_pockets(start_x: int, end_x: int) -> Array[Dictionary]:
	var remaining: Dictionary = {}
	var pockets: Array[Dictionary] = []

	for x in range(start_x, end_x):
		var surface_y: int = get_surface_y(x)

		for depth in range(surface_thickness + 1, underground_depth - 2):
			var cell := Vector2i(x, surface_y + depth)

			if is_cave_cell(cell):
				remaining[cell] = true

	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		var cells: Array[Vector2i] = [start]
		var touches_border := false
		var index := 0

		remaining.erase(start)

		while index < cells.size():
			var cell: Vector2i = cells[index]
			index += 1

			if cell.x == start_x or cell.x == end_x - 1:
				touches_border = true

			for direction in CAVE_NEIGHBORS:
				var neighbor: Vector2i = cell + direction

				if remaining.has(neighbor):
					remaining.erase(neighbor)
					cells.append(neighbor)

		pockets.append({
			"cells": cells,
			"touches_border": touches_border
		})

	return pockets

func get_pocket_anchor(cells: Array[Vector2i]) -> Vector2i:
	var center := Vector2.ZERO

	for cell in cells:
		center += Vector2(cell)

	center /= float(cells.size())

	var anchor: Vector2i = cells[0]
	var best_distance: float = Vector2(anchor).distance_squared_to(center)

	for cell in cells:
		var distance: float = Vector2(cell).distance_squared_to(center)

		if distance < best_distance:
			best_distance = distance
			anchor = cell

	return anchor

func prepare_pockets(pockets: Array[Dictionary]) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []

	for pocket in pockets:
		var cells: Array[Vector2i] = pocket["cells"]

		if pocket["touches_border"]:
			continue

		if cells.size() < min_pocket_size:
			continue

		selected.append({
			"anchor": get_pocket_anchor(cells),
			"cells": cells
		})

	return selected

func build_pocket_connections(pockets: Array[Dictionary]) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []

	if pockets.size() < 2:
		return connections

	var connected: Array[int] = [0]
	var remaining: Array[int] = []

	for i in range(1, pockets.size()):
		remaining.append(i)

	while not remaining.is_empty():
		var best_from: int = -1
		var best_to: int = -1
		var best_distance: float = INF

		for from_index in connected:
			var from_cell: Vector2i = pockets[from_index]["anchor"]

			for to_index in remaining:
				var to_cell: Vector2i = pockets[to_index]["anchor"]

				var difference := Vector2(to_cell - from_cell)
				difference.y *= 2.0

				var distance: float = difference.length_squared()

				if distance < best_distance:
					best_distance = distance
					best_from = from_index
					best_to = to_index

		connections.append({
			"from": pockets[best_from]["anchor"],
			"to": pockets[best_to]["anchor"]
		})

		connected.append(best_to)
		remaining.erase(best_to)

	return connections

func plan_tunnel(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var current := from_cell
	mark_tunnel_area(current)

	while current != to_cell:
		var difference := to_cell - current

		if absi(difference.x) > absi(difference.y):
			current.x += signi(difference.x)
		else:
			current.y += signi(difference.y)

		mark_tunnel_area(current)

func mark_tunnel_area(center: Vector2i) -> void:
	for offset_x in range(-1, 2):
		for offset_y in range(-1, 2):
			var cell := center + Vector2i(offset_x, offset_y)
			var depth: int = cell.y - get_surface_y(cell.x)

			if depth <= surface_thickness:
				continue

			if depth > underground_depth - 3:
				continue

			tunnel_cells[cell] = true

			if generated_chunks.has(get_chunk_x(cell.x)):
				if not placed_blocks.has(cell):
					tile_map_layer.erase_cell(cell)

func generate_tunnel() -> void:
	var planning_distance: int = render_distance + tunnel_margin

	var start_x: int = -planning_distance * chunk_size
	var end_x: int = (planning_distance + 1) * chunk_size

	var pockets := find_cave_pockets(start_x, end_x)
	var selected_pockets := prepare_pockets(pockets)
	var connections := build_pocket_connections(selected_pockets)

	for connection in connections:
		plan_tunnel(connection["from"], connection["to"])

	for pocket in selected_pockets:
		remember_pocket(pocket)

	generate_surface_entrances(start_x, end_x)

func extend_tunnels(start_x: int, end_x: int) -> void:
	requested_pocket_start = start_x
	requested_pocket_end = end_x
	pocket_request_pending = true

func remember_pocket(pocket: Dictionary) -> void:
	for cell in pocket["cells"]:
		known_pocket_cells[cell] = true

	var anchor: Vector2i = pocket["anchor"]

	if not known_pocket_anchors.has(anchor):
		known_pocket_anchors.append(anchor)

func is_pocket_known(pocket: Dictionary) -> bool:
	for cell in pocket["cells"]:
		if known_pocket_cells.has(cell):
			return true

	return false

func is_ground_solid(cell: Vector2i) -> bool:
	if placed_blocks.has(cell):
		return true

	if removed_blocks.has(cell):
		return false

	var depth: int = cell.y - get_surface_y(cell.x)

	if depth < 0 || depth > underground_depth:
		return false

	if is_cave_cell(cell) || tunnel_cells.has(cell):
		return false

	return true

func is_entrance_path_valid(path: Array[Vector2i]) -> bool:
	if path.is_empty():
		return false

	for cell in path:
		if not is_ground_solid(cell + Vector2i.DOWN):
			return false

		for height in range(3):
			var body_cell := cell + Vector2i.UP * height

			if placed_blocks.has(body_cell):
				return false

	return true

func carve_entrance(path: Array[Vector2i]) -> void:
	for foot_cell in path:
		for height in range(3):
			var cell := foot_cell + Vector2i.UP * height

			if cell.y < get_surface_y(cell.x):
				continue

			tunnel_cells[cell] = true

			if generated_chunks.has(get_chunk_x(cell.x)):
				if not placed_blocks.has(cell):
					tile_map_layer.erase_cell(cell)

func generate_surface_entrances(start_x: int, end_x: int) -> void:
	requested_entrance_start = start_x
	requested_entrance_end = end_x
	entrance_request_pending = true

func copy_cell_flags(source: Dictionary, start_x: int, end_x: int) -> Dictionary:
	var copy: Dictionary = {}

	for cell: Vector2i in source:
		if cell.x >= start_x and cell.x < end_x:
			copy[cell] = true

	return copy

func create_entrance_planner(start_x: int, end_x: int, include_world_state: bool = true) -> EntrancePlanner:
	var planner := EntrancePlanner.new()

	planner.noise = noise.duplicate() as FastNoiseLite
	planner.cave_noise = cave_noise.duplicate() as FastNoiseLite

	planner.underground_depth = underground_depth
	planner.surface_thickness = surface_thickness
	planner.cave_threshold = cave_threshold
	planner.max_entrance_length = max_entrance_length
	planner.min_pocket_size = min_pocket_size

	planner.max_height = max_height
	planner.average_height = average_height
	planner.amp = amp

	if include_world_state:
		planner.known_pocket_cells = copy_cell_flags(known_pocket_cells, start_x, end_x)
		planner.tunnel_cells = copy_cell_flags(tunnel_cells, start_x, end_x)
		planner.removed_blocks = copy_cell_flags(removed_blocks, start_x, end_x)
		planner.placed_blocks = copy_cell_flags(placed_blocks, start_x, end_x)

	return planner

func apply_entrance_results(results: Array[Dictionary]) -> void:
	for result in results:
		var sector: int = result["sector"]
		var path: Array[Vector2i] = result["path"]

		if entrance_sectors.has(sector):
			continue

		if not is_entrance_path_valid(path):
			continue

		carve_entrance(path)
		entrance_sectors[sector] = true

func update_entrance_thread() -> void:
	if entrance_thread.is_started():
		if entrance_thread.is_alive():
			return

		var results: Array[Dictionary] = entrance_thread.wait_to_finish()
		active_entrance_planner = null

		match active_generation_task:
			GenerationTask.POCKETS:
				apply_pocket_results(results)
				generate_surface_entrances(active_task_start, active_task_end)

			GenerationTask.ENTRANCES:
				apply_entrance_results(results)

		active_generation_task = GenerationTask.NONE
		return

	if not pocket_request_pending and not entrance_request_pending:
		return

	var task: Callable

	if pocket_request_pending:
		active_task_start = requested_pocket_start
		active_task_end = requested_pocket_end
		active_generation_task = GenerationTask.POCKETS

		active_entrance_planner = create_entrance_planner(active_task_start, active_task_end, false)
		task = active_entrance_planner.calculate_pockets.bind(active_task_start, active_task_end)
	else:
		active_task_start = requested_entrance_start
		active_task_end = requested_entrance_end
		active_generation_task = GenerationTask.ENTRANCES

		active_entrance_planner = create_entrance_planner(active_task_start, active_task_end)

		var completed_sectors: Dictionary = entrance_sectors.duplicate()
		var sector_width: int = chunk_size * entrance_spacing_chunks

		task = active_entrance_planner.calculate.bind(active_task_start, active_task_end, sector_width, completed_sectors)

	var error: Error = entrance_thread.start(task)

	if error != OK:
		active_entrance_planner = null
		active_generation_task = GenerationTask.NONE
		push_error("Impossible de démarrer le thread de génération : %s" % error)
		return

	if active_generation_task == GenerationTask.POCKETS:
		pocket_request_pending = false
	else:
		entrance_request_pending = false

func apply_pocket_results(selected_pockets: Array[Dictionary]) -> void:

	for pocket in selected_pockets:
		if is_pocket_known(pocket):
			continue

		var anchor: Vector2i = pocket["anchor"]

		if known_pocket_anchors.is_empty():
			remember_pocket(pocket)
			continue

		var closest_anchor: Vector2i = known_pocket_anchors[0]
		var best_distance: float = INF

		for known_anchor in known_pocket_anchors:
			var difference := Vector2(known_anchor - anchor)
			difference.y *= 2.0

			var distance: float = difference.length_squared()

			if distance < best_distance:
				best_distance = distance
				closest_anchor = known_anchor

		plan_tunnel(anchor, closest_anchor)
		remember_pocket(pocket)


func _on_mining_timer_timeout() -> void:
	update_block_highlight()

	if not can_mine():
		return

	if highlighted_cell != mining_cell:
		return

	break_block()
