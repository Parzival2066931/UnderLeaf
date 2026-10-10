extends BaseState
class_name EnemyChasing

@export var enemy: Enemy

var time_without_sight: float = 0.0


func enter() -> void:
	time_without_sight = 0.0


func exit() -> void:
	enemy.velocity.x = 0.0


func _process(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	enemy.velocity.x = 0.0

	var target_visible := enemy.can_see_target()

	if target_visible:
		enemy.last_seen_position = enemy.target.global_position
		time_without_sight = 0.0
	else:
		time_without_sight += delta

		if time_without_sight >= enemy.sight_loss_delay:
			transitioned.emit(&"Returning")
			return

	var stop_distance: float = 0.0 if target_visible else enemy.stopping_distance
	enemy.move_toward_position(enemy.last_seen_position, stop_distance)

	if target_visible and enemy.can_attack_target():
		enemy.velocity.x = 0.0
		transitioned.emit(&"Attacking")
		return

	if is_zero_approx(enemy.velocity.x):
		enemy.animation.play("Idle")
	else:
		enemy.animation.play("Walk")
