extends CharacterBody2D

class_name Enemy

@export var max_ap: int = 6
@export var move_step: float = 32.0
var current_ap: int = 6
@onready var ai = $AI

func _ready() -> void:
	_create_enemy_sprite()

func _create_enemy_sprite() -> void:
	var sprite := $Sprite2D
	var color_rect := ColorRect.new()
	color_rect.size = Vector2(28, 28)
	color_rect.color = Color(0.9, 0.2, 0.2)
	color_rect.position = Vector2(-14, -14)
	sprite.add_child(color_rect)

func move_towards(target_position: Vector2, distance: float = 0.0) -> void:
	var step := distance if distance > 0.0 else move_step
	var direction := (target_position - global_position).normalized()
	global_position += direction * step

func end_turn() -> void:
	if CombatManager:
		CombatManager.end_turn()

func get_current_ap() -> int:
	return current_ap

func get_max_ap() -> int:
	return max_ap

func get_ai() -> Node:
	return ai
