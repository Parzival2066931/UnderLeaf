extends CharacterBody2D

var config: ItemData

@export var gravity := 300.0
@export var item_visual_size := 8.0
@export var float_height := 1.5
@export var float_speed := 3.0
@export var float_offset := 3.0

@onready var sprite: Sprite2D = $Sprite2D

var float_time := 0.0
var picked_up := false

func _ready() -> void:
	if config == null:
		return

	sprite.texture = config.texture
	resize_sprite()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	float_time += delta
	sprite.position.y = -float_offset + sin(float_time * float_speed) * float_height


func resize_sprite() -> void:
	if sprite.texture == null:
		return

	var texture_size = sprite.texture.get_size()
	var largest_side = maxf(texture_size.x, texture_size.y)

	var scale_factor = item_visual_size / largest_side
	sprite.scale = Vector2.ONE * scale_factor

func _on_pickup_area_body_entered(body: Node2D) -> void:
	if picked_up or config == null:
		return

	if not body.has_method("add_item"):
		return

	if body.add_item(config):
		picked_up = true
		queue_free()
