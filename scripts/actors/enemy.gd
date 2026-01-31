extends CharacterBody2D

class_name Enemy

const DamagePopup = preload("res://scripts/ui/damage_popup.gd")
const EnemyThreatVisual = preload("res://scripts/ui/enemy_threat_visual.gd")

const MutagenicCell = preload("res://scripts/world/mutagenic_cell.gd")

@export var max_hp: int = 8
@export var max_ap: int = 10
@export var move_step: float = 32.0
@export var attack_contact_distance: float = 40.0
@export var attack_damage: int = 2
@export var ranged_attack_range: float = 240.0
@export var ranged_attack_damage: int = 2
var current_ap: int = 0
var current_hp: int = 0
@onready var ai = $AI
@onready var attack_area: Area2D = $AttackArea
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var _hit_tween: Tween

func _ready() -> void:
	current_hp = max_hp
	current_ap = max_ap
	add_to_group("enemy")
	_configure_attack_area()
	_create_enemy_sprite()
	_create_threat_visual()
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_started)

func _create_enemy_sprite() -> void:
	var sprite := $Sprite2D
	_build_depth_block(sprite, Vector2(28, 28), Color(0.9, 0.2, 0.2), 6.0)

func _build_depth_block(sprite: Node, size: Vector2, base_color: Color, depth: float) -> void:
	if not sprite:
		return
	for child in sprite.get_children():
		child.queue_free()
	var shadow := ColorRect.new()
	shadow.size = size
	shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	shadow.position = Vector2(-size.x * 0.5 + depth * 0.4, -size.y * 0.5 + depth * 0.6)
	shadow.z_index = -3
	sprite.add_child(shadow)

	var side := ColorRect.new()
	side.size = Vector2(size.x, depth)
	side.color = base_color.darkened(0.4)
	side.position = Vector2(-size.x * 0.5, size.y * 0.5)
	side.z_index = -1
	sprite.add_child(side)

	var top := ColorRect.new()
	top.size = size
	top.color = base_color
	top.position = Vector2(-size.x * 0.5, -size.y * 0.5)
	top.z_index = 0
	sprite.add_child(top)

	var highlight := ColorRect.new()
	highlight.size = Vector2(size.x, 3.0)
	highlight.color = Color(1.0, 1.0, 1.0, 0.12)
	highlight.position = top.position
	highlight.z_index = 1
	sprite.add_child(highlight)

func move_towards(target_position: Vector2, distance: float = 0.0) -> void:
	var step := distance if distance > 0.0 else move_step
	var world := get_tree().current_scene
	if world and world.has_method("get_astar_path"):
		var path: PackedVector2Array = world.get_astar_path(global_position, target_position)
		if path.size() > 1:
			var next_pos: Vector2 = path[1]
			if world.has_method("snap_to_grid"):
				next_pos = world.snap_to_grid(next_pos)
			var to_next := next_pos - global_position
			if to_next == Vector2.ZERO:
				return
			var motion: Vector2 = to_next.normalized() * min(step, to_next.length())
			var collision: KinematicCollision2D = move_and_collide(motion)
			if collision == null and world.has_method("snap_to_grid"):
				global_position = world.snap_to_grid(global_position)
			return
		print("Enemy path empty or too short. pos=", global_position, " target=", target_position, " path_size=", path.size())
		return

func attack(target: Node) -> void:
	if not target:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)

func can_attack_ranged(target: Node) -> bool:
	if not target:
		return false
	if global_position.distance_to(target.global_position) > ranged_attack_range:
		return false
	return _has_clear_shot(target)

func ranged_attack(target: Node) -> void:
	if not target:
		return
	if not _has_clear_shot(target):
		return
	_spawn_ranged_shot_line(target.global_position)
	if target.has_method("take_damage"):
		target.take_damage(ranged_attack_damage, self)

func _has_clear_shot(target: Node) -> bool:
	var space := get_world_2d().direct_space_state if get_world_2d() else null
	if not space:
		return true
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result := space.intersect_ray(query)
	if result.is_empty():
		return true
	return result.collider == target

func _spawn_ranged_shot_line(target_pos: Vector2) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if not scene:
		return
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.6, 0.2, 0.9)
	line.points = PackedVector2Array([global_position, target_pos])
	line.z_index = 6
	scene.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.12)
	tween.tween_callback(line.queue_free)

func end_turn() -> void:
	if CombatManager:
		CombatManager.end_turn()

func get_current_ap() -> int:
	return current_ap

func get_max_ap() -> int:
	return max_ap

func spend_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		return true
	return false

func reset_ap() -> void:
	current_ap = max_ap

func get_current_hp() -> int:
	return current_hp

func get_max_hp() -> int:
	return max_hp

func get_attack_contact_distance() -> float:
	return attack_contact_distance

func get_ranged_attack_range() -> float:
	return ranged_attack_range

func get_attack_targets() -> Array:
	if not attack_area:
		return []
	var bodies := attack_area.get_overlapping_bodies()
	var targets: Array = []
	for body in bodies:
		if body != null and body.is_in_group("player"):
			targets.append(body)
	return targets

func get_ai() -> Node:
	return ai

func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0:
		return
	current_hp = max(current_hp - amount, 0)
	print("%s took %s damage. HP: %s/%s" % [name, amount, current_hp, max_hp])
	_spawn_damage_popup(amount, Color(1.0, 0.35, 0.35))
	_play_hit_feedback()
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

func _configure_attack_area() -> void:
	if not attack_area:
		return
	attack_area.monitoring = true
	var shape_node := attack_area.get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape and shape_node.shape is CircleShape2D:
		shape_node.shape.radius = attack_contact_distance

func _play_hit_feedback() -> void:
	if not has_node("Sprite2D"):
		return
	var sprite := $Sprite2D
	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(sprite, "scale", Vector2(1.08, 0.92), 0.06)
	_hit_tween.tween_property(sprite, "scale", Vector2.ONE, 0.08)
	if sprite.get_child_count() > 0:
		var rect := sprite.get_child(0)
		if rect is ColorRect:
			var base_color: Color = rect.color
			_hit_tween.parallel().tween_property(rect, "color", Color(1.0, 1.0, 1.0), 0.05)
			_hit_tween.tween_property(rect, "color", base_color, 0.08)

func _spawn_damage_popup(amount: int, color: Color) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if not scene:
		return
	var popup := DamagePopup.new()
	popup.amount = amount
	popup.color = color
	popup.global_position = global_position + Vector2(0, -20)
	scene.add_child(popup)

func _create_threat_visual() -> void:
	if has_node("ThreatVisual"):
		return
	var ring := Node2D.new()
	ring.name = "ThreatVisual"
	ring.set_script(EnemyThreatVisual)
	add_child(ring)

func _on_turn_started(actor: Node) -> void:
	if actor == self:
		reset_ap()
