extends CharacterBody2D

var config: ItemData

@export var gravity := 300.0
@export var item_visual_size := 8.0
@export var float_height := 1.5
@export var float_speed := 3.0
@export var float_offset := 3.0


@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea

var pickup_delay: float = 0.0
var counts_for_collection: bool = true

var float_time := 0.0
var picked_up := false

func _ready() -> void:
	if config == null:
		return

	sprite.texture = config.texture
	resize_sprite()


func _physics_process(delta: float) -> void:
	if pickup_delay > 0.0:
		pickup_delay = maxf(pickup_delay - delta, 0.0)

		if pickup_delay == 0.0:
			for body in pickup_area.get_overlapping_bodies():
				_on_pickup_area_body_entered(body)

				if picked_up:
					return
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	
	if is_on_floor():
		velocity.x = 0.0
		
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
	if picked_up or config == null or pickup_delay > 0.0:
		return

	if not body.has_method("add_item"):
		return

	if body.add_item(config):
		picked_up = true
		SoundManager.play_sound(SoundManager.item_collected_sound)

		if body is Player and counts_for_collection:
			Quests.record_item_collected(config)

		queue_free()
