extends Control
class_name BackgroundColor


@export var world_generator: Node2D
@export_range(0.0, 2.0, 0.05) var daylight_energy: float = 0.8

@export_group("Orbit Settings")
@export var orbit_width := 320
@export var orbit_height := 155
@export var cycle_duration := 30.0


@export_group("Time Settings")
#@export_range(0.0, 1.0, 0.01)
@export var start_phase := 0.0 # 0 = crépuscule à gauche

@onready var sky: ColorRect = $Layer1/Sky
@onready var orbit_center: Marker2D = $Layer1/OrbitCenter
@onready var sun_sprite: Sprite2D = $Layer1/Sun
@onready var moon_sprite: Sprite2D = $Layer1/Moon
@onready var stars: Stars = $Layer1/Stars

@onready var hills: TextureRect = $Layer2/Hills
@onready var static_grass: TextureRect = $Layer2/StaticGrass
@onready var dirt: TextureRect = $Parallax2D/Dirt

@onready var near_grass: TextureRect = $Layer4/NearGrass

# IMPORTANT :
# phase 0.00 = gauche = crépuscule / sunrise
# phase 0.25 = haut = plein jour
# phase 0.50 = droite = crépuscule / sunset
# phase 0.75 = bas = nuit
# phase 1.00 = retour à gauche

@export var sky_steps: Array[Dictionary] = [
	{ "t": 0.00, "color": "#ff8a5b" }, # crépuscule gauche
	{ "t": 0.20, "color": "#6fc8ff" }, # transition rapide vers jour
	{ "t": 0.38, "color": "#6fc8ff" }, # jour long
	{ "t": 0.42, "color": "#ff7a59" }, # crépuscule droite
	{ "t": 0.58, "color": "#0b1026" }, # transition rapide vers nuit
	{ "t": 0.92, "color": "#0b1066" }, # nuit longue
	{ "t": 1.00, "color": "#ff8a5b" }  # retour crépuscule gauche
]

@export var background_steps: Array[Dictionary] = [
	{ "t": 0.00, "color": "#ffd0a8" },
	{ "t": 0.20, "color": "#ffffff" },
	{ "t": 0.38, "color": "#ffffff" },
	{ "t": 0.42, "color": "#ffb08a" },
	{ "t": 0.58, "color": "#5c6da8" },
	{ "t": 0.92, "color": "#5c6da8" },
	{ "t": 1.00, "color": "#ffd0a8" }
]

@export var stars_opacity_steps: Array[Dictionary] = [
	{ "t": 0.00, "a": 0.0 }, # Jour (gauche)
	{ "t": 0.50, "a": 0.0 }, # Début transition soir
	{ "t": 0.60, "a": 1.0 }, # Nuit pleine
	{ "t": 0.85, "a": 1.0 }, # Fin de nuit
	{ "t": 0.95, "a": 0.0 }  # Retour jour
]

var orbit_speed := 0.0
var sun_angle := 0.0
var moon_angle := 0.0

func _ready() -> void:
	orbit_speed = TAU / cycle_duration

	sun_angle = phase_to_angle(start_phase)
	moon_angle = phase_to_angle(wrapf(start_phase + 0.5, 0.0, 1.0))

	update_orbit_positions()
	update_colors_from_orbit()

func _physics_process(delta: float) -> void:
	sun_angle -= orbit_speed * delta
	moon_angle -= orbit_speed * delta

	update_orbit_positions()
	update_colors_from_orbit()

func update_orbit_positions() -> void:
	var center := orbit_center.global_position

	sun_sprite.global_position = center + Vector2(
		cos(sun_angle) * orbit_width,
		-sin(sun_angle) * orbit_height
	)

	moon_sprite.global_position = center + Vector2(
		cos(moon_angle) * orbit_width,
		-sin(moon_angle) * orbit_height
	)

func update_colors_from_orbit() -> void:
	var orbit_phase := angle_to_phase(sun_angle)
	var background_color := sample_color_steps(background_steps, orbit_phase)

	sky.color = sample_color_steps(sky_steps, orbit_phase)

	hills.modulate = background_color
	static_grass.modulate = background_color
	near_grass.modulate = background_color
	
	var sun_height: float = sin(orbit_phase * TAU)
	var daylight: float = smoothstep(0.0, 0.25, sun_height)

	world_generator.set_surface_light(daylight * daylight_energy, background_color)
	

	stars.modulate.a = sample_float_steps(
		stars_opacity_steps,
		orbit_phase
	)



func phase_to_angle(phase: float) -> float:
	var wrapped_phase := wrapf(phase, 0.0, 1.0)
	return PI - wrapped_phase * TAU

func angle_to_phase(angle: float) -> float:
	var wrapped := wrapf(PI - angle, 0.0, TAU)
	return wrapped / TAU

func sample_color_steps(steps: Array[Dictionary], t: float) -> Color:
	if steps.is_empty():
		return Color.WHITE

	if steps.size() == 1:
		return Color(steps[0]["color"])

	for i in range(steps.size() - 1):
		var a := steps[i]
		var b := steps[i + 1]

		var ta: float = a["t"]
		var tb: float = b["t"]

		if t >= ta and t <= tb:
			var local_t := inverse_lerp(ta, tb, t)
			return Color(a["color"]).lerp(Color(b["color"]), local_t)

	return Color(steps[steps.size() - 1]["color"])

func sample_float_steps(steps: Array[Dictionary], t: float) -> float:
	for i in range(steps.size() - 1):
		var a := steps[i]
		var b := steps[i + 1]
		if t >= a["t"] and t <= b["t"]:
			var local_t := inverse_lerp(a["t"], b["t"], t)
			return lerp(float(a["a"]), float(b["a"]), local_t)
	return steps[steps.size() - 1]["a"]
