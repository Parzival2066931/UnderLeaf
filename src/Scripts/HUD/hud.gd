extends CanvasLayer
class_name HUD

@export_file var menu_scene: String
@export var heart_scene: PackedScene

@export_group("Fabrication")
@export var recipe_slot_scene: PackedScene

@export_group("Victoire")
@export var victory_screen: Control
@export var victory_focus_button: Button

@onready var player_ath: Control = $PlayerATH
@onready var weapon_icon: TextureRect = $PlayerATH/MarginContainer/HorBarControl/HotBar/HBoxContainer2/ItemSlot/MarginContainer/PanelContainer/MarginContainer/Item
@onready var loot_slots: HBoxContainer = $PlayerATH/MarginContainer/HorBarControl/HotBar/HBoxContainer2/Loot
@onready var weapon_menu_button: MenuButton = $PlayerATH/MarginContainer/HorBarControl/HotBar/HBoxContainer2/ItemSlot/WeaponMenuButton
@onready var hearts_container: HBoxContainer = $PlayerATH/MarginContainer/HealthControl/Hearts
@onready var craft_button: Button = $PlayerATH/CraftButton
@onready var craft_panel: PanelContainer = $PlayerATH/CraftPanel
@onready var craft_close_button: Button = $PlayerATH/CraftPanel/VBoxContainer/Header/CloseButton
@onready var recipe_catalog: RecipeCatalog = $RecipeCatalog
@onready var recipes_grid: GridContainer = $PlayerATH/CraftPanel/VBoxContainer/Pages/CraftingPage/RecipesScroll/RecipesGrid
@onready var ingredients_panel: VBoxContainer = $PlayerATH/CraftPanel/VBoxContainer/Pages/CraftingPage/IngredientsPanel
@onready var ingredient_rows: VBoxContainer = $PlayerATH/CraftPanel/VBoxContainer/Pages/CraftingPage/IngredientsPanel/IngredientRows
@onready var crafting_tab: Button = $PlayerATH/CraftPanel/VBoxContainer/Header/CraftingTab
@onready var quests_tab: Button = $PlayerATH/CraftPanel/VBoxContainer/Header/QuestsTab
@onready var crafting_page: Control = $PlayerATH/CraftPanel/VBoxContainer/Pages/CraftingPage
@onready var quest_page: Control = $PlayerATH/CraftPanel/VBoxContainer/Pages/QuestPage

@onready var pause_menu: Control = $PauseMenu

@onready var settings_menu: Control = $settings

@onready var game_over: Control = $GameOver
@onready var restart_button: Button = $GameOver/PanelContainer/VBoxContainer3/VBoxContainer/Restart



var hearts: Array[TextureProgressBar] = []
var health_per_heart: float = 1.0


var first_time_settings := true
var health_component: HealthComponent

var crafting_player: Player
var hovered_recipe_slot: RecipeSlot


signal weapon_selected(weapon_id: int)

