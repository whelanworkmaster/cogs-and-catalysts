extends Node2D

@export var grid_color: Color = Color(0.2, 0.6, 0.8, 0.25)
@export var line_width: float = 1.0

var _obstacle_rects: Array[Rect2] = []

func _ready() -> void:
	z_index = -10
	_cache_obstacles()
	queue_redraw()

func refresh() -> void:
	_cache_obstacles()
	queue_redraw()

func _draw() -> void:
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
	for y in range(rows):
		for x in range(cols):
			var center := origin + Vector2((x + 0.5) * cell.x, (y + 0.5) * cell.y)
			if _point_in_obstacles(center):
				continue
			var rect := Rect2(center - cell * 0.5, cell)
			draw_rect(rect, grid_color, false, line_width)

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
		var zone := obstacle as Node2D
		if not zone:
			continue
		var rect := _get_obstacle_rect(zone)
		if rect.size != Vector2.ZERO:
			_obstacle_rects.append(rect)

func _point_in_obstacles(pos: Vector2) -> bool:
	for rect in _obstacle_rects:
		if rect.has_point(pos):
			return true
	return false

func _get_obstacle_rect(zone: Node2D) -> Rect2:
	var shape_node := zone.get_node_or_null("ElevationBlocker/CollisionShape2D")
	if shape_node and shape_node is CollisionShape2D:
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape:
			var world_center: Vector2 = shape_node.global_transform.origin
			var scale: Vector2 = shape_node.global_transform.get_scale().abs()
			var size: Vector2 = rect_shape.size * scale
			return Rect2(world_center - size * 0.5, size)
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
			var found := root.find_children("", "Area2D", true, false)
			for node in found:
				if node is Node and node.has_node("ElevationBlocker"):
					typed.append(node)
	return typed
