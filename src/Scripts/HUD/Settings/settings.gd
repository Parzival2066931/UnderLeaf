extends Control
class_name SettingsMenu


@export var minimum_volume_db: float = -55.0
@export var maximum_volume_db: float = -10.0

@onready var music_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MusicRow/MusicSlider
@onready var music_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MusicRow/Value
@onready var effects_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/EffectsRow/EffectsSlider
@onready var effects_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/EffectsRow/Value
@onready var mute_checkbox: CheckBox = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MuteCheckBox
@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

var music_bus: int
var effects_bus: int
var master_bus: int

signal back_requested()


func _ready() -> void:
	music_bus = AudioServer.get_bus_index(&"Music")
	effects_bus = AudioServer.get_bus_index(&"SFX")
	master_bus = AudioServer.get_bus_index(&"Master")

	assert(music_bus >= 0, "Le bus Music est introuvable.")
	assert(effects_bus >= 0, "Le bus SFX est introuvable.")
	assert(master_bus >= 0, "Le bus Master est introuvable.")

	music_slider.value_changed.connect(_on_music_changed)
	effects_slider.value_changed.connect(_on_effects_changed)
	mute_checkbox.toggled.connect(_on_mute_toggled)
	back_button.pressed.connect(_on_back_pressed)

	refresh_controls()


func open() -> void:
	refresh_controls()
	show()
	music_slider.grab_focus()


func refresh_controls() -> void:
	var music_percent: float = get_volume_percent(music_bus)
	var effects_percent: float = get_volume_percent(effects_bus)

	music_slider.set_value_no_signal(music_percent)
	effects_slider.set_value_no_signal(effects_percent)

	music_value.text = "%d%%" % roundi(music_percent)
	effects_value.text = "%d%%" % roundi(effects_percent)

	mute_checkbox.set_pressed_no_signal(AudioServer.is_bus_mute(master_bus))


func get_volume_percent(bus_index: int) -> float:
	if AudioServer.is_bus_mute(bus_index):
		return 0.0

	var volume_db: float = AudioServer.get_bus_volume_db(bus_index)
	var ratio: float = inverse_lerp(minimum_volume_db, maximum_volume_db, volume_db)

	return lerpf(1.0, 100.0, clampf(ratio, 0.0, 1.0))


func set_volume_percent(bus_index: int, value: float) -> void:
	var percent: float = clampf(value, 0.0, 100.0)
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)

	if percent <= 0.0:
		return

	var ratio: float = clampf((percent - 1.0) / 99.0, 0.0, 1.0)
	var volume_db: float = lerpf(minimum_volume_db, maximum_volume_db, ratio)

	AudioServer.set_bus_volume_db(bus_index, volume_db)

func _on_music_changed(value: float) -> void:
	set_volume_percent(music_bus, value)
	music_value.text = "%d%%" % roundi(value)


func _on_effects_changed(value: float) -> void:
	set_volume_percent(effects_bus, value)
	effects_value.text = "%d%%" % roundi(value)


func _on_mute_toggled(enabled: bool) -> void:
	AudioServer.set_bus_mute(master_bus, enabled)


func _on_back_pressed() -> void:
	back_requested.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mute_audio") and not event.is_echo():
		var muted: bool = not AudioServer.is_bus_mute(master_bus)
		AudioServer.set_bus_mute(master_bus, muted)
		mute_checkbox.set_pressed_no_signal(muted)
		get_viewport().set_input_as_handled()
