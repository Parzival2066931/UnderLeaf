extends Enemy

@export var speed: float = 30.0
@export var stopping_distance: float = 20.0
@export var sight_loss_delay: float = 0.5
@export var return_tolerance: float = 16.0
@export var return_stuck_delay: float = 1.5

@export var block_size: float = 16.0
@export_range(1, 2, 1) var max_step_blocks: int = 2
@export var obstacle_check_distance: float = 4.0
@export var jump_clearance: float = 4.0

@export_group("Variation des fourmis")
@export var average_scale: float = 0.5
@export var size_deviation: float = 0.15
@export var minimum_size_factor: float = 0.7
@export var maximum_size_factor: float = 1.3



@onready var sight_cast: RayCast2D = $SightCast


enum State {
	IDLE,
	CHASE,
	RETURN
}

var state: State = State.IDLE

var size_factor: float = 1.0
var variation_initialized: bool = false
var target: Node2D = null

var base_position := Vector2.ZERO
var best_return_distance: float = 0.0
var return_stuck_time: float = 0.0
var time_without_sight: float = 0.0
var last_seen_position := Vector2.ZERO


func _ready() -> void:
	super()
	
	base_position = global_position

	detection_zone.body_entered.connect(_on_detection_body_entered)
	detection_zone.body_exited.connect(_on_detection_body_exited)

	animation.play("Idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	update_detection(delta)
	velocity.x = 0.0

	match state:
		State.CHASE:
			move_toward_position(last_seen_position, stopping_distance)

		State.RETURN:
			update_return(delta)

			if state == State.RETURN:
				move_toward_position(base_position, 2.0)

	try_climb_obstacle()

	if is_zero_approx(velocity.x):
		animation.play("Idle")
	else:
		animation.play("Walk")

	move_and_slide()

func _enter_tree() -> void:
	if variation_initialized:
		return

	variation_initialized = true

	size_factor = clampf(
		randfn(1.0, size_deviation),
		minimum_size_factor,
		maximum_size_factor
	)

	scale = Vector2.ONE * average_scale * size_factor

	var health_node: HealthComponent = get_node("HealthComponent")
	health_node.max_health = maxf(
		1.0,
		roundf(health_node.max_health * size_factor)
	)

func can_see_target() -> bool:
	if not is_instance_valid(target):
		return false

	sight_cast.target_position = sight_cast.to_local(target.global_position)
	sight_cast.force_raycast_update()

	return not sight_cast.is_colliding()


func update_detection(delta: float) -> void:
	if can_see_target():
		last_seen_position = target.global_position
		time_without_sight = 0.0
		state = State.CHASE
	elif state == State.CHASE:
		time_without_sight += delta

		if time_without_sight >= sight_loss_delay:
			time_without_sight = 0.0
			start_return()

func update_return(delta: float) -> void:
	var distance: float = global_position.distance_to(base_position)

	if distance <= return_tolerance:
		state = State.IDLE
		return

	if distance < best_return_distance - 1.0:
		best_return_distance = distance
		return_stuck_time = 0.0
	else:
		return_stuck_time += delta

	if return_stuck_time >= return_stuck_delay:
		state = State.IDLE

func try_climb_obstacle() -> void:
	if not is_on_floor() or is_zero_approx(velocity.x):
		return

	var forward := Vector2(signf(velocity.x) * obstacle_check_distance, 0.0)

	if not test_move(global_transform, forward):
		return

	var gravity_y: float = get_gravity().y

	if gravity_y <= 0.0:
		return

	for block_count in range(1, max_step_blocks + 1):
		var jump_height: float = block_size * block_count + jump_clearance
		var upward := Vector2(0.0, -jump_height)

		if test_move(global_transform, upward):
			continue

		var raised_transform: Transform2D = global_transform
		raised_transform.origin += upward

		if test_move(raised_transform, forward):
			continue

		velocity.y = -sqrt(2.0 * gravity_y * jump_height)
		return

func move_toward_position(destination: Vector2, stop_distance: float) -> void:
	var horizontal_distance: float = destination.x - global_position.x

	if absf(horizontal_distance) > stop_distance:
		velocity.x = signf(horizontal_distance) * speed

	if not is_zero_approx(horizontal_distance):
		animation.flip_h = horizontal_distance > 0.0

func start_return() -> void:
	state = State.RETURN
	best_return_distance = global_position.distance_to(base_position)
	return_stuck_time = 0.0

func _on_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		target = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
