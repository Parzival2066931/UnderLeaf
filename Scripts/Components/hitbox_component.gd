extends Area2D
class_name HitboxComponent

signal hit(hurtbox: HurtboxComponent, amount: int)

@export var damage_amount: int = 10

@onready var hit_shape: CollisionShape2D = $HitboxShape


var active := false
var hit_targets: Array[HurtboxComponent] = []
var target_filter := Callable()


func _ready() -> void:
	assert(hit_shape != null, "Il faut assigner Hit Shape.")
	hit_shape.set_deferred("disabled", true)


func activate(filter: Callable = Callable()) -> void:
	if active:
		return

	hit_targets.clear()
	target_filter = filter
	active = true
	hit_shape.set_deferred("disabled", false)


func deactivate() -> void:
	active = false
	hit_shape.set_deferred("disabled", true)


func _on_hurtbox_entered(area: Area2D) -> void:
	if not active or not area is HurtboxComponent:
		return

	var hurtbox := area as HurtboxComponent

	if hit_targets.has(hurtbox):
		return

	if hurtbox.health_component.is_dead():
		return

	if target_filter.is_valid() and not target_filter.call(hurtbox):
		return

	hit_targets.append(hurtbox)
	hurtbox.apply_damage(damage_amount)
	hit.emit(hurtbox, damage_amount)
