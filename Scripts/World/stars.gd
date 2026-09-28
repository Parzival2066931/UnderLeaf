extends Node2D
class_name Stars

@export var star_scene: PackedScene
@export var spawn_area_size := Vector2(640, 110)
@export var star_count: int = 80



func _ready() -> void:
	generate_stars()

func generate_stars() -> void:
	clear_stars()
	
	if star_scene == null:
		push_warning("star_scene n'est pas assignée dans Stars.")
		return
	
	for i in range(star_count):
		var star_instance = star_scene.instantiate()
		
		if star_instance == null:
			continue
		
		var random_x := randf_range(0.0, spawn_area_size.x)
		var random_y := randf_range(0.0, spawn_area_size.y)
		
		star_instance.position = Vector2(random_x, random_y)
		
		add_child(star_instance)

func clear_stars() -> void:
	for child in get_children():
		child.queue_free()
