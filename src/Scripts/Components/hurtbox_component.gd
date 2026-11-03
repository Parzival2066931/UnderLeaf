extends Area2D
class_name HurtboxComponent #reçoit

signal damaged(amount: float)

@export var health_component: HealthComponent

func _ready() -> void:
	assert(health_component, "No health_component:HealthComponent specified in %s." % [str(get_path())])

func apply_damage(amount: float) -> void:
	health_component.damage(amount)
	damaged.emit(amount)
