@abstract class_name BaseState
extends Node

signal transitioned(next_state: StringName)


@abstract func enter() -> void

@abstract func exit() -> void

@abstract func _process(delta: float) -> void

@abstract func _physics_process(delta: float) -> void
