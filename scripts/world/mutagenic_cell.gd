extends Node2D

class_name MutagenicCell

@export var value: int = 1
var pickup_area: Area2D

func _ready() -> void:
	_create_visual()
	_create_pickup_area()
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

func _create_pickup_area() -> void:
	pickup_area = Area2D.new()
	pickup_area.monitoring = true
	add_child(pickup_area)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	pickup_area.add_child(shape)
	pickup_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if body.has_method("add_mutagenic_cells"):
		body.add_mutagenic_cells(value)
	queue_free()
