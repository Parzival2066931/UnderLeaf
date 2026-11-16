extends PanelContainer

signal debug_toggled(enabled: bool)

@onready var fps_label: Label = $MarginContainer/Content/FPSLabel
@onready var memory_label: Label = $MarginContainer/Content/MemoryLabel
@onready var maximum_memory_label: Label = $MarginContainer/Content/MaximumMemoryLabel
@onready var minimum_memory_label: Label = $MarginContainer/Content/MinimumMemoryLabel

const BYTES_PER_MIB: float = 1024.0 * 1024.0
const DISPLAY_INTERVAL_MS: int = 250

var current_memory: int = 0
var minimum_memory: int = -1
var maximum_memory: int = 0
var next_display_update: int = 0
var memory_available: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ignore_mouse(self)
	hide()

	_sample_memory()
	_refresh_labels()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("geek_data") and not event.is_echo():
		visible = not visible
		_refresh_labels()
		debug_toggled.emit(visible)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_sample_memory()

	var now: int = Time.get_ticks_msec()

	if now < next_display_update:
		return

	next_display_update = now + DISPLAY_INTERVAL_MS

	if visible:
		_refresh_labels()


func _sample_memory() -> void:
	current_memory = int(OS.get_static_memory_usage())
	memory_available = current_memory > 0

	if not memory_available:
		return

	if minimum_memory < 0:
		minimum_memory = current_memory
	else:
		minimum_memory = mini(minimum_memory, current_memory)

	maximum_memory = maxi(maximum_memory, current_memory)


func _refresh_labels() -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if not memory_available:
		memory_label.text = "Memory: unavailable"
		maximum_memory_label.text = "Maximum: unavailable"
		minimum_memory_label.text = "Minimum: unavailable"
		return

	memory_label.text = "Memory: %.1f MiB" % (current_memory / BYTES_PER_MIB)
	maximum_memory_label.text = "Maximum: %.1f MiB" % (maximum_memory / BYTES_PER_MIB)
	minimum_memory_label.text = "Minimum: %.1f MiB" % (minimum_memory / BYTES_PER_MIB)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_ignore_mouse(child)
