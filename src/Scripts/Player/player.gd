extends CharacterBody2D
class_name Player

@export_range(1, 20, 1) var heart_count: int = 5
@export_range(1.0, 100.0, 1.0) var health_per_heart: float = 20.0
@export var regeneration_amount: float = 5.0


@onready var stats: PlayerStats = $PlayerStats
@onready var animation: AnimatedSprite2D = $Animation
@onready var attack_range: Area2D = $AttackRange
@onready var attack_hitbox: HitboxComponent = $HitboxComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var regen_timer: Timer = $RegenTimer
@onready var hand: MeleeWeapon = $Weapons/Hand
@onready var pickaxe: MeleeWeapon = $Weapons/Pickaxe
@onready var axe: MeleeWeapon = $Weapons/Axe
@onready var bow: RangedWeapon = $Weapons/Bow



const SPEED = 70.0
const JUMP_VELOCITY = -300.0
const INVENTORY_SIZE := 10

var inventory: Array[Dictionary] = []
var selected_slot: int = 0
var weapons: Dictionary = {}
var active_weapon: BaseWeapon

enum Weapon {
	NONE,
	PICKAXE,
	AXE,
	BOW
}
var unlocked_weapons: Array[Weapon] = [Weapon.NONE]
var current_weapon: Weapon = Weapon.NONE:
	set(value):
		current_weapon = value

		if is_node_ready() and not weapons.is_empty():
			equip_weapon()

signal projectile_requested(projectile_scene: PackedScene, origin: Vector2, initial_velocity: Vector2)
signal inventory_changed

func _ready() -> void:
	setup_weapons()

	health_component.max_health = heart_count * health_per_heart
	health_component.health = health_component.max_health

	Hud.set_player_connection(health_component, heart_count, self)
	notify_inventory_changed()
	Hud.select_slot(selected_slot)

	health_component.changed.connect(_on_health_changed)
	


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = stats.get_stat_value(PlayerStats.Stat.JUMP, JUMP_VELOCITY)

	var direction := Input.get_axis("left", "right")
	var move_speed := stats.get_stat_value(PlayerStats.Stat.MOVE_SPEED, SPEED)

	if direction:
		velocity.x = direction * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
	
	update_animation(direction)
	move_and_slide()
	

func setup_weapons() -> void:
	weapons = {
		Weapon.NONE: hand,
		Weapon.PICKAXE: pickaxe,
		Weapon.AXE: axe,
		Weapon.BOW: bow
	}

	attack_hitbox.top_level = true

	for weapon: BaseWeapon in weapons.values():
		weapon.setup(self)

	refresh_weapon_menu()

	Hud.weapon_selected.connect(_on_weapon_selected)
	
	bow.shot_requested.connect(projectile_requested.emit)
	equip_weapon()


func equip_weapon() -> void:
	if active_weapon != null:
		active_weapon.cancel_attack()

	animation.stop()

	active_weapon = weapons[current_weapon]
	update_weapon_icon()


func update_weapon_icon() -> void:
	Hud.set_weapon_icon(active_weapon.icon)


func get_weapon() -> String:
	return active_weapon.animation_suffix


func can_mine() -> bool:
	return active_weapon != null and active_weapon.allows_mining


func update_animation(direction: float) -> void:
	active_weapon.update_attack()

	if active_weapon.is_attacking:
		return

	var suffix := get_weapon()

	if direction != 0:
		animation.flip_h = direction < 0
		animation.play("Walk" + suffix)
		return

	animation.play("Idle" + suffix)

func add_item(data: ItemData, quantity: int = 1) -> bool:
	if not can_add_item(data, quantity):
		return false

	for stack in inventory:
		if stack["item"] == data:
			stack["quantity"] += quantity
			notify_inventory_changed()
			return true

	for stack in inventory:
		if stack["item"] == null:
			stack["item"] = data
			stack["quantity"] = quantity
			notify_inventory_changed()
			return true

	inventory.append({
		"item": data,
		"quantity": quantity
	})

	notify_inventory_changed()
	return true

func get_selected_item() -> ItemData:
	if selected_slot < 0 or selected_slot >= inventory.size():
		return null

	var stack := inventory[selected_slot]

	if stack["quantity"] <= 0:
		return null

	return stack["item"]


func consume_selected_item() -> void:
	var data: ItemData = get_selected_item()

	if data != null:
		remove_item(data)

func notify_inventory_changed() -> void:
	Hud.refresh_hotbar(inventory)
	inventory_changed.emit()

func get_item_quantity(data: ItemData) -> int:
	if data == null:
		return 0

	var total: int = 0

	for stack in inventory:
		if stack["item"] == data:
			total += int(stack["quantity"])

	return total

func remove_item(data: ItemData, quantity: int = 1) -> bool:
	if data == null or quantity <= 0:
		return false

	if get_item_quantity(data) < quantity:
		return false

	var remaining: int = quantity

	for stack in inventory:
		if stack["item"] != data:
			continue

		var amount: int = mini(int(stack["quantity"]), remaining)
		stack["quantity"] -= amount
		remaining -= amount

		if stack["quantity"] == 0:
			stack["item"] = null

		if remaining == 0:
			break

	notify_inventory_changed()
	return true

