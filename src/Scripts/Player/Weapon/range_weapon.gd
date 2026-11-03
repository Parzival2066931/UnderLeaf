class_name RangedWeapon
extends BaseWeapon

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var launch_point: Marker2D

@onready var trajectory: Line2D = $Trajectory

var projectile_gravity: float
var projectile_lifetime: float
var projectile_collision_mask: int
var is_aiming: bool = false

signal shot_requested(projectile_scene: PackedScene, origin: Vector2, initial_velocity: Vector2)



func setup(weapon_player: Player) -> void:
	super.setup(weapon_player)
	
	assert(projectile_scene != null, "Assigne la scène de projectile à Bow.")
	assert(launch_point != null, "Assigne ArrowOrigin à Bow.")

	allows_mining = false
	player.animation.animation_finished.connect(_on_animation_finished)
	
	load_projectile_settings()
	trajectory.hide()


func update_attack() -> void:
	if is_aiming:
		update_aim()

		if Input.is_action_just_released("attack"):
			release_shot()

		return

	if is_attacking:
		return

	if Input.is_action_just_pressed("attack"):
		start_aim()


func start_aim() -> void:
	is_aiming = true
	is_attacking = true

	update_aim()

	player.animation.stop()
	player.animation.play("Attack" + animation_suffix + "Start")


func update_aim() -> void:
	player.animation.flip_h = player.get_global_mouse_position().x < player.global_position.x
	update_trajectory()

func release_shot() -> void:
	is_aiming = false
	trajectory.hide()

	var origin := launch_point.global_position
	var direction := origin.direction_to(player.get_global_mouse_position())
	var initial_velocity := direction * projectile_speed

	player.animation.stop()
	player.animation.play("Attack" + animation_suffix + "End")

	shot_requested.emit(projectile_scene, origin, initial_velocity)

func load_projectile_settings() -> void:
	var arrow := projectile_scene.instantiate() as Arrow
	assert(arrow != null, "La scène de projectile doit utiliser le script Arrow.")

	projectile_gravity = arrow.gravity
	projectile_lifetime = arrow.lifetime

	var collision_ray := arrow.get_node("RayCast2D") as RayCast2D
	projectile_collision_mask = collision_ray.collision_mask

	arrow.free()

func update_trajectory() -> void:
	var simulated_position := launch_point.global_position
	var direction := simulated_position.direction_to(player.get_global_mouse_position())
	var simulated_velocity := direction * projectile_speed
	var acceleration := Vector2(0.0, projectile_gravity)

	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var remaining_lifetime := projectile_lifetime

	var points := PackedVector2Array()
	points.append(trajectory.to_local(simulated_position))

	var space := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.collision_mask = projectile_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.hit_from_inside = true

	while remaining_lifetime > 0.0:
		remaining_lifetime -= step

		if remaining_lifetime <= 0.0:
			break

		var movement := simulated_velocity * step + acceleration * step * step * 0.5
		var next_position := simulated_position + movement

		query.from = simulated_position
		query.to = next_position

		var collision := space.intersect_ray(query)

		if not collision.is_empty():
			var impact_position: Vector2 = collision["position"]
			points.append(trajectory.to_local(impact_position))
			break

		simulated_position = next_position
		simulated_velocity += acceleration * step

		points.append(trajectory.to_local(simulated_position))

	trajectory.points = points
	trajectory.show()

func _on_animation_finished() -> void:
	if not is_attacking or is_aiming:
		return

	if player.animation.animation != StringName("Attack" + animation_suffix + "End"):
		return

	is_attacking = false


func cancel_attack() -> void:
	is_aiming = false
	is_attacking = false
	trajectory.hide()
