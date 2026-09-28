extends RefCounted
class_name EntrancePlanner

const CAVE_NEIGHBORS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN
]

var noise: FastNoiseLite
var cave_noise: FastNoiseLite

var underground_depth: int
var surface_thickness: int
var cave_threshold: float
var max_entrance_length: int
var min_pocket_size: int

var max_height: int
var average_height: int
var amp: int

var surface_height_cache: Dictionary = {}
var known_pocket_cells: Dictionary = {}
var tunnel_cells: Dictionary = {}
var removed_blocks: Dictionary = {}
var placed_blocks: Dictionary = {}

func get_surface_y(x: int) -> int:
	if surface_height_cache.has(x):
		return surface_height_cache[x]

	var value: float = noise.get_noise_1d(x)
	var surface_y: int = int(average_height + value * amp)
	var height: int = mini(surface_y, max_height)

	surface_height_cache[x] = height

	return height

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

func find_cave_floor_cells(start_x: int, end_x: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	for cell: Vector2i in known_pocket_cells:
		if cell.x < start_x or cell.x >= end_x:
			continue

		if not is_ground_solid(cell + Vector2i.DOWN):
			continue

		var has_clearance := true

		for height in range(3):
			var body_cell := cell + Vector2i.UP * height

			if is_ground_solid(body_cell):
				has_clearance = false
				break

		if has_clearance:
			candidates.append(cell)

	return candidates

func build_valid_entrance_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	var horizontal_distance: int = absi(target.x - start.x)
	var descent: int = target.y - start.y

	if descent <= 0 or descent > 20:
		return path

	if horizontal_distance > max_entrance_length:
		return path

	if horizontal_distance < descent * 2:
		return path

	if not can_use_entrance_cell(start):
		return path

	var direction: int = signi(target.x - start.x)

	var costs: Dictionary = {start.y: 0.0}

	var previous: Dictionary = {}

	for step in range(1, horizontal_distance + 1):
		var x: int = start.x + step * direction
		var progress: float = float(step) / horizontal_distance
		var curve: float = 1.0 - (1.0 - progress) * (1.0 - progress)
		var preferred_y: float = start.y + descent * curve

		var next_costs: Dictionary = {}

		for current_y: int in costs:
			for drop in range(2):
				var next_y: int = current_y + drop

				if next_y > target.y:
					continue

				var remaining_steps: int = horizontal_distance - step
				if target.y - next_y > remaining_steps:
					continue

				var cell := Vector2i(x, next_y)

				if not can_use_entrance_cell(cell):
					continue

				var difference: float = next_y - preferred_y
				var cost: float = float(costs[current_y]) + difference * difference

				if not next_costs.has(next_y) or cost < float(next_costs[next_y]):
					next_costs[next_y] = cost
					previous[cell] = Vector2i(x - direction, current_y)

		costs = next_costs

		if costs.is_empty():
			return path

	if not costs.has(target.y):
		return path

	var current := target
	path.append(current)

	while current != start:
		current = previous[current]
		path.append(current)

	path.reverse()
	return path

func find_entrance_path(surface_x: int, floor_cells: Array[Vector2i]) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	var start := Vector2i(surface_x, get_surface_y(surface_x) - 1)

	for target in floor_cells:
		var horizontal_distance: int = absi(target.x - start.x)

		if horizontal_distance > max_entrance_length:
			continue

		var path_length: int = horizontal_distance + 1

		if not best_path.is_empty() and path_length >= best_path.size():
			continue

		var path := build_valid_entrance_path(start, target)

		if path.is_empty():
			continue

		if not has_single_surface_opening(path):
			continue

		best_path = path

	return best_path

func find_entrance_in_sector(start_x: int, end_x: int, floor_cells: Array[Vector2i]) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []

	for surface_x in range(start_x, end_x):
		var path := find_entrance_path(surface_x, floor_cells)

		if path.is_empty():
			continue

		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path

	return best_path

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

func calculate(start_x: int, end_x: int, sector_width: int, completed_sectors: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var first_sector: int = floori(float(start_x) / sector_width)
	var last_sector: int = floori(float(end_x - 1) / sector_width)
	var floor_cells := find_cave_floor_cells(start_x, end_x)

	for sector in range(first_sector, last_sector + 1):
		if completed_sectors.has(sector):
			continue

		var sector_start: int = sector * sector_width
		var sector_end: int = sector_start + sector_width

		if sector_start < start_x or sector_end > end_x:
			continue

		var nearby_floor_cells: Array[Vector2i] = []

		for cell in floor_cells:
			if cell.x < sector_start - max_entrance_length:
				continue

			if cell.x > sector_end - 1 + max_entrance_length:
				continue

			nearby_floor_cells.append(cell)

		var path := find_entrance_in_sector(sector_start, sector_end, nearby_floor_cells)

		if path.is_empty():
			continue

		results.append({
			"sector": sector,
			"path": path
		})

		for foot_cell in path:
			for height in range(3):
				var cell := foot_cell + Vector2i.UP * height

				if cell.y >= get_surface_y(cell.x):
					tunnel_cells[cell] = true

	return results

func calculate_pockets(start_x: int, end_x: int) -> Array[Dictionary]:
	var pockets := find_cave_pockets(start_x, end_x)
	return prepare_pockets(pockets)

func can_use_entrance_cell(cell: Vector2i) -> bool:
	if not is_ground_solid(cell + Vector2i.DOWN):
		return false

	for height in range(3):
		var body_cell := cell + Vector2i.UP * height

		if placed_blocks.has(body_cell):
			return false

	return true

func has_single_surface_opening(path: Array[Vector2i]) -> bool:
	var entered_ground: bool = false

	for cell in path:
		var exposed: bool = cell.y - 2 <= get_surface_y(cell.x)

		if exposed and entered_ground:
			return false

		if not exposed:
			entered_ground = true

	return entered_ground
