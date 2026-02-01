extends MeshInstance3D

@export var grid_color: Color = Color(0.2, 0.6, 0.8, 0.25)

var _obstacle_rects: Array[Rect2] = []

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = grid_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	material_override = mat
	_cache_obstacles()
	_rebuild_mesh()

func refresh() -> void:
	_cache_obstacles()
	_rebuild_mesh()

func _rebuild_mesh() -> void:
	var bounds: Vector2 = _get_nav_bounds()
	var cell: Vector2 = _get_cell_size()
	var origin: Vector2 = _get_grid_origin()
	if cell.x <= 0.0 or cell.y <= 0.0:
		return
	var half: Vector2 = bounds * 0.5
	if origin == Vector2.ZERO:
		origin = Vector2(-half.x, -half.y)
	var cols: int = int(ceilf(bounds.x / cell.x))
	var rows: int = int(ceilf(bounds.y / cell.y))
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var y_offset := 0.05
	for y in range(rows):
		for x in range(cols):
			var center := origin + Vector2((x + 0.5) * cell.x, (y + 0.5) * cell.y)
			if _point_in_obstacles(center):
				continue
			var hx := cell.x * 0.5
			var hz := cell.y * 0.5
			# Four edges of the cell as line segments on XZ plane
			# Bottom edge (min Z)
			im.surface_add_vertex(Vector3(center.x - hx, y_offset, center.y - hz))
			im.surface_add_vertex(Vector3(center.x + hx, y_offset, center.y - hz))
			# Right edge (max X)
			im.surface_add_vertex(Vector3(center.x + hx, y_offset, center.y - hz))
			im.surface_add_vertex(Vector3(center.x + hx, y_offset, center.y + hz))
			# Top edge (max Z)
			im.surface_add_vertex(Vector3(center.x + hx, y_offset, center.y + hz))
			im.surface_add_vertex(Vector3(center.x - hx, y_offset, center.y + hz))
			# Left edge (min X)
			im.surface_add_vertex(Vector3(center.x - hx, y_offset, center.y + hz))
			im.surface_add_vertex(Vector3(center.x - hx, y_offset, center.y - hz))
	im.surface_end()
	mesh = im

func _get_nav_bounds() -> Vector2:
	var parent_main := get_parent()
	if parent_main and parent_main.has_method("get"):
		var value: Variant = parent_main.get("nav_bounds_size")
		if value is Vector2:
			return value
	return Vector2(1200, 840)

func _get_cell_size() -> Vector2:
	var parent_main := get_parent()
	if parent_main and parent_main.has_method("get"):
		var value: Variant = parent_main.get("grid_cell_size")
		if value is Vector2:
			return value
	return Vector2(32, 32)

func _get_grid_origin() -> Vector2:
	var parent_main := get_parent()
	if parent_main and parent_main.has_method("get"):
		var value: Variant = parent_main.get("_grid_origin")
		if value is Vector2:
			return value
	return Vector2.ZERO

func _cache_obstacles() -> void:
	_obstacle_rects.clear()
	var obstacles: Array[Node] = _get_nav_obstacles()
	for obstacle in obstacles:
		var rect := _get_obstacle_rect(obstacle)
		if rect.size != Vector2.ZERO:
			_obstacle_rects.append(rect)

func _point_in_obstacles(pos: Vector2) -> bool:
	for rect in _obstacle_rects:
		if rect.has_point(pos):
			return true
	return false

func _get_obstacle_rect(zone: Node) -> Rect2:
	# Try 3D shape
	var shape_3d := zone.get_node_or_null("ElevationBlocker/CollisionShape3D")
	if shape_3d and shape_3d is CollisionShape3D:
		var box_shape := shape_3d.shape as BoxShape3D
		if box_shape:
			var world_pos: Vector3 = shape_3d.global_transform.origin
			var xz_size := Vector2(box_shape.size.x, box_shape.size.z)
			return Rect2(Vector2(world_pos.x, world_pos.z) - xz_size * 0.5, xz_size)
	return Rect2()

func _get_nav_obstacles() -> Array[Node]:
	var raw := get_tree().get_nodes_in_group("nav_obstacle")
	var typed: Array[Node] = []
	for node in raw:
		if node is Node:
			typed.append(node)
	if typed.is_empty():
		var root := get_tree().current_scene
		if root:
			for type_name in ["Area3D", "Area2D"]:
				var found := root.find_children("", type_name, true, false)
				for node in found:
					if node is Node and node.has_node("ElevationBlocker"):
						typed.append(node)
	return typed
