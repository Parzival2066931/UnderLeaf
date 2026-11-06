extends ItemBehavior
class_name WeaponBehavior


@export var weapon_id: Player.Weapon = Player.Weapon.PICKAXE


func can_unlock(player: Player) -> bool:
	return player.weapons.has(weapon_id) and not player.is_weapon_unlocked(weapon_id)


func use(player: Player, _target_cell: Vector2i) -> bool:
	return player.unlock_weapon(weapon_id)
