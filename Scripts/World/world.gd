extends Node2D

@export var player_scene: PackedScene
@export var item_scene: PackedScene
@export var block_items: Array[ItemData] = []

@onready var spawner: Node2D = $Spawner
@onready var enemy_catalog: EnemyCatalog = $EnemyCatalog



@export_group("Placement des ennemis")
@export var surface_spawn_clearance: Vector2i = Vector2i(3, 3)
@export var minimum_enemy_spawn_distance: float = 400.0
@export_range(0.0, 1.0) var base_spawn_chance: float = 0.8
@export_range(0.0, 1.0) var population_penalty: float = 0.5
@export var population_radius: float = 400.0

@export_group("Population des cavités")
@export_range(1, 10000, 1) var small_cave_size: int = 80
@export_range(1, 10000, 1) var large_cave_size: int = 600
@export_range(1, 20, 1) var minimum_cave_enemies: int = 1
@export_range(1, 20, 1) var maximum_cave_enemies: int = 5
@export var underground_spawn_clearance: Vector2i = Vector2i(5, 3)
@export var minimum_cave_enemy_spacing: float = 64.0
@export_range(0.0, 1.0) var cave_spawn_chance: float = 0.95
@export_range(0.0, 1.0) var cave_population_penalty: float = 0.85

var pending_enemy_chunks: Array[int] = []
var evaluated_enemy_chunks: Dictionary = {}
var spawned_enemies: Array[Enemy] = []
var populated_caves: Dictionary = {}
var cave_spawn_check_elapsed: float = 0.0
var cave_spawn_check_index: int = 0
var cave_enemies: Dictionary = {}

var player: Player

func _ready() -> void:
	Generator.item_scene = item_scene
	Generator.block_items = block_items
	Generator.spawner = spawner

	Generator.chunk_generated.connect(_on_chunk_generated)
	Generator.chunk_unloading.connect(_on_chunk_unloading)
	Generator.init()
	
	spawn_player()

	Generator.player = player
	player.place_block_requested.connect(Generator.try_place_block)

	Generator.update_surface_light(Generator.get_player_chunk())
	


func _process(delta: float) -> void:
	Generator.update()
	process_enemy_spawn_queue()
	update_cave_spawning(delta)


func spawn_player() -> void:
	var spawn_x: int = 5
	var surface_y: int = Generator.get_surface_y(spawn_x)
	var spawn_cell := Vector2i(spawn_x, surface_y - 1)

	var spawn_position: Vector2 = Generator.tile_map_layer.to_global(
		Generator.tile_map_layer.map_to_local(spawn_cell)
	)

	player = spawner.spawn(player_scene, spawn_position)
	player.projectile_requested.connect(_on_projectile_requested)

