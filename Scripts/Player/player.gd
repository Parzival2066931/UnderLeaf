extends CharacterBody2D
class_name Player

@export var attack_impact_frame: int = 5
@export_range(1, 20, 1) var heart_count: int = 5
@export_range(1.0, 100.0, 1.0) var health_per_heart: float = 20.0
@export var regeneration_amount: float = 5.0


@export_group("Icônes des armes")
@export var pickaxe_icon: Texture2D
@export var axe_icon: Texture2D
@export var bow_icon: Texture2D

@onready var animation: AnimatedSprite2D = $Animation
@onready var attack_range: Area2D = $AttackRange
@onready var attack_hitbox: HitboxComponent = $HitboxComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var regen_timer: Timer = $RegenTimer


const SPEED = 70.0
const JUMP_VELOCITY = -300.0
const INVENTORY_SIZE := 10

var inventory: Array[Dictionary] = []
var selected_slot: int = 0
var is_attacking := false
var impact_applied := false
var attack_weapon: Weapon = Weapon.NONE

enum Weapon {
	NONE,
	PICKAXE,
	AXE,
	BOW
}

var current_weapon: Weapon = Weapon.NONE:
	set(value):
		current_weapon = value

		if is_node_ready():
			update_weapon_icon()

signal place_block_requested
signal attack_impact(weapon: Weapon)


func _ready() -> void:
	update_weapon_icon()
	
	health_component.max_health = heart_count * health_per_heart
	health_component.health = health_component.max_health

	Hud.set_player_connection(health_component, heart_count)
	Hud.refresh_hotbar(inventory)
	Hud.select_slot(selected_slot)
	Hud.weapon_menu_button.get_popup().clear()
	Hud.add_weapon_choice(pickaxe_icon, Weapon.PICKAXE)
	Hud.add_weapon_choice(axe_icon, Weapon.AXE)
	Hud.add_weapon_choice(bow_icon, Weapon.BOW)

	Hud.weapon_selected.connect(_on_weapon_selected)
	
	animation.frame_changed.connect(_on_animation_frame_changed)
	animation.animation_finished.connect(_on_animation_finished)
	attack_hitbox.top_level = true
	attack_impact.connect(_on_attack_impact)
	attack_hitbox.hit.connect(_on_attack_hit)
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
	
	
func update_animation(direction: float) -> void:
	if is_attacking:
		return
	
	var weapon = get_weapon()

	if weapon == "Bow":
		if Input.is_action_just_pressed("attack"):
			animation.play("AttackBowStart")
			return

		if Input.is_action_pressed("attack"):
			#animation de charge si jamais
			return

		if Input.is_action_just_released("attack"):
			animation.play("AttackBowEnd")
			return

	else:
		if Input.is_action_pressed("attack"):
			start_attack()
			return

	if direction != 0:
		animation.flip_h = direction < 0
		animation.play("Walk" + weapon)
		return

	animation.play("Idle" + weapon)
	

func get_weapon() -> String:
	match current_weapon:
		Weapon.PICKAXE:
			return "Pickaxe"
		Weapon.AXE:
			return "Axe"
		Weapon.BOW:
			return "Bow"
		_:
			return ""

func update_weapon_icon() -> void:
	var icon: Texture2D = null

	match current_weapon:
		Weapon.PICKAXE:
			icon = pickaxe_icon
		Weapon.AXE:
			icon = axe_icon
		Weapon.BOW:
			icon = bow_icon

	Hud.set_weapon_icon(icon)

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

func start_attack() -> void:
	if is_attacking or current_weapon == Weapon.BOW:
		return

	attack_weapon = current_weapon

	animation.stop()
	impact_applied = false
	is_attacking = true

	animation.flip_h = get_global_mouse_position().x < global_position.x
	animation.play("Attack" + get_weapon())

	_on_animation_frame_changed()


func _on_animation_frame_changed() -> void:
	if not is_attacking:
		return

	if animation.frame != attack_impact_frame:
		attack_hitbox.deactivate()
		return

	if impact_applied:
		return

	impact_applied = true
	attack_impact.emit(attack_weapon)


func _on_animation_finished() -> void:
	if not is_attacking:
		return

	attack_hitbox.deactivate()
	is_attacking = false


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