func _ready() -> void:
	hide_all_menu()
	weapon_menu_button.get_popup().id_pressed.connect(_on_weapon_selected)
	craft_button.pressed.connect(_on_craft_button_pressed)
	craft_close_button.pressed.connect(_on_craft_close_pressed)
	craft_panel.visibility_changed.connect(_on_craft_panel_visibility_changed)
	Quests.recipes_changed.connect(_on_recipes_changed)
	Quests.quest_completed.connect(_on_quest_completed)
	
	build_recipe_grid()
	crafting_tab.pressed.connect(show_crafting_page.bind(true))
	quests_tab.pressed.connect(show_crafting_page.bind(false))
	show_crafting_page(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func hide_all_menu(enable_scene_ui := true):
	pause_menu.hide()
	#settings_menu.hide()
	player_ath.hide()
	craft_panel.hide()
	game_over.hide()
	victory_screen.hide()

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

func show_crafting_page(show_crafting: bool) -> void:
	hovered_recipe_slot = null
	ingredients_panel.hide()

	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control != null and crafting_page.is_ancestor_of(focused_control):
		focused_control.release_focus()

	crafting_page.visible = show_crafting
	quest_page.visible = not show_crafting

	crafting_tab.set_pressed_no_signal(show_crafting)
	quests_tab.set_pressed_no_signal(not show_crafting)

func show_victory() -> void:
	if victory_screen.visible:
		return

	hide_all_menu(false)
	get_tree().paused = true
	victory_screen.show()

	if victory_focus_button != null:
		victory_focus_button.grab_focus()

func set_player_connection(hc: HealthComponent, heart_count: int, player: Player) -> void:
	if is_instance_valid(crafting_player):
		if crafting_player.inventory_changed.is_connected(refresh_recipe_slots):
			crafting_player.inventory_changed.disconnect(refresh_recipe_slots)

	crafting_player = player
	crafting_player.inventory_changed.connect(refresh_recipe_slots)

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
			

func build_recipe_grid() -> void:
	hovered_recipe_slot = null

	var focused_control: Control = get_viewport().gui_get_focus_owner()
	if focused_control != null and recipes_grid.is_ancestor_of(focused_control):
		focused_control.release_focus()

	for child in recipes_grid.get_children():
		recipes_grid.remove_child(child)
		child.queue_free()

	ingredients_panel.hide()

	for recipe in recipe_catalog.recipes:
		if recipe == null or recipe.result == null:
			continue

		if not Quests.is_recipe_unlocked(recipe):
			continue

		var slot := recipe_slot_scene.instantiate() as RecipeSlot
		assert(slot != null, "La scène doit utiliser RecipeSlot.")

		slot.setup(recipe)
		recipes_grid.add_child(slot)

		slot.mouse_entered.connect(_on_recipe_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_recipe_mouse_exited.bind(slot))
		slot.focus_entered.connect(refresh_ingredient_list)
		slot.focus_exited.connect(refresh_ingredient_list)
		slot.pressed.connect(_on_recipe_pressed.bind(recipe))

	if is_instance_valid(crafting_player):
		refresh_recipe_slots()

func can_pause() -> bool:
	if game_over.visible or victory_screen.visible:
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
	var popup := weapon_menu_button.get_popup()

	popup.add_icon_item(icon, "", weapon_id)
	popup.set_item_icon_max_width(popup.item_count - 1, 16)

func refresh_recipe_slots() -> void:
	for slot: RecipeSlot in recipes_grid.get_children():
		slot.set_craftable(crafting_player.can_craft(slot.recipe))

func refresh_ingredient_list() -> void:
	for row in ingredient_rows.get_children():
		ingredient_rows.remove_child(row)
		row.queue_free()

	var slot := hovered_recipe_slot
	if slot == null:
		slot = get_viewport().gui_get_focus_owner() as RecipeSlot

	if slot == null or not crafting_page.is_visible_in_tree():
		ingredients_panel.hide()
		return

	for ingredient in slot.recipe.ingredients:
		if ingredient != null and ingredient.item != null:
			add_ingredient_row(ingredient)

	ingredients_panel.visible = ingredient_rows.get_child_count() > 0

func add_ingredient_row(ingredient: RecipeIngredient) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	ingredient_rows.add_child(row)

	var item_icon := TextureRect.new()
	item_icon.custom_minimum_size = Vector2(24, 24)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture = ingredient.item.texture
	row.add_child(item_icon)

	var name_label := Label.new()
	name_label.text = ingredient.item.item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var quantity_label := Label.new()
	quantity_label.text = "× %d" % ingredient.quantity
	row.add_child(quantity_label)

func _on_recipe_pressed(recipe: CraftRecipe) -> void:
	if is_instance_valid(crafting_player):
		crafting_player.craft(recipe)

func _on_recipe_mouse_entered(slot: RecipeSlot) -> void:
	hovered_recipe_slot = slot
	refresh_ingredient_list()


func _on_recipe_mouse_exited(slot: RecipeSlot) -> void:
	if hovered_recipe_slot == slot:
		hovered_recipe_slot = null

	refresh_ingredient_list()

func _on_craft_panel_visibility_changed() -> void:
	hovered_recipe_slot = null
	refresh_ingredient_list()


func _on_weapon_selected(weapon_id: int) -> void:
	weapon_selected.emit(weapon_id)

func _on_craft_button_pressed() -> void:
	craft_panel.visible = not craft_panel.visible

func _on_craft_close_pressed() -> void:
	craft_panel.hide()

func _on_recipes_changed() -> void:
	build_recipe_grid.call_deferred()

func _on_quest_completed(quest: QuestData) -> void:
	if quest.is_final_quest:
		show_victory()
