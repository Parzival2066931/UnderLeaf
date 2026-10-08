extends BaseState
class_name EnemyReturning

@export var enemy: Enemy

var best_return_distance: float = 0.0
var stuck_time: float = 0.0


func enter() -> void:
	best_return_distance = enemy.global_position.distance_to(enemy.base_position)
	stuck_time = 0.0


func exit() -> void:
	enemy.velocity.x = 0.0


func _process(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	enemy.velocity.x = 0.0

	if enemy.can_see_target():
		enemy.last_seen_position = enemy.target.global_position
		transitioned.emit(&"Chasing")
		return

	var distance: float = enemy.global_position.distance_to(enemy.base_position)

	if distance <= enemy.return_tolerance:
		transitioned.emit(&"Idle")
		return

	if distance < best_return_distance - 1.0:
		best_return_distance = distance
		stuck_time = 0.0
	else:
		stuck_time += delta

	if stuck_time >= enemy.return_stuck_delay:
		transitioned.emit(&"Idle")
		return

	enemy.move_toward_position(enemy.base_position, 2.0)

	if is_zero_approx(enemy.velocity.x):
		enemy.animation.play("Idle")
	else:
		enemy.animation.play("Walk")
