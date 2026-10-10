@abstract class_name Enemy
extends CharacterBody2D

@export var speed: float = 30.0
@export var stopping_distance: float = 20.0
@export var sight_loss_delay: float = 0.5
@export var return_tolerance: float = 16.0
@export var return_stuck_delay: float = 1.5

@onready var state_machine: StateMachine = $StateMachine
@onready var attack_hitbox: HitboxComponent = $HitboxComponent
@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_zone: Area2D = $DetectionZone
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var health_bar: TextureProgressBar = $TextureProgressBar
@onready var attack_range: Area2D = $AttackRange

var target: Node2D = null
var base_position := Vector2.ZERO
var last_seen_position := Vector2.ZERO

func _ready() -> void:
	health_component.changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.health

func can_attack_target() -> bool:
	if not is_instance_valid(target):
		return false

	if not can_see_target():
		return false

	return attack_range.overlaps_body(target)


@abstract func can_see_target() -> bool
@abstract func move_toward_position(destination: Vector2, stop_distance: float) -> void
@abstract func prepare_attack() -> void

func _on_health_changed(current_health: float) -> void:
	health_bar.value = current_health

func _on_died() -> void:
	state_machine.change_state(&"Dead")
