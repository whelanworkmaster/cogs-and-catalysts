extends Node2D

class_name MutagenicCell

@export var value: int = 1

func _ready() -> void:
	_create_visual()
	_start_pulse()

func _create_visual() -> void:
	var color_rect := ColorRect.new()
	color_rect.size = Vector2(12, 12)
	color_rect.color = Color(0.2, 0.95, 0.6)
	color_rect.position = Vector2(-6, -6)
	add_child(color_rect)

func _start_pulse() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)
