extends StaticBody3D

class_name CoverSegment

const KAYKIT_CUBE_SCENE := preload("res://addons/kaykit_prototype_bits/Assets/gltf/Primitive_Cube.gltf")

@export var cover_size: Vector2 = Vector2(32.0, 32.0)
@export var cover_height: float = 16.0
@export var cover_strength: float = 0.5
@export var cover_use_distance: float = 36.0
@export var cover_color: Color = Color(0.32, 0.36, 0.4, 1.0)

func _ready() -> void:
	add_to_group("cover")
	add_to_group("nav_obstacle")
	_build_visual()
	_build_blocker()

func evaluate_cover(attacker_pos: Vector3, target_pos: Vector3) -> Dictionary:
	var local_attacker := to_local(attacker_pos)
	var local_target := to_local(target_pos)
	var half_extents := cover_size * 0.5
	if local_target.y > cover_height + 24.0:
		return {"applies": false}
	var target_xz := Vector2(local_target.x, local_target.z)
	var attacker_xz := Vector2(local_attacker.x, local_attacker.z)
	if _distance_to_rect(target_xz, half_extents) > cover_use_distance:
		return {"applies": false}
	if not _segment_intersects_rect(attacker_xz, target_xz, half_extents):
		return {"applies": false}
	var target_side := _get_cover_side(target_xz)
	var attacker_side := _get_cover_side(attacker_xz)
	if target_side == 0 or attacker_side == 0:
		return {"applies": false}
	if target_side == attacker_side:
		return {"applies": false}
	var impact_xz := _segment_rect_impact_point(attacker_xz, target_xz, half_extents)
	if impact_xz == Vector2.INF:
		return {"applies": false}
	var impact_local := Vector3(impact_xz.x, cover_height * 0.85, impact_xz.y)
	return {
		"applies": true,
		"multiplier": cover_strength,
		"impact_position": to_global(impact_local)
	}

func _build_visual() -> void:
	var visual_root := Node3D.new()
	visual_root.name = "CoverMesh"
	add_child(visual_root)
	var instanced := KAYKIT_CUBE_SCENE.instantiate()
	if instanced is Node3D:
		var model := instanced as Node3D
		model.position = Vector3(0.0, 0.0, 0.0)
		model.scale = Vector3(cover_size.x / 4.0, cover_height / 4.0, cover_size.y / 4.0)
		visual_root.add_child(model)
		return
	var fallback := CSGBox3D.new()
	fallback.size = Vector3(cover_size.x, cover_height, cover_size.y)
	fallback.transform.origin = Vector3(0.0, cover_height * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cover_color
	fallback.material = mat
	visual_root.add_child(fallback)

func _build_blocker() -> void:
	var blocker := StaticBody3D.new()
	blocker.name = "ElevationBlocker"
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(cover_size.x, cover_height, cover_size.y)
	shape_node.shape = box
	shape_node.transform.origin = Vector3(0, cover_height * 0.5, 0)
	blocker.add_child(shape_node)
	add_child(blocker)

func _distance_to_rect(point: Vector2, half_extents: Vector2) -> float:
	var clamped_x := clampf(point.x, -half_extents.x, half_extents.x)
	var clamped_y := clampf(point.y, -half_extents.y, half_extents.y)
	return point.distance_to(Vector2(clamped_x, clamped_y))

func _get_cover_side(point: Vector2) -> int:
	if absf(point.x) > absf(point.y):
		return 1 if point.x >= 0.0 else -1
	if absf(point.y) > 0.0001:
		return 2 if point.y >= 0.0 else -2
	return 0

func _segment_intersects_rect(a: Vector2, b: Vector2, half_extents: Vector2) -> bool:
	return _segment_rect_impact_point(a, b, half_extents) != Vector2.INF

func _segment_rect_impact_point(a: Vector2, b: Vector2, half_extents: Vector2) -> Vector2:
	var min_pt := Vector2(-half_extents.x, -half_extents.y)
	var max_pt := Vector2(half_extents.x, half_extents.y)
	var d := b - a
	var t_min := 0.0
	var t_max := 1.0
	if absf(d.x) < 0.0001:
		if a.x < min_pt.x or a.x > max_pt.x:
			return Vector2.INF
	else:
		var inv_dx := 1.0 / d.x
		var tx1 := (min_pt.x - a.x) * inv_dx
		var tx2 := (max_pt.x - a.x) * inv_dx
		if tx1 > tx2:
			var tx := tx1
			tx1 = tx2
			tx2 = tx
		t_min = maxf(t_min, tx1)
		t_max = minf(t_max, tx2)
		if t_min > t_max:
			return Vector2.INF
	if absf(d.y) < 0.0001:
		if a.y < min_pt.y or a.y > max_pt.y:
			return Vector2.INF
	else:
		var inv_dy := 1.0 / d.y
		var ty1 := (min_pt.y - a.y) * inv_dy
		var ty2 := (max_pt.y - a.y) * inv_dy
		if ty1 > ty2:
			var ty := ty1
			ty1 = ty2
			ty2 = ty
		t_min = maxf(t_min, ty1)
		t_max = minf(t_max, ty2)
		if t_min > t_max:
			return Vector2.INF
	return a + d * t_min
