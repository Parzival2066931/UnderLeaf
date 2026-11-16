extends Control

@onready var world_list: ItemList = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WorldList
@onready var status: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Status
@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/BackButton
@onready var load_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/LoadButton
@onready var new_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/NewButton
@onready var new_world_dialog: ConfirmationDialog = $NewWorldDialog
@onready var creation_error: Label = $NewWorldDialog/Fields/ErrorLabel
@onready var world_name_input: LineEdit = $NewWorldDialog/Fields/NameRow/WorldName
@onready var seed_input: LineEdit = $NewWorldDialog/Fields/SeedRow/SeedInput
@onready var edit_name_button: Button = $NewWorldDialog/Fields/NameRow/EditNameButton
@onready var edit_seed_button: Button = $NewWorldDialog/Fields/SeedRow/EditSeedButton
@onready var keyboard_window: Window = $NewWorldDialog/KeyboardWindow
@onready var virtual_keyboard: VirtualKeyboard = $NewWorldDialog/KeyboardWindow/VirtualKeyboard
@onready var delete_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/DeleteButton
@onready var delete_world_dialog: ConfirmationDialog = $DeleteWorldDialog

var pending_delete_id: String = ""
var editing_seed: bool = false
var busy: bool = false

signal back_requested
signal world_requested(world_id: String)
signal new_world_requested(world_name: String, seed: int)

func _ready() -> void:
	world_list.item_selected.connect(_on_item_selected)
	world_list.item_activated.connect(_on_item_activated)
	back_button.pressed.connect(_on_back_pressed)
	load_button.pressed.connect(_on_load_pressed)
	new_button.pressed.connect(_on_new_pressed)
	new_world_dialog.confirmed.connect(_on_create_confirmed)
	edit_name_button.pressed.connect(_on_edit_name_pressed)
	edit_seed_button.pressed.connect(_on_edit_seed_pressed)

	virtual_keyboard.submitted.connect(_on_keyboard_submitted)
	virtual_keyboard.cancelled.connect(_on_keyboard_cancelled)
	keyboard_window.close_requested.connect(_on_keyboard_close_requested)
	
	delete_button.pressed.connect(_on_delete_pressed)
	delete_world_dialog.confirmed.connect(_on_delete_confirmed)
	delete_world_dialog.canceled.connect(_on_delete_cancelled)

func open() -> void:
	show()
	busy = false
	back_button.disabled = false
	world_list.mouse_filter = Control.MOUSE_FILTER_STOP
	world_list.clear()
	load_button.disabled = true
	delete_button.disabled = true
	pending_delete_id = ""
	status.text = ""

	var worlds: Array[Dictionary] = WorldSaveManager.list_worlds()

	for world in worlds:
		var percentage: int = int(world["quest_percentage"])
		var label: String = "%s — Quests: %d%%" % [world["name"], percentage]
		var index: int = world_list.add_item(label)

		world_list.set_item_metadata(index, world["id"])

	if worlds.is_empty():
		status.text = "No saved worlds found."
		back_button.grab_focus()
	else:
		world_list.grab_focus()


func show_error(message: String) -> void:
	busy = false
	back_button.disabled = false
	world_list.mouse_filter = Control.MOUSE_FILTER_STOP
	load_button.disabled = world_list.get_selected_items().is_empty()
	status.text = message

func show_creation_error(message: String) -> void:
	busy = false
	new_world_dialog.get_ok_button().disabled = false
	creation_error.text = message

func _on_item_selected(_index: int) -> void:
	if busy:
		return

	load_button.disabled = false
	delete_button.disabled = false
	status.text = ""


func _on_item_activated(index: int) -> void:
	if busy:
		return

	world_list.select(index)
	_on_load_pressed()


func _on_load_pressed() -> void:
	if busy:
		return

	var selection: PackedInt32Array = world_list.get_selected_items()

	if selection.is_empty():
		return

	var world_id: String = String(world_list.get_item_metadata(selection[0]))

	busy = true
	load_button.disabled = true
	back_button.disabled = true
	world_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.text = "Loading..."

	world_requested.emit(world_id)


