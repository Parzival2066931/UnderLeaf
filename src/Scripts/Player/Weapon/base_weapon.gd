@abstract
class_name BaseWeapon
extends Node

@export var icon: Texture2D
@export var animation_suffix: String = ""
@export var allows_mining: bool = false
@export var instant_mining_category: ItemData.MiningCategory = ItemData.MiningCategory.NONE

var player: Player
var is_attacking: bool = false


func setup(weapon_player: Player) -> void:
	player = weapon_player


@abstract func update_attack() -> void


@abstract func cancel_attack() -> void
