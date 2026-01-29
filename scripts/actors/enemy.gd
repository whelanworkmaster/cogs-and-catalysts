extends CharacterBody2D

class_name Enemy

const MutagenicCell = preload("res://scripts/world/mutagenic_cell.gd")

@export var max_hp: int = 8
@export var max_ap: int = 6
@export var move_step: float = 32.0
@export var attack_contact_distance: float = 40.0
@export var attack_damage: int = 2
var current_ap: int = 6
var current_hp: int = 0
@onready var ai = $AI

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
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

func attack(target: Node) -> void:
	if not target:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)

func end_turn() -> void:
	if CombatManager:
		CombatManager.end_turn()

func get_current_ap() -> int:
	return current_ap

func get_max_ap() -> int:
	return max_ap

func get_current_hp() -> int:
	return current_hp

func get_max_hp() -> int:
	return max_hp

func get_attack_contact_distance() -> float:
	return attack_contact_distance

func get_ai() -> Node:
	return ai

func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0:
		return
	current_hp = max(current_hp - amount, 0)
	print("%s took %s damage. HP: %s/%s" % [name, amount, current_hp, max_hp])
	if current_hp <= 0:
		_die()

func _die() -> void:
	if CombatManager:
		CombatManager.remove_actor(self)
	_drop_mutagenic_cell()
	_play_death_effect()
	queue_free()

func _drop_mutagenic_cell() -> void:
	var cell := MutagenicCell.new()
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		scene.add_child(cell)
	else:
		get_parent().add_child(cell)
	cell.global_position = global_position

func _play_death_effect() -> void:
	if not has_node("Sprite2D"):
		return
	var sprite := $Sprite2D
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
