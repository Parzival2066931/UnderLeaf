class_name PlayerStats
extends Node

enum Stat { MOVE_SPEED, HEALTH, JUMP }

var active_bonuses: Dictionary = {}


func apply_bonus(stat: Stat, percent: float, duration: float) -> bool:
	if duration <= 0.0 or percent <= 0.0:
		return false

	active_bonuses[stat] = {
		"percent": percent,
		"remaining": duration
	}
	return true


func get_stat_value(stat: Stat, base_value: float) -> float:
	if not active_bonuses.has(stat):
		return base_value

	var bonus: Dictionary = active_bonuses[stat]
	return base_value * (1.0 + float(bonus["percent"]) / 100.0)


func _physics_process(delta: float) -> void:
	for stat in active_bonuses.keys():
		var bonus: Dictionary = active_bonuses[stat]
		bonus["remaining"] -= delta

		if bonus["remaining"] <= 0.0:
			active_bonuses.erase(stat)
