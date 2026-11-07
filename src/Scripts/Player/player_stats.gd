class_name PlayerStats
extends Node

enum Stat { MOVE_SPEED, HEALTH, JUMP, VISION }


var surroundings_light: PointLight2D
var player_light: PointLight2D
var base_surroundings_light_scale: float
var base_player_light_scale: float
var active_bonuses: Dictionary = {}
var regeneration_health: HealthComponent
var regeneration_rate: float = 0.0
var regeneration_remaining: float = 0.0

func _physics_process(delta: float) -> void:
	for stat in active_bonuses.keys():
		var bonus: Dictionary = active_bonuses[stat]
		bonus["remaining"] -= delta

		if bonus["remaining"] <= 0.0:
			active_bonuses.erase(stat)

	update_regeneration(delta)
	update_vision()

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

func apply_regeneration(health: HealthComponent, total_healing: float, duration: float) -> bool:
	if duration <= 0.0 or total_healing <= 0.0:
		return false

	if health.is_dead() or health.is_maxed():
		return false

	regeneration_health = health
	regeneration_rate = total_healing / duration
	regeneration_remaining = duration
	return true


func update_regeneration(delta: float) -> void:
	if regeneration_remaining <= 0.0:
		return

	if not is_instance_valid(regeneration_health) or regeneration_health.is_dead():
		regeneration_remaining = 0.0
		return

	var elapsed: float = minf(delta, regeneration_remaining)
	regeneration_remaining = maxf(regeneration_remaining - elapsed, 0.0)

	if not regeneration_health.is_maxed():
		regeneration_health.heal(regeneration_rate * elapsed)

func setup_vision(surroundings: PointLight2D, character_light: PointLight2D) -> void:
	surroundings_light = surroundings
	player_light = character_light
	base_surroundings_light_scale = surroundings_light.texture_scale
	base_player_light_scale = player_light.texture_scale


func update_vision() -> void:
	if is_instance_valid(surroundings_light):
		surroundings_light.texture_scale = get_stat_value(Stat.VISION, base_surroundings_light_scale)

	if is_instance_valid(player_light):
		player_light.texture_scale = get_stat_value(Stat.VISION, base_player_light_scale)
