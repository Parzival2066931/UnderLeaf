class_name Cricket
extends Enemy

@export var jump_height: float = 32.0
@export var jump_delay: float = 0.6

var jump_cooldown: float = 0.0
var jump_horizontal_velocity: float = 0.0
var jumping: bool = false


func _physics_process(delta: float) -> void:
	if is_on_floor():
		jump_cooldown = maxf(jump_cooldown - delta, 0.0)

	if not is_on_floor():
		velocity += get_gravity() * delta

	if health_component.is_dead():
		jumping = false
		jump_horizontal_velocity = 0.0
	elif jumping:
		velocity.x = jump_horizontal_velocity

	move_and_slide()

	if jumping and is_on_floor() and velocity.y >= 0.0:
		jumping = false
		jump_horizontal_velocity = 0.0
		velocity.x = 0.0
		jump_cooldown = jump_delay
		update_movement_animation()
	elif jumping:
		update_movement_animation()


func move_toward_position(destination: Vector2, stop_distance: float) -> void:
	if jumping:
		velocity.x = jump_horizontal_velocity
		return

	velocity.x = 0.0

	var horizontal_distance := destination.x - global_position.x

	if absf(horizontal_distance) <= stop_distance:
		return

	face_position(destination)

	if not is_on_floor() or jump_cooldown > 0.0:
		return

	var gravity_y: float = get_gravity().y

	if gravity_y <= 0.0:
		return

	jump_horizontal_velocity = signf(horizontal_distance) * speed
	velocity.x = jump_horizontal_velocity
	velocity.y = -sqrt(2.0 * gravity_y * jump_height)
	jumping = true


func update_movement_animation() -> void:
	if jumping:
		animation.play("Jump")
	else:
		animation.play("Idle")


func can_attack_target() -> bool:
	return is_on_floor() and not jumping and super.can_attack_target()