func can_add_item(data: ItemData, quantity: int = 1) -> bool:
	if data == null or quantity <= 0:
		return false

	for stack in inventory:
		if stack["item"] == data or stack["item"] == null:
			return true

	return inventory.size() < INVENTORY_SIZE

func prepare_craft_inventory(recipe: CraftRecipe) -> Dictionary:
	if recipe == null or recipe.result == null:
		return {}

	if recipe.result_quantity <= 0 or recipe.ingredients.is_empty():
		return {}
	
	var weapon_behavior := recipe.result.behavior as WeaponBehavior

	if weapon_behavior != null:
		if recipe.result_quantity != 1 or not weapon_behavior.can_unlock(self):
			return {}
	
	var simulated_inventory: Array[Dictionary] = []

	for stack in inventory:
		simulated_inventory.append({
			"item": stack["item"],
			"quantity": int(stack["quantity"])
		})

	for ingredient in recipe.ingredients:
		if ingredient == null or ingredient.item == null:
			return {}

		if ingredient.quantity <= 0:
			return {}

		var remaining: int = ingredient.quantity

		for stack in simulated_inventory:
			if stack["item"] != ingredient.item:
				continue

			var amount: int = mini(int(stack["quantity"]), remaining)
			stack["quantity"] -= amount
			remaining -= amount

			if stack["quantity"] == 0:
				stack["item"] = null

			if remaining == 0:
				break

		if remaining > 0:
			return {}
	
	if weapon_behavior != null:
		return {"inventory": simulated_inventory}
	
	for stack in simulated_inventory:
		if stack["item"] == recipe.result:
			stack["quantity"] += recipe.result_quantity
			return {"inventory": simulated_inventory}

	for stack in simulated_inventory:
		if stack["item"] == null:
			stack["item"] = recipe.result
			stack["quantity"] = recipe.result_quantity
			return {"inventory": simulated_inventory}

	if simulated_inventory.size() >= INVENTORY_SIZE:
		return {}

	simulated_inventory.append({
		"item": recipe.result,
		"quantity": recipe.result_quantity
	})

	return {"inventory": simulated_inventory}

func can_craft(recipe: CraftRecipe) -> bool:
	return not prepare_craft_inventory(recipe).is_empty()

func craft(recipe: CraftRecipe) -> bool:
	var result: Dictionary = prepare_craft_inventory(recipe)
	if result.is_empty():
		return false

	var weapon_behavior := recipe.result.behavior as WeaponBehavior
	if weapon_behavior != null:
		if not weapon_behavior.use(self, Vector2i.ZERO):
			return false

	inventory = result["inventory"]
	notify_inventory_changed()
	return true

func use_selected_item() -> void:
	var item := get_selected_item()
	if item == null or item.behavior == null:
		return

	if item.behavior.use(self, Generator.get_target_cell()):
		consume_selected_item()

func is_weapon_unlocked(weapon_id: Weapon) -> bool:
	return weapon_id in unlocked_weapons


func refresh_weapon_menu() -> void:
	Hud.weapon_menu_button.get_popup().clear()

	for weapon_id in unlocked_weapons:
		var weapon: BaseWeapon = weapons[weapon_id]
		Hud.add_weapon_choice(weapon.icon, weapon_id)


func unlock_weapon(weapon_id: Weapon) -> bool:
	if not weapons.has(weapon_id) or is_weapon_unlocked(weapon_id):
		return false

	unlocked_weapons.append(weapon_id)
	refresh_weapon_menu()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("previous_slot"):
		selected_slot = wrapi(selected_slot - 1, 0, INVENTORY_SIZE)
		
		Hud.select_slot(selected_slot)
		
	elif event.is_action_pressed("next_slot"):
		selected_slot = wrapi(selected_slot + 1, 0, INVENTORY_SIZE)
		
		Hud.select_slot(selected_slot)
		
	elif event.is_action_pressed("place_bloc"):
		use_selected_item()

func _on_weapon_selected(weapon_id: int) -> void:
	var selected_weapon := weapon_id as Weapon
	
	if is_weapon_unlocked(selected_weapon):
		current_weapon = selected_weapon

func _on_attack_impact(weapon: Weapon) -> void:
	if weapon == Weapon.BOW:
		return

	attack_hitbox.global_position = get_global_mouse_position()
	attack_hitbox.activate(_can_hit_target)


func _can_hit_target(hurtbox: HurtboxComponent) -> bool:
	return attack_range.overlaps_area(hurtbox)


func _on_attack_hit(_hurtbox: HurtboxComponent, _amount: int) -> void:
	attack_hitbox.deactivate()

func _on_health_changed(_health: float) -> void:
	if health_component.is_dead() or health_component.is_maxed():
		regen_timer.stop()
		return

	if regen_timer.is_stopped():
		regen_timer.start()
		
func _on_regen_timer_timeout() -> void:
	if health_component.is_dead() or health_component.is_maxed():
		return

	health_component.heal(regeneration_amount)
