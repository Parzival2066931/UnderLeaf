class_name MeleeWeapon
extends BaseWeapon

@export var impact_frame: int = 5

var impact_applied: bool = false


func setup(weapon_player: Player) -> void:
	super.setup(weapon_player)

	player.animation.frame_changed.connect(_on_animation_frame_changed)
	player.animation.animation_finished.connect(_on_animation_finished)
	player.attack_hitbox.hit.connect(_on_attack_hit)


func update_attack() -> void:
	if is_attacking:
		return

	if Input.is_action_pressed("attack"):
		start_attack()


func start_attack() -> void:
	if is_attacking:
		return

	player.animation.stop()

	impact_applied = false
	is_attacking = true

	player.animation.flip_h = player.get_global_mouse_position().x < player.global_position.x
	player.animation.play("Attack" + animation_suffix)

	_on_animation_frame_changed()


func _on_animation_frame_changed() -> void:
	if not is_attacking:
		return

	if player.animation.animation != StringName("Attack" + animation_suffix):
		return

	if player.animation.frame != impact_frame:
		player.attack_hitbox.deactivate()
		return

	if impact_applied:
		return

	impact_applied = true

	player.attack_hitbox.global_position = player.get_global_mouse_position()
	player.attack_hitbox.activate(_can_hit_target)


func _on_animation_finished() -> void:
	if not is_attacking:
		return

	if player.animation.animation != StringName("Attack" + animation_suffix):
		return

	cancel_attack()


func _can_hit_target(hurtbox: HurtboxComponent) -> bool:
	return player.attack_range.overlaps_area(hurtbox)


func _on_attack_hit(_hurtbox: HurtboxComponent, _amount: int) -> void:
	if not is_attacking:
		return

	player.attack_hitbox.deactivate()


func cancel_attack() -> void:
	if not is_attacking:
		return

	player.attack_hitbox.deactivate()
	is_attacking = false
	impact_applied = false
