class_name PlaceableObject
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $Area2D

var outline_material: ShaderMaterial
var config: ItemData
var placement_cell: Vector2i


func _ready() -> void:
	assert(sprite.material is ShaderMaterial, "Le Sprite2D doit posséder le matériau de contour.")

	outline_material = sprite.material.duplicate() as ShaderMaterial
	set_highlight(false)

func _exit_tree() -> void:
	Generator.deselect_placeable(self)

func set_highlight(enabled: bool) -> void:
	if enabled:
		sprite.material = outline_material
	else:
		sprite.material = null


func _on_area_2d_mouse_entered() -> void:
	Generator.select_placeable(self)


func _on_area_2d_mouse_exited() -> void:
	Generator.deselect_placeable(self)
