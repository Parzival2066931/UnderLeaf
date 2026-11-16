extends Control
class_name VirtualKeyboard

signal submitted(value: String)
signal cancelled

enum Mode {
	TEXT,
	NUMBER
}

@onready var title: Label = $CenterContainer/PanelContainer/MarginContainer/Content/Title
@onready var text_input: LineEdit = $CenterContainer/PanelContainer/MarginContainer/Content/TextInput
@onready var letters: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/Content/Letters
@onready var space_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Actions/SpaceButton
@onready var delete_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Actions/DeleteButton
@onready var clear_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Actions/ClearButton
@onready var cancel_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Footer/CancelButton
@onready var confirm_button: Button = $CenterContainer/PanelContainer/MarginContainer/Content/Footer/ConfirmButton

const KEY_NORMAL: StyleBox = preload("res://Ressources/basic_recipe_style.tres")
const KEY_HIGHLIGHT: StyleBox = preload("res://Ressources/craftable_recipe_style.tres")

var current_mode: Mode = Mode.TEXT
var previous_focus: Control
var key_buttons: Array[Button] = []
var keyboard_rows: Array = []


func _ready() -> void:
	hide()
	set_process_input(false)

	text_input.focus_mode = Control.FOCUS_CLICK
	text_input.keep_editing_on_text_submit = true

	space_button.pressed.connect(_insert_character.bind(" "))
	delete_button.pressed.connect(_delete_character)
	clear_button.pressed.connect(_clear_text)
	cancel_button.pressed.connect(_cancel)
	confirm_button.pressed.connect(_confirm)

	text_input.text_changed.connect(_on_text_changed)
	text_input.text_submitted.connect(_on_text_submitted)


func open(initial_text: String = "", mode: Mode = Mode.TEXT) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	current_mode = mode

	title.text = "Enter world name" if mode == Mode.TEXT else "Enter seed"
	text_input.placeholder_text = "World name" if mode == Mode.TEXT else "Leave empty for a random seed"
	text_input.max_length = 40 if mode == Mode.TEXT else 11
	text_input.text = initial_text.left(text_input.max_length)
	text_input.caret_column = text_input.text.length()

	space_button.visible = mode == Mode.TEXT

	_build_keys()
	_update_confirm_button()

	show()
	set_process_input(true)
	key_buttons[0].grab_focus()

func apply_key_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", KEY_NORMAL)
	button.add_theme_stylebox_override("hover", KEY_HIGHLIGHT)
	button.add_theme_stylebox_override("pressed", KEY_HIGHLIGHT)
	button.add_theme_stylebox_override("hover_pressed", KEY_HIGHLIGHT)
	button.add_theme_stylebox_override("focus", KEY_HIGHLIGHT)

func cancel() -> void:
	if is_visible_in_tree():
		_cancel()

func _build_keys() -> void:
	for child in letters.get_children():
		letters.remove_child(child)
		child.queue_free()

	key_buttons.clear()
	keyboard_rows.clear()

	var layouts: Array[String] = [
		"1234567890",
		"QWERTYUIOP",
		"ASDFGHJKL",
		"ZXCVBNM"
	]

	if current_mode == Mode.NUMBER:
		layouts = [
			"123",
			"456",
			"789",
			"-0"
		]

	for characters in layouts:
		var row_container := HBoxContainer.new()
		row_container.alignment = BoxContainer.ALIGNMENT_CENTER
		row_container.add_theme_constant_override("separation", 4)
		letters.add_child(row_container)

		var row: Array[Control] = []

		for character in characters:
			var button := Button.new()
			button.text = character
			apply_key_style(button)
			button.custom_minimum_size = Vector2(36, 32)
			button.focus_mode = Control.FOCUS_ALL

			row_container.add_child(button)
			button.pressed.connect(_insert_character.bind(character))

			key_buttons.append(button)
			row.append(button)

		keyboard_rows.append(row)

	_build_focus_navigation()

func _build_focus_navigation() -> void:
	var rows: Array = keyboard_rows.duplicate()

	var actions: Array[Control] = []

	if current_mode == Mode.TEXT:
		actions.append(space_button)

	actions.append(delete_button)
	actions.append(clear_button)
	rows.append(actions)

	var footer: Array[Control] = [cancel_button, confirm_button]
	rows.append(footer)

	var all_controls: Array[Control] = []

	for row_index in range(rows.size()):
		var current_row: Array = rows[row_index]
		var above: Array = rows[wrapi(row_index - 1, 0, rows.size())]
		var below: Array = rows[wrapi(row_index + 1, 0, rows.size())]

		for column in range(current_row.size()):
			var control: Control = current_row[column]
			var left: Control = current_row[wrapi(column - 1, 0, current_row.size())]
			var right: Control = current_row[wrapi(column + 1, 0, current_row.size())]
			var up: Control = above[mini(column, above.size() - 1)]
			var down: Control = below[mini(column, below.size() - 1)]

			control.focus_neighbor_left = control.get_path_to(left)
			control.focus_neighbor_right = control.get_path_to(right)
			control.focus_neighbor_top = control.get_path_to(up)
			control.focus_neighbor_bottom = control.get_path_to(down)

			all_controls.append(control)

	for index in range(all_controls.size()):
		var control: Control = all_controls[index]
		var next_control: Control = all_controls[wrapi(index + 1, 0, all_controls.size())]
		var previous_control: Control = all_controls[wrapi(index - 1, 0, all_controls.size())]

		control.focus_next = control.get_path_to(next_control)
		control.focus_previous = control.get_path_to(previous_control)

	text_input.focus_next = text_input.get_path_to(key_buttons[0])
	text_input.focus_previous = text_input.get_path_to(cancel_button)


func _insert_character(character: String) -> void:
	if text_input.has_selection():
		text_input.delete_selection()

	text_input.insert_text_at_caret(character)
	_update_confirm_button()


func _delete_character() -> void:
	if text_input.has_selection():
		text_input.delete_selection()
	else:
		var caret: int = text_input.caret_column

		if caret > 0:
			text_input.delete_text(caret - 1, caret)
			text_input.caret_column = caret - 1

	_update_confirm_button()


func _clear_text() -> void:
	text_input.clear()
	_update_confirm_button()


func _on_text_changed(_new_text: String) -> void:
	_update_confirm_button()


func _update_confirm_button() -> void:
	var value: String = text_input.text.strip_edges()
	var valid: bool = not value.is_empty()

	if current_mode == Mode.NUMBER:
		valid = value.is_empty() or value.is_valid_int()

		if valid and not value.is_empty():
			var number: int = int(value)
			valid = number >= -2147483648 and number <= 2147483647

	# Le bouton reste accessible au joystick, même si la saisie est invalide.
	confirm_button.modulate = Color.WHITE if valid else Color(0.55, 0.55, 0.55)


func _is_valid_value(value: String) -> bool:
	if current_mode == Mode.TEXT:
		return not value.is_empty()

	if value.is_empty():
		return true

	if not value.is_valid_int():
		return false

	var number: int = int(value)
	return number >= -2147483648 and number <= 2147483647


func _on_text_submitted(_value: String) -> void:
	_confirm()


func _confirm() -> void:
	var value: String = text_input.text.strip_edges()

	if not _is_valid_value(value):
		title.text = "Enter a world name" if current_mode == Mode.TEXT else "Enter a valid seed"
		return

	_close()
	submitted.emit(value)


func _cancel() -> void:
	_close()
	cancelled.emit()


func _close() -> void:
	set_process_input(false)
	hide()

	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