func find_surface_spawn_cells(chunk_x: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var start_x: int = chunk_x * Generator.chunk_size
	var end_x: int = start_x + Generator.chunk_size

	for x in range(start_x, end_x):
		var surface_y: int = Generator.get_surface_y(x)
		var ground_cell := Vector2i(x, surface_y)

		if not has_surface_spawn_space(ground_cell):
			continue

		var spawn_cell := ground_cell + Vector2i.UP
		var spawn_position := Generator.tile_map_layer.to_global(
			Generator.tile_map_layer.map_to_local(spawn_cell)
		)

		if spawn_position.distance_to(player.global_position) < minimum_enemy_spawn_distance:
			continue

		candidates.append(spawn_cell)

	return candidates


func has_surface_spawn_space(ground_cell: Vector2i) -> bool:
	var half_width: int = floori(surface_spawn_clearance.x / 2.0)

	for column in range(surface_spawn_clearance.x):
		var offset_x: int = column - half_width
		var floor_cell := ground_cell + Vector2i(offset_x, 0)

		if not Generator.generated_chunks.has(Generator.get_chunk_x(floor_cell.x)):
			return false

		if Generator.tile_map_layer.get_cell_source_id(floor_cell) == -1:
			return false

		for height in range(1, surface_spawn_clearance.y + 1):
			var empty_cell := floor_cell + Vector2i(0, -height)

			if Generator.tile_map_layer.get_cell_source_id(empty_cell) != -1:
				return false

	return true

func process_enemy_spawn_queue() -> void:
	if not is_instance_valid(player):
		return

	if not player.is_inside_tree():
		return

	if pending_enemy_chunks.is_empty():
		return

	var chunk_x: int = pending_enemy_chunks.pop_front()

	if not Generator.generated_chunks.has(chunk_x):
		return

	if evaluated_enemy_chunks.has(chunk_x):
		return

	if enemy_catalog.terrestrial_enemies.is_empty():
		return

	var candidates := find_surface_spawn_cells(chunk_x)

	if candidates.is_empty():
		return

	var spawn_cell: Vector2i = candidates.pick_random()
	var spawn_position := Generator.tile_map_layer.to_global(
		Generator.tile_map_layer.map_to_local(spawn_cell)
	)

	var nearby_count: int = count_nearby_enemies(spawn_position)
	var spawn_chance: float = base_spawn_chance

	if nearby_count > 0:
		spawn_chance *= pow(population_penalty, nearby_count)

	evaluated_enemy_chunks[chunk_x] = true

	if randf() >= spawn_chance:
		return

	var enemy_scene: PackedScene = enemy_catalog.terrestrial_enemies.pick_random()
	var enemy := spawner.spawn(enemy_scene, spawn_position) as Enemy

	register_spawned_enemy(enemy)


func count_nearby_enemies(spawn_position: Vector2) -> int:
	var nearby_count: int = 0
	var radius_squared: float = population_radius * population_radius

	for index in range(spawned_enemies.size() - 1, -1, -1):
		var enemy: Enemy = spawned_enemies[index]

		if not is_instance_valid(enemy):
			spawned_enemies.remove_at(index)
			continue

		if enemy.is_queued_for_deletion():
			continue

		if enemy.is_node_ready():
			if enemy.health_component.is_dead():
				continue

		if enemy.global_position.distance_squared_to(spawn_position) <= radius_squared:
			nearby_count += 1

	return nearby_count

func get_cave_population(cave_size: int) -> int:
	var size_range: int = maxi(large_cave_size - small_cave_size, 1)
	var size_ratio: float = clampf(
		float(cave_size - small_cave_size) / float(size_range),
		0.0,
		1.0
	)

	return roundi(lerpf(float(minimum_cave_enemies), float(maximum_cave_enemies), size_ratio))

func has_underground_spawn_space(spawn_cell: Vector2i) -> bool:
	var width: int = maxi(underground_spawn_clearance.x, 1)
	var height: int = maxi(underground_spawn_clearance.y, 1)
	var half_width: int = floori(width / 2.0)

	var center_chunk: int = Generator.get_chunk_x(spawn_cell.x)

	if not Generator.generated_chunks.has(center_chunk):
		return false

	var floor_cell := spawn_cell + Vector2i.DOWN

	if Generator.tile_map_layer.get_cell_source_id(floor_cell) == -1:
		return false

	for column in range(width):
		var offset_x: int = column - half_width
		var bottom_cell := spawn_cell + Vector2i(offset_x, 0)
		var chunk_x: int = Generator.get_chunk_x(bottom_cell.x)

		if not Generator.generated_chunks.has(chunk_x):
			return false

		for row in range(height):
			var empty_cell := bottom_cell + Vector2i(0, -row)

			if Generator.tile_map_layer.get_cell_source_id(empty_cell) != -1:
				return false

	return true

func find_cave_spawn_cells(pocket: Dictionary) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	for cell: Vector2i in pocket["cells"]:
		if not has_underground_spawn_space(cell):
			continue

		var spawn_position := Generator.tile_map_layer.to_global(
			Generator.tile_map_layer.map_to_local(cell)
		)

		if spawn_position.distance_to(player.global_position) < minimum_enemy_spawn_distance:
			continue

		candidates.append(cell)

	return candidates

func select_cave_spawn_cells(candidates: Array[Vector2i], target_count: int) -> Array[Vector2i]:
	var available: Array[Vector2i] = candidates.duplicate()
	var selected: Array[Vector2i] = []
	var selected_positions: Array[Vector2] = []
	var spacing_squared: float = minimum_cave_enemy_spacing * minimum_cave_enemy_spacing

	available.shuffle()

	for cell in available:
		var spawn_position := Generator.tile_map_layer.to_global(
			Generator.tile_map_layer.map_to_local(cell)
		)

		var too_close: bool = false

		for existing_position in selected_positions:
			if spawn_position.distance_squared_to(existing_position) < spacing_squared:
				too_close = true
				break

		if too_close:
			continue

		selected.append(cell)
		selected_positions.append(spawn_position)

		if selected.size() >= target_count:
			break

	return selected

func is_cave_loaded(pocket: Dictionary) -> bool:
	var cells: Array = pocket["cells"]

	if cells.is_empty():
		return false

	var first_cell: Vector2i = cells[0]
	var minimum_x: int = first_cell.x
	var maximum_x: int = first_cell.x

	for cell: Vector2i in cells:
		minimum_x = mini(minimum_x, cell.x)
		maximum_x = maxi(maximum_x, cell.x)

	var margin: int = ceili(maxi(underground_spawn_clearance.x, 1) / 2.0)
	var first_chunk: int = Generator.get_chunk_x(minimum_x - margin)
	var last_chunk: int = Generator.get_chunk_x(maximum_x + margin)

	for chunk_x in range(first_chunk, last_chunk + 1):
		if not Generator.generated_chunks.has(chunk_x):
			return false

	return true

func update_cave_spawning(delta: float) -> void:
	if not is_instance_valid(player):
		return

	if not player.is_inside_tree():
		return

	if enemy_catalog.underground_enemies.is_empty():
		return

	cave_spawn_check_elapsed += delta

	if cave_spawn_check_elapsed < 0.2:
		return

	cave_spawn_check_elapsed = 0.0

	var anchors: Array = Generator.known_pockets.keys()

	if anchors.is_empty():
		return

	cave_spawn_check_index %= anchors.size()

	var anchor: Vector2i = anchors[cave_spawn_check_index]
	cave_spawn_check_index += 1

	if populated_caves.has(anchor):
		return

	var pocket: Dictionary = Generator.known_pockets[anchor]

	if not is_cave_loaded(pocket):
		return

	var target_count: int = get_cave_population(int(pocket["size"]))
	var remaining_count: int = count_remaining_cave_enemies(anchor)
	var missing_count: int = maxi(target_count - remaining_count, 0)

	if missing_count == 0:
		populated_caves[anchor] = true
		return

	var candidates := find_cave_spawn_cells(pocket)
	var selected_cells := select_cave_spawn_cells(candidates, missing_count)
	
	print(
		"Cavité : ", anchor,
		" | Taille : ", pocket["size"],
		" | Maximum : ", target_count,
		" | Candidats : ", candidates.size(),
		" | Emplacements retenus : ", selected_cells.size()
	)
	
	if selected_cells.is_empty():
		return

	populated_caves[anchor] = true

	for cell in selected_cells:
		var height: int = maxi(underground_spawn_clearance.y, 1)
		var local_position := Generator.tile_map_layer.map_to_local(cell)
		local_position.y -= (height - 1) * Generator.tile_map_layer.tile_set.tile_size.y * 0.5

		var spawn_position := Generator.tile_map_layer.to_global(local_position)
		var nearby_count: int = count_nearby_enemies(spawn_position)
		var chance: float = cave_spawn_chance

		if nearby_count > 0:
			chance *= pow(cave_population_penalty, nearby_count)

		if randf() >= chance:
			continue

		var enemy_scene: PackedScene = enemy_catalog.underground_enemies.pick_random()
		var enemy := spawner.spawn(enemy_scene, spawn_position) as Enemy

		register_spawned_enemy(enemy)
		cave_enemies[anchor].append(enemy)


func register_spawned_enemy(enemy: Enemy) -> void:
	spawned_enemies.append(enemy)

func count_remaining_cave_enemies(anchor: Vector2i) -> int:
	var enemies: Array = cave_enemies.get(anchor, [])

	for index in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[index]

		if not is_instance_valid(enemy):
			enemies.remove_at(index)
			continue

		if enemy.is_queued_for_deletion():
			enemies.remove_at(index)
			continue

		if enemy.is_node_ready() and enemy.health_component.is_dead():
			enemies.remove_at(index)

	cave_enemies[anchor] = enemies
	return enemies.size()


func _on_chunk_unloading(chunk_x: int) -> void:
	for index in range(spawned_enemies.size() - 1, -1, -1):
		var enemy: Enemy = spawned_enemies[index]

		if not is_instance_valid(enemy):
			spawned_enemies.remove_at(index)
			continue

		var local_position := Generator.tile_map_layer.to_local(enemy.global_position)
		var cell := Generator.tile_map_layer.local_to_map(local_position)

		if Generator.get_chunk_x(cell.x) != chunk_x:
			continue

		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.hide()
		enemy.queue_free()
		spawned_enemies.remove_at(index)

	pending_enemy_chunks.erase(chunk_x)
	evaluated_enemy_chunks.erase(chunk_x)

	for anchor: Vector2i in Generator.known_pockets:
		var pocket: Dictionary = Generator.known_pockets[anchor]

		for cell: Vector2i in pocket["cells"]:
			if Generator.get_chunk_x(cell.x) == chunk_x:
				populated_caves.erase(anchor)
				count_remaining_cave_enemies(anchor)
				break

func _on_projectile_requested(projectile_scene: PackedScene, origin: Vector2, initial_velocity: Vector2) -> void:
	var arrow := spawner.spawn(projectile_scene, origin) as Arrow
	arrow.launch(initial_velocity)

func _on_chunk_generated(chunk_x: int) -> void:
	if not pending_enemy_chunks.has(chunk_x):
		pending_enemy_chunks.append(chunk_x)
