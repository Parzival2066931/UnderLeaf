extends Control

@onready var quantity_label: Label = $MarginContainer/PanelContainer/MarginContainer/Quantity
@onready var icon: TextureRect = $MarginContainer/PanelContainer/MarginContainer/Item
@onready var selection: Panel = $Selection





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func show_item(data: ItemData, quantity: int) -> void:
	icon.texture = data.texture if data != null else null
	quantity_label.text = str(quantity) if quantity > 1 else ""
	

func set_selected(value: bool) -> void:
	selection.visible = value
	
