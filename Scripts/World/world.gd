extends Node2D

@export var player_scene: PackedScene
@export var ant_scene_test: PackedScene
@export var item_scene: PackedScene
@export var block_items: Array[ItemData] = []

@onready var spawner: Node2D = $Spawner

var player: Player
var ant: Enemy

func _ready() -> void:
	Generator.item_scene = item_scene
	Generator.block_items = block_items
	Generator.spawner = spawner

	Generator.init()
	spawn_player()
	spawn_enemy_test()

	Generator.player = player
	player.place_block_requested.connect(Generator.try_place_block)

	Generator.update_surface_light(Generator.get_player_chunk())


func _process(_delta: float) -> void:
	Generator.update()


func spawn_player() -> void:
	var spawn_x: int = 5
	var surface_y: int = Generator.get_surface_y(spawn_x)
	var spawn_cell := Vector2i(spawn_x, surface_y - 1)

	var spawn_position: Vector2 = Generator.tile_map_layer.to_global(
		Generator.tile_map_layer.map_to_local(spawn_cell)
	)

	player = spawner.spawn(player_scene, spawn_position)


func spawn_enemy_test() -> void:
	var spawn_x := 10
	var surface_y: int = Generator.get_surface_y(spawn_x)
	var spawn_cell := Vector2i(spawn_x, surface_y - 1)

	var spawn_position: Vector2 = Generator.tile_map_layer.to_global(
		Generator.tile_map_layer.map_to_local(spawn_cell)
	)

	ant = spawner.spawn(ant_scene_test, spawn_position)
