class_name RangedWeapon
extends BaseWeapon

signal shot_requested(direction: Vector2)

var is_aiming: bool = false


func setup(weapon_player: Player) -> void:
	super.setup(weapon_player)

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

	var direction := player.global_position.direction_to(player.get_global_mouse_position())

	player.animation.stop()
	player.animation.play("Attack" + animation_suffix + "End")

	shot_requested.emit(direction)


func _on_animation_finished() -> void:
	if not is_attacking or is_aiming:
		return

	if player.animation.animation != StringName("Attack" + animation_suffix + "End"):
		return

	is_attacking = false


func cancel_attack() -> void:
	is_aiming = false
	is_attacking = false
