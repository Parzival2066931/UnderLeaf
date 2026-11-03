extends Node2D
class_name Arrow

@export var gravity: float = 500.0
@export var damage: float = 10.0
@export var lifetime: float = 5.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var ray_cast: RayCast2D = $RayCast2D

var velocity: Vector2 = Vector2.ZERO
var remaining_lifetime: float
var launched: bool = false


func _ready() -> void:
	ray_cast.hit_from_inside = true
	sprite.rotation = velocity.angle()


func launch(initial_velocity: Vector2) -> void:
	velocity = initial_velocity
	remaining_lifetime = lifetime
	launched = true


func _physics_process(delta: float) -> void:
	if not launched:
		return

	remaining_lifetime -= delta

	if remaining_lifetime <= 0.0:
		queue_free()
		return

	var acceleration := Vector2(0.0, gravity)
	var movement := velocity * delta + acceleration * delta * delta * 0.5
	var next_position := global_position + movement

	# Vérifier le déplacement avant de déplacer la flèche.
	ray_cast.target_position = ray_cast.to_local(next_position)
	ray_cast.force_raycast_update()

	if ray_cast.is_colliding():
		var collider := ray_cast.get_collider()
		global_position = ray_cast.get_collision_point()
		hit_target(collider)
		return

	global_position = next_position
	velocity += acceleration * delta

	sprite.rotation = velocity.angle()


func hit_target(collider: Object) -> void:
	launched = false

	if collider is HurtboxComponent:
		collider.apply_damage(damage)
	elif collider is Enemy:
		collider.hurtbox.apply_damage(damage)

	queue_free()
