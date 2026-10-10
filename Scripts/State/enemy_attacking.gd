extends BaseState
class_name EnemyAttacking

@export var enemy: Enemy
@export var impact_frame: int = 1

var impact_applied := false


func enter() -> void:
	enemy.velocity.x = 0.0
	enemy.attack_hitbox.deactivate()
	impact_applied = false

	enemy.animation.frame_changed.connect(_on_frame_changed)
	enemy.animation.animation_finished.connect(_on_animation_finished)

	if not enemy.can_attack_target():
		transitioned.emit(&"Chasing")
		return

	enemy.prepare_attack()
	enemy.animation.stop()
	enemy.animation.play("Attack")
	_on_frame_changed()


func exit() -> void:
	enemy.attack_hitbox.deactivate()
	enemy.animation.frame_changed.disconnect(_on_frame_changed)
	enemy.animation.animation_finished.disconnect(_on_animation_finished)


func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	enemy.velocity.x = 0.0
	



func _on_frame_changed() -> void:
	if enemy.animation.frame != impact_frame:
		enemy.attack_hitbox.deactivate()
		return

	if impact_applied:
		return

	impact_applied = true

	if enemy.can_attack_target():
		enemy.attack_hitbox.activate()


func _on_animation_finished() -> void:
	transitioned.emit(&"Chasing")
