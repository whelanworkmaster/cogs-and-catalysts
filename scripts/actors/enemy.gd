extends CharacterBody3D

class_name Enemy

const DamagePopup = preload("res://scripts/ui/damage_popup.gd")
const MutagenicCell = preload("res://scripts/world/mutagenic_cell.gd")
const EnemyThreatVisual = preload("res://scripts/ui/enemy_threat_visual.gd")

@export var max_hp: int = 8
@export var max_ap: int = 10
@export var move_step: float = 32.0
@export var attack_contact_distance: float = 40.0
@export var attack_damage: int = 2
@export var ranged_attack_range: float = 240.0
@export var ranged_attack_damage: int = 2
var current_ap: int = 0
var current_hp: int = 0
var current_elevation: int = 0
var current_elevation_height: float = 0.0
@onready var ai = $AI
@onready var attack_area: Area3D = $AttackArea
@onready var elevation_detector: Area3D = $ElevationDetector
var _visual_root: Node3D
var _body_mesh: CSGBox3D
var _hit_tween: Tween

func _ready() -> void:
	current_hp = max_hp
	current_ap = max_ap
	add_to_group("enemy")
	_configure_attack_area()
	elevation_detector.area_entered.connect(_on_elevation_area_entered)
	elevation_detector.area_exited.connect(_on_elevation_area_exited)
	_setup_visual()
	_create_threat_visual()
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_started)

func _setup_visual() -> void:
	_visual_root = $VisualRoot if has_node("VisualRoot") else null
	_body_mesh = $VisualRoot/BodyBox if has_node("VisualRoot/BodyBox") else null
	if _body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.2, 0.2)
		_body_mesh.material = mat

func _on_elevation_area_entered(area: Area3D) -> void:
	if "elevation_level" in area:
		current_elevation = area.elevation_level
		current_elevation_height = area.elevation_height
		_apply_elevation_visuals()

func _on_elevation_area_exited(area: Area3D) -> void:
	if "elevation_level" in area:
		if area.elevation_level == current_elevation:
			current_elevation = 0
			current_elevation_height = 0.0
			_apply_elevation_visuals()

func move_towards(target_position, distance: float = 0.0) -> void:
	var step := distance if distance > 0.0 else move_step
	var world := get_tree().current_scene

	# Convert target to Vector3 if needed
	var target_3d: Vector3
	if target_position is Vector3:
		target_3d = target_position
	elif target_position is Vector2:
		target_3d = Vector3(target_position.x, 0, target_position.y)
	else:
		return

	if world and world.has_method("get_astar_path_3d"):
		var path: PackedVector3Array = world.get_astar_path_3d(global_position, target_3d)
		if path.size() > 1:
			var next_pos: Vector3 = path[1]
			if world.has_method("snap_to_grid"):
				next_pos = world.snap_to_grid(next_pos)
			next_pos.y = global_position.y
			global_position = next_pos
			return
	# Fallback to 2D path
	if world and world.has_method("get_astar_path"):
		var pos_2d := Vector2(global_position.x, global_position.z)
		var target_2d := Vector2(target_3d.x, target_3d.z)
		var path: PackedVector2Array = world.get_astar_path(pos_2d, target_2d)
		if path.size() > 1:
			var next_pos_2d: Vector2 = path[1]
			if world.has_method("snap_to_grid"):
				next_pos_2d = world.snap_to_grid(next_pos_2d)
			global_position = Vector3(next_pos_2d.x, global_position.y, next_pos_2d.y)

func attack(target: Node) -> void:
	if not target:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)

func can_attack_ranged(target: Node) -> bool:
	if not target:
		return false
	if target.has_method("get_elevation_level") and target.get_elevation_level() != current_elevation:
		return false
	if _xz_distance_to(target.global_position) > ranged_attack_range:
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
	var world := get_tree().current_scene
	if world and world.has_method("has_clear_los"):
		return world.has_clear_los(global_position, target.global_position)
	return true

func _spawn_ranged_shot_line(target_pos: Vector3) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if not scene:
		return
	var mesh_instance := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mesh_instance.mesh = im
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mesh_instance.material_override = mat
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(global_position + Vector3(0, 16, 0))
	im.surface_add_vertex(target_pos + Vector3(0, 16, 0))
	im.surface_end()
	scene.add_child(mesh_instance)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(mesh_instance.queue_free)

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

func get_elevation_level() -> int:
	return current_elevation

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
			if body.has_method("get_elevation_level") and body.get_elevation_level() != current_elevation:
				continue
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
	queue_free()

func _drop_mutagenic_cell() -> void:
	var cell := MutagenicCell.new()
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		scene.add_child(cell)
	else:
		get_parent().add_child(cell)
	cell.global_position = global_position

func _apply_elevation_visuals() -> void:
	global_position.y = current_elevation_height

func _configure_attack_area() -> void:
	if not attack_area:
		return
	attack_area.monitoring = true
	var shape_node := attack_area.get_node_or_null("CollisionShape3D")
	if shape_node and shape_node is CollisionShape3D and shape_node.shape is SphereShape3D:
		(shape_node.shape as SphereShape3D).radius = attack_contact_distance

func _play_hit_feedback() -> void:
	if not _visual_root:
		return
	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(_visual_root, "scale", Vector3(1.08, 0.92, 1.08), 0.06)
	_hit_tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.08)
	if _body_mesh and _body_mesh.material:
		var mat: StandardMaterial3D = _body_mesh.material as StandardMaterial3D
		if mat:
			var base_color: Color = mat.albedo_color
			_hit_tween.parallel().tween_property(mat, "albedo_color", Color(1.0, 1.0, 1.0), 0.05)
			_hit_tween.tween_property(mat, "albedo_color", base_color, 0.08)

func _spawn_damage_popup(amount: int, color: Color) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if not scene:
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var world_pos := global_position + Vector3(0, 16, 0)
	var screen_pos := camera.unproject_position(world_pos)
	var popup := DamagePopup.new()
	popup.amount = amount
	popup.color = color
	popup.global_position = screen_pos
	scene.add_child(popup)

func _create_threat_visual() -> void:
	if has_node("ThreatVisual"):
		return
	var ring := MeshInstance3D.new()
	ring.name = "ThreatVisual"
	ring.set_script(EnemyThreatVisual)
	add_child(ring)

func _on_turn_started(actor: Node) -> void:
	if actor == self:
		reset_ap()

## Returns XZ-plane distance from this node to the given position (ignores Y).
func _xz_distance_to(target: Vector3) -> float:
	var a := Vector2(global_position.x, global_position.z)
	var b := Vector2(target.x, target.z)
	return a.distance_to(b)