func _on_back_pressed() -> void:
	if busy:
		return

	hide()
	back_requested.emit()

func _on_new_pressed() -> void:
	if busy:
		return

	world_name_input.clear()
	seed_input.clear()
	creation_error.text = ""
	new_world_dialog.get_ok_button().disabled = false
	new_world_dialog.popup_centered(Vector2i(360, 240))
	edit_name_button.grab_focus()


func _on_create_confirmed() -> void:
	if busy:
		return

	var world_name: String = world_name_input.text.strip_edges()
	var seed_text: String = seed_input.text.strip_edges()

	if world_name.is_empty():
		creation_error.text = "Enter a world name."
		edit_name_button.grab_focus()
		return

	if not seed_text.is_empty() and not seed_text.is_valid_int():
		creation_error.text = "The seed must be a whole number."
		edit_seed_button.grab_focus()
		return

	var world_seed: int

	if seed_text.is_empty():
		world_seed = randi_range(-2147483648, 2147483647)
	else:
		world_seed = int(seed_text)

		if world_seed < -2147483648 or world_seed > 2147483647:
			creation_error.text = "Seed must be between -2147483648 and 2147483647."
			return

	busy = true
	new_world_dialog.get_ok_button().disabled = true
	creation_error.text = "Creating..."

	new_world_requested.emit(world_name, world_seed)

func _on_edit_name_pressed() -> void:
	if busy:
		return

	editing_seed = false
	keyboard_window.popup_centered(Vector2i(520, 380))
	virtual_keyboard.open(world_name_input.text, VirtualKeyboard.Mode.TEXT)


func _on_edit_seed_pressed() -> void:
	if busy:
		return

	editing_seed = true
	keyboard_window.popup_centered(Vector2i(520, 380))
	virtual_keyboard.open(seed_input.text, VirtualKeyboard.Mode.NUMBER)


func _on_keyboard_submitted(value: String) -> void:
	if editing_seed:
		seed_input.text = value
	else:
		world_name_input.text = value

	creation_error.text = ""
	_close_keyboard_window()


func _on_keyboard_cancelled() -> void:
	_close_keyboard_window()


func _on_keyboard_close_requested() -> void:
	virtual_keyboard.cancel()


func _close_keyboard_window() -> void:
	keyboard_window.hide()

	if editing_seed:
		edit_seed_button.call_deferred("grab_focus")
	else:
		edit_name_button.call_deferred("grab_focus")

func _on_delete_pressed() -> void:
	if busy:
		return

	var selection: PackedInt32Array = world_list.get_selected_items()

	if selection.is_empty():
		return

	var index: int = selection[0]
	pending_delete_id = String(world_list.get_item_metadata(index))

	# Lire le nom depuis la sauvegarde, sans modifier le monde sélectionné.
	var data: Dictionary = WorldSaveManager.load_world(pending_delete_id)
	var world_name: String = pending_delete_id

	if not data.is_empty():
		world_name = String(data["world"].get("name", pending_delete_id))

	busy = true
	delete_world_dialog.dialog_text = 'Delete "%s"?\n\nThis permanently removes its saved progress.' % world_name
	delete_world_dialog.popup_centered()

	delete_world_dialog.get_cancel_button().grab_focus()


func _on_delete_cancelled() -> void:
	pending_delete_id = ""
	busy = false

	delete_world_dialog.hide()
	delete_button.grab_focus()


func _on_delete_confirmed() -> void:
	if pending_delete_id.is_empty():
		return

	var error: Error = WorldSaveManager.delete_world(pending_delete_id)

	pending_delete_id = ""
	delete_world_dialog.hide()

	open()

	if error != OK:
		status.text = "Unable to fully delete the world. Error: %s" % error
		return

	if world_list.item_count == 0:
		status.text = "World deleted. No saved worlds remaining."
	else:
		status.text = "World deleted."
