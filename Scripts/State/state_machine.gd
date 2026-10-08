extends Node
class_name StateMachine

@export var initial_state: BaseState

var current_state: BaseState
var states: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child is BaseState:
			states[StringName(child.name)] = child
			set_state_active(child, false)
			child.transitioned.connect(
				_on_transitioned.bind(child)
			)


func start() -> void:
	if current_state != null:
		return

	if initial_state == null or initial_state.get_parent() != self:
		push_error("L'état initial doit être un enfant de la StateMachine.")
		return

	current_state = initial_state
	set_state_active(current_state, true)
	current_state.enter()


func set_state_active(state: BaseState, active: bool) -> void:
	state.set_process(active)
	state.set_physics_process(active)


func _on_transitioned(next_state_name: StringName, requesting_state: BaseState) -> void:
	if requesting_state != current_state:
		return

	var next_state: BaseState = states.get(next_state_name)

	if next_state == null:
		push_error("État inconnu : %s" % next_state_name)
		return

	if next_state == current_state:
		return

	set_state_active(current_state, false)
	current_state.exit()

	current_state = next_state
	set_state_active(current_state, true)
	current_state.enter()
