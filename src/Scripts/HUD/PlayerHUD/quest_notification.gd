extends PanelContainer
class_name QuestNotification

@export var display_duration: float = 3.0
@export var fade_duration: float = 0.4

@onready var quest_name_label: Label = $MarginContainer/VBoxContainer/QuestName

var notification_tween: Tween


func _ready() -> void:
	hide()
	visibility_changed.connect(_on_visibility_changed)


func show_completed(quest_title: String) -> void:
	clear_notification()

	quest_name_label.text = quest_title
	modulate.a = 1.0
	show()

	notification_tween = create_tween()
	notification_tween.tween_interval(display_duration)
	notification_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	notification_tween.tween_callback(hide)


func clear_notification() -> void:
	if notification_tween != null:
		notification_tween.kill()
		notification_tween = null

	hide()
	modulate.a = 1.0


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		clear_notification()
