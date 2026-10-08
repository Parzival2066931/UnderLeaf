extends BaseState
class_name EnemyIdle

@export var enemy: Enemy


func enter() -> void:
	enemy.velocity.x = 0.0
	enemy.animation.play("Idle")


func exit() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	enemy.velocity.x = 0.0

	if enemy.can_see_target():
		enemy.last_seen_position = enemy.target.global_position
		transitioned.emit(&"Chasing")
		return
