extends CharacterBody2D
class_name Enemy

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_zone: Area2D = $DetectionZone
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: TextureProgressBar = $TextureProgressBar


func _ready() -> void:
	health_component.changed.connect(_on_health_changed)

	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.health


func _on_health_changed(current_health: float) -> void:
	health_bar.value = current_health
