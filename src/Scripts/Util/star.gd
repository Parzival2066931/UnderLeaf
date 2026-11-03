extends Sprite2D

@export var sparkle_time_min := 0.5
@export var sparkle_time_max := 1.0

@export var sparkle_strength_min := 0.18
@export var sparkle_strength_max := 0.38

@export var sparkle_delay_min := 0.1
@export var sparkle_delay_max := 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var s = randf_range(0.05, 0.15)
	scale = Vector2(s, s)
	sparkle()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



var is_sparkling := true

func sparkle() -> void:
	if texture == null or texture.gradient == null:
		return
	
	while is_sparkling:
		# valeurs random
		var duration := randf_range(sparkle_time_min, sparkle_time_max)
		var strength := randf_range(sparkle_strength_min, sparkle_strength_max)
		
		# aller (flash)
		var tween := create_tween()
		tween.tween_property(texture, "fill_to", Vector2(0.5, 0.1), duration)
		await tween.finished
		
		# retour (pas forcément même vitesse)
		duration = randf_range(sparkle_time_min, sparkle_time_max)
		var tween_back := create_tween()
		tween_back.tween_property(texture, "fill_to", Vector2(0.5, strength), duration)
		await tween_back.finished
		
		# pause aléatoire (très important pour le naturel)
		await get_tree().create_timer(randf_range(sparkle_delay_min, sparkle_delay_max)).timeout
