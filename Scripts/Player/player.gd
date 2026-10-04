extends CharacterBody2D
class_name Player

@export_group("Icônes des armes")
@export var pickaxe_icon: Texture2D
@export var axe_icon: Texture2D
@export var bow_icon: Texture2D

@onready var animation: AnimatedSprite2D = $Animation

const SPEED = 70.0
const JUMP_VELOCITY = -300.0
const INVENTORY_SIZE := 10

var inventory: Array[Dictionary] = []
var selected_slot: int = 0

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

func _ready() -> void:
	update_weapon_icon()
	
	Hud.refresh_hotbar(inventory)
	Hud.select_slot(selected_slot)
	Hud.weapon_menu_button.get_popup().clear()
	Hud.add_weapon_choice(pickaxe_icon, Weapon.PICKAXE)
	Hud.add_weapon_choice(axe_icon, Weapon.AXE)
	Hud.add_weapon_choice(bow_icon, Weapon.BOW)

	Hud.weapon_selected.connect(_on_weapon_selected)


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
	var weapon = get_weapon()

	if weapon == "Bow":
		if Input.is_action_just_pressed("attack"):
			animation.play("AttackBowStart")
			return

		if Input.is_action_pressed("attack"):
			# ici tu peux garder une animation de charge si tu en as une
			return

		if Input.is_action_just_released("attack"):
			animation.play("AttackBowEnd")
			return

	else:
		if Input.is_action_pressed("attack"):
			animation.play("Attack" + weapon)
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

	# Réutiliser une case vidée.
	for stack in inventory:
		if stack["item"] == null:
			stack["item"] = data
			stack["quantity"] = 1
			Hud.refresh_hotbar(inventory)
			return true

	# Ajouter une case si l'inventaire n'est pas plein.
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
