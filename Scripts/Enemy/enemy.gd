@abstract class_name Enemy
extends CharacterBody2D

@export var speed: float = 30.0
@export var stopping_distance: float = 20.0
@export var sight_loss_delay: float = 0.5
@export var return_tolerance: float = 16.0
@export var return_stuck_delay: float = 1.5


@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_zone: Area2D = $DetectionZone
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: TextureProgressBar = $TextureProgressBar

var target: Node2D = null
var base_position := Vector2.ZERO
var last_seen_position := Vector2.ZERO

func _ready() -> void:
	health_component.changed.connect(_on_health_changed)

	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.health


@abstract func can_see_target() -> bool

@abstract func move_toward_position(destination: Vector2, stop_distance: float) -> void

func _on_health_changed(current_health: float) -> void:
	health_bar.value = current_health
