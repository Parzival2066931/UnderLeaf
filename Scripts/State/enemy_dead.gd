extends BaseState
class_name EnemyDead

@export var enemy: Enemy
@export_range(5.0, 10.0, 0.5) var disappear_delay: float = 7.0

var time_left: float


func enter() -> void:
	time_left = disappear_delay

	enemy.velocity.x = 0.0
	enemy.target = null
	enemy.attack_hitbox.deactivate()
	enemy.health_bar.hide()

	enemy.set_deferred("collision_layer", 0)
	enemy.set_deferred("collision_mask", 1)

	enemy.hurtbox.set_deferred("monitorable", false)
	enemy.hurtbox.set_deferred("monitoring", false)
	enemy.detection_zone.set_deferred("monitoring", false)
	enemy.attack_range.set_deferred("monitoring", false)

	enemy.animation.stop()
	enemy.animation.play("Die")


func exit() -> void:
	pass


func _process(delta: float) -> void:
	if enemy.animation.is_playing():
		return

	time_left -= delta

	if time_left <= 0.0:
		enemy.queue_free()


func _physics_process(_delta: float) -> void:
	enemy.velocity.x = 0.0
