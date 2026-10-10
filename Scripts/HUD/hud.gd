extends CanvasLayer
class_name HUD

@export_file var menu_scene: String
@export var heart_scene: PackedScene

@onready var player_ath: Control = $PlayerATH
@onready var pause_menu: Control = $PauseMenu
@onready var settings_menu: Control = $settings
@onready var weapon_icon: TextureRect = $PlayerATH/MarginContainer/HorBarControl/HotBar/HBoxContainer2/ItemSlot/MarginContainer/PanelContainer/MarginContainer/Item
@onready var loot_slots: HBoxContainer = $PlayerATH/MarginContainer/HorBarControl/HotBar/HBoxContainer2/Loot
@onready var weapon_menu_button: MenuButton = $PlayerATH/MarginContainer/HorBarControl/HotBar/HBoxContainer2/ItemSlot/WeaponMenuButton
@onready var hearts_container: HBoxContainer = $PlayerATH/MarginContainer/HealthControl/Hearts
@onready var game_over: Control = $GameOver
@onready var restart_button: Button = $GameOver/PanelContainer/VBoxContainer3/VBoxContainer/Restart


var hearts: Array[TextureProgressBar] = []
var health_per_heart: float = 1.0


var first_time_settings := true
var health_component: HealthComponent

signal weapon_selected(weapon_id: int)

func _ready() -> void:
	hide_all_menu()
	weapon_menu_button.get_popup().id_pressed.connect(_on_weapon_selected)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func hide_all_menu(enable_scene_ui := true):
	pause_menu.hide()
	#settings_menu.hide()
	player_ath.hide()
	game_over.hide()

	#if enable_scene_ui and get_tree().current_scene.has_method("set_ui_enabled"):
		#get_tree().current_scene.set_ui_enabled(true)


func show_pause_menu():
	hide_all_menu(false)
	get_tree().paused = true

	#if get_tree().current_scene.has_method("set_ui_enabled"):
		#get_tree().current_scene.set_ui_enabled(false)

	pause_menu.show()
	pause_menu.replay.grab_focus()

	
func show_settings_menu():
	hide_all_menu(false)

	#if get_tree().current_scene.has_method("set_ui_enabled"):
		#get_tree().current_scene.set_ui_enabled(false)

	settings_menu.show()


	
func show_player_control():
	get_tree().paused = false
	hide_all_menu(true)
	player_ath.show()

func show_game_over() -> void:
	if game_over.visible:
		return

	hide_all_menu(false)
	get_tree().paused = true
	game_over.show()
	restart_button.grab_focus()

func set_player_connection(hc: HealthComponent, heart_count: int) -> void:
	if is_instance_valid(health_component):
		if health_component.changed.is_connected(_update_player):
			health_component.changed.disconnect(_update_player)

		if health_component.died.is_connected(show_game_over):
			health_component.died.disconnect(show_game_over)
	
	health_component = hc
	health_per_heart = health_component.max_health / heart_count

	for heart in hearts:
		hearts_container.remove_child(heart)
		heart.queue_free()

	hearts.clear()

	for i in range(heart_count):
		var heart := heart_scene.instantiate() as TextureProgressBar
		hearts_container.add_child(heart)
		hearts.append(heart)

	health_component.changed.connect(_update_player)
	health_component.died.connect(show_game_over)
	_update_player(health_component.health)


func _update_player(health: float) -> void:
	for i in range(hearts.size()):
		var remaining_health := health - i * health_per_heart
		hearts[i].value = clampf(remaining_health / health_per_heart, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not can_pause():
			return
		
		show_pause_menu()
			
func can_pause() -> bool:
	if game_over.visible:
		return false

	return get_tree().current_scene.name != "Menu"

func set_weapon_icon(icon: Texture2D) -> void:
	weapon_icon.texture = icon

func refresh_hotbar(inventory: Array[Dictionary]) -> void:
	for i in range(loot_slots.get_child_count()):
		var slot = loot_slots.get_child(i)

		if i < inventory.size():
			slot.show_item(
				inventory[i]["item"],
				inventory[i]["quantity"]
			)
		else:
			slot.show_item(null, 0)

func select_slot(index: int) -> void:
	for i in range(loot_slots.get_child_count()):
		loot_slots.get_child(i).set_selected(i == index)

func add_weapon_choice(icon: Texture2D, weapon_id: int) -> void:
	weapon_menu_button.get_popup().add_icon_item(icon, "", weapon_id)

func _on_weapon_selected(weapon_id: int) -> void:
	weapon_selected.emit(weapon_id)
