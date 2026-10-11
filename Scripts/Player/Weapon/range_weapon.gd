class_name RangedWeapon
extends BaseWeapon

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var launch_point: Marker2D


var is_aiming: bool = false

signal shot_requested(projectile_scene: PackedScene, origin: Vector2, initial_velocity: Vector2)



func setup(weapon_player: Player) -> void:
	super.setup(weapon_player)
	
	assert(projectile_scene != null, "Assigne la scène de projectile à Bow.")
	assert(launch_point != null, "Assigne ArrowOrigin à Bow.")

	allows_mining = false
	player.animation.animation_finished.connect(_on_animation_finished)


func update_attack() -> void:
	if is_aiming:
		update_aim()

		if Input.is_action_just_released("attack"):
			release_shot()

		return

	if is_attacking:
		return

	if Input.is_action_just_pressed("attack"):
		start_aim()


func start_aim() -> void:
	is_aiming = true
	is_attacking = true

	update_aim()

	player.animation.stop()
	player.animation.play("Attack" + animation_suffix + "Start")


func update_aim() -> void:
	player.animation.flip_h = player.get_global_mouse_position().x < player.global_position.x


func release_shot() -> void:
	is_aiming = false

	var origin := launch_point.global_position
	var direction := origin.direction_to(player.get_global_mouse_position())
	var initial_velocity := direction * projectile_speed

	player.animation.stop()
	player.animation.play("Attack" + animation_suffix + "End")

	shot_requested.emit(projectile_scene, origin, initial_velocity)


func _on_animation_finished() -> void:
	if not is_attacking or is_aiming:
		return

	if player.animation.animation != StringName("Attack" + animation_suffix + "End"):
		return

	is_attacking = false


func cancel_attack() -> void:
	is_aiming = false
	is_attacking = false
