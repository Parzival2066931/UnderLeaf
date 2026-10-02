extends Area2D
class_name HitboxComponent #inflige

signal hit(hurtbox: HurtboxComponent, amount: int)

@export var damage_amount := 1

func _on_hurtbox_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		
		area.apply_damage(damage_amount)
		hit.emit(area, damage_amount)
