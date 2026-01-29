extends Node2D

class_name DamagePopup

@export var amount: int = 0
@export var color: Color = Color(1.0, 0.35, 0.35)
@export var rise_distance: float = 18.0
@export var duration: float = 0.6

func _ready() -> void:
	_create_label()
	_play()

func _create_label() -> void:
	var label := Label.new()
	label.text = str(amount)
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-6, -10)
	add_child(label)

func _play() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", position + Vector2(0, -rise_distance), duration)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)
