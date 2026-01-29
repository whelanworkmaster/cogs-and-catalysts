extends Node2D

class_name EnemyThreatVisual

@export var ring_width: float = 2.0
@export var ring_color: Color = Color(1.0, 0.4, 0.4, 0.25)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var enemy := get_parent()
	if enemy == null:
		return
	if not CombatManager or not CombatManager.active_combat:
		return
	if not enemy.has_method("get_attack_contact_distance"):
		return
	var radius: float = float(enemy.get_attack_contact_distance())
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring_color, ring_width)
