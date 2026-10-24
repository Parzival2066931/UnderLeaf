@abstract class_name Enemy
extends CharacterBody2D

@export var speed: float = 30.0
@export var stopping_distance: float = 20.0
@export var sight_loss_delay: float = 0.5
@export var return_tolerance: float = 16.0
@export var return_stuck_delay: float = 1.5
@export var bite_offset: float = 45.0
@export var habitat: Habitat = Habitat.TERRESTRE

@onready var sight_cast: RayCast2D = $SightCast
@onready var state_machine: StateMachine = $StateMachine
@onready var attack_hitbox: HitboxComponent = $HitboxComponent
@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_zone: Area2D = $DetectionZone
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var health_bar: TextureProgressBar = $TextureProgressBar
@onready var attack_range: Area2D = $AttackRange

enum Habitat {
	TERRESTRE,
	SOUS_TERRAIN
}

var target: Node2D = null
var base_position := Vector2.ZERO
var last_seen_position := Vector2.ZERO

func _ready() -> void:
	health_component.changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.health

	base_position = global_position

	detection_zone.body_entered.connect(_on_detection_body_entered)
	detection_zone.body_exited.connect(_on_detection_body_exited)

	process_physics_priority = 1

	for state in state_machine.get_children():
		if state is BaseState:
			state.set("enemy", self)

	state_machine.initial_state = $StateMachine/Idle
	state_machine.start()

func can_attack_target() -> bool:
	if not is_instance_valid(target):
		return false

	if not can_see_target():
		return false

	return attack_range.overlaps_body(target)


func can_see_target() -> bool:
	if not is_instance_valid(target):
		return false

	sight_cast.target_position = sight_cast.to_local(target.global_position)
	sight_cast.force_raycast_update()

	return not sight_cast.is_colliding()


func prepare_attack() -> void:
	if is_instance_valid(target):
		face_position(target.global_position)


func face_position(destination: Vector2) -> void:
	var horizontal_distance := destination.x - global_position.x

	if not is_zero_approx(horizontal_distance):
		animation.flip_h = horizontal_distance > 0.0

	var direction := 1.0 if animation.flip_h else -1.0
	attack_range.position.x = direction * bite_offset
	attack_hitbox.position.x = direction * bite_offset

@abstract func move_toward_position(destination: Vector2, stop_distance: float) -> void

func _on_health_changed(current_health: float) -> void:
	health_bar.value = current_health

func _on_died() -> void:
	state_machine.change_state(&"Dead")

func _on_detection_body_entered(body: Node2D) -> void:
	if health_component.is_dead():
		return

	if body is Player:
		target = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
