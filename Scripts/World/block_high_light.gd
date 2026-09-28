extends Node2D

var size := 16.0

func _draw() -> void:
	draw_rect(
		Rect2(
			Vector2(-size / 2.0, -size / 2.0),
			Vector2(size, size)
		),
		Color.WHITE,
		false,
		1.0
	)
