extends Node2D
class_name Spawner

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	pass
	
	

func spawn(objet: PackedScene, pos: Vector2, ressource: Resource = null) -> Node:
	var objet_a_spawn = objet.instantiate()
	if ressource:
		objet_a_spawn.config = ressource
	
	get_tree().current_scene.call_deferred("add_child", objet_a_spawn)
	objet_a_spawn.global_position = pos
	return objet_a_spawn
	

	
