extends CharacterBody2D
class_name Player

@export_range(1, 20, 1) var heart_count: int = 5
@export_range(1.0, 100.0, 1.0) var health_per_heart: float = 20.0
@export var regeneration_amount: float = 5.0




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

var current_weapon: Weapon = Weapon.NONE:
	set(value):
		current_weapon = value

		if is_node_ready() and not weapons.is_empty():
			equip_weapon()

signal place_block_requested


func _ready() -> void:
	setup_weapons()

	health_component.max_health = heart_count * health_per_heart
	health_component.health = health_component.max_health

	Hud.set_player_connection(health_component, heart_count)
	Hud.refresh_hotbar(inventory)
	Hud.select_slot(selected_slot)

	health_component.changed.connect(_on_health_changed)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
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

	Hud.weapon_menu_button.get_popup().clear()
	
	Hud.add_weapon_choice(hand.icon, Weapon.NONE)
	Hud.add_weapon_choice(pickaxe.icon, Weapon.PICKAXE)
	Hud.add_weapon_choice(axe.icon, Weapon.AXE)
	Hud.add_weapon_choice(bow.icon, Weapon.BOW)

	Hud.weapon_selected.connect(_on_weapon_selected)

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

func add_item(data: ItemData) -> bool:
	if data == null:
		return false

	# Compléter une pile existante en priorité.
	for stack in inventory:
		if stack["item"] == data:
			stack["quantity"] += 1
			Hud.refresh_hotbar(inventory)
			return true

	for stack in inventory:
		if stack["item"] == null:
			stack["item"] = data
			stack["quantity"] = 1
			Hud.refresh_hotbar(inventory)
			return true

	if inventory.size() >= INVENTORY_SIZE:
		return false

	inventory.append({
		"item": data,
		"quantity": 1
	})

	Hud.refresh_hotbar(inventory)
	return true

func get_selected_item() -> ItemData:
	if selected_slot < 0 or selected_slot >= inventory.size():
		return null

	var stack := inventory[selected_slot]

	if stack["quantity"] <= 0:
		return null

	return stack["item"]


func consume_selected_item() -> void:
	if get_selected_item() == null:
		return

	var stack := inventory[selected_slot]
	stack["quantity"] -= 1

	if stack["quantity"] == 0:
		stack["item"] = null

	Hud.refresh_hotbar(inventory)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("place_bloc"):
		var control := get_viewport().gui_get_hovered_control()

		if control != null:
			print("Interface sous la souris : ", control.get_path())
		else:
			print("Aucune interface sous la souris")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("previous_slot"):
		selected_slot = wrapi(selected_slot - 1, 0, INVENTORY_SIZE)
		
		Hud.select_slot(selected_slot)
		
	elif event.is_action_pressed("next_slot"):
		selected_slot = wrapi(selected_slot + 1, 0, INVENTORY_SIZE)
		
		Hud.select_slot(selected_slot)
		
	elif event.is_action_pressed("place_bloc"):
		print("BLOC")
		place_block_requested.emit()

func _on_weapon_selected(weapon_id: int) -> void:
	current_weapon = weapon_id as Weapon

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
