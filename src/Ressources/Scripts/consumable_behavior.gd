class_name ConsumableBehavior
extends ItemBehavior

@export var target_stat: PlayerStats.Stat = PlayerStats.Stat.HEALTH
@export_range(0.1, 1000.0, 0.1, "or_greater") var potency: float = 20.0
@export_range(0.0, 600.0, 0.1, "or_greater", "suffix:s") var duration: float = 0.0


func use(player: Player, _target_cell: Vector2i) -> bool:
	match target_stat:
		PlayerStats.Stat.HEALTH:
			if duration > 0.0:
				return false

			var health := player.health_component
			if health.is_dead() or health.is_maxed():
				return false

			health.heal(potency)
			return true

		PlayerStats.Stat.MOVE_SPEED, PlayerStats.Stat.JUMP:
			return player.stats.apply_bonus(target_stat, potency, duration)

	return false
