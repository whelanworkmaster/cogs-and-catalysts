extends Node2D

@export var auto_start_combat: bool = true
@export var nav_bounds_size: Vector2 = Vector2(1200, 840)
@export var grid_cell_size: Vector2 = Vector2(32, 32)
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
var _astar := AStarGrid2D.new()
var _grid_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	_build_navigation()
	call_deferred("_build_astar_grid")
	if auto_start_combat:
		call_deferred("_start_combat")

func _start_combat() -> void:
	if not CombatManager or CombatManager.active_combat:
		return
	var actors: Array = []
	var player := get_tree().get_first_node_in_group("player")
	if player:
		actors.append(player)
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy != player:
			actors.append(enemy)
	if not actors.is_empty():
		CombatManager.start_combat(actors)

func _build_navigation() -> void:
	if not nav_region:
		return
	var nav_poly := NavigationPolygon.new()
	var half := nav_bounds_size * 0.5
	var outer := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	nav_poly.add_outline(outer)
	var outer_area := _polygon_signed_area(outer)
	var obstacles := get_tree().get_nodes_in_group("nav_obstacle")
	for obstacle in obstacles:
		var zone := obstacle as Node2D
		if not zone:
			continue
		var outline := _build_obstacle_outline(zone)
		if outline.size() > 2:
			if _polygon_signed_area(outline) * outer_area > 0.0:
				outline.reverse()
			nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = nav_poly

func _build_astar_grid() -> void:
	var half := nav_bounds_size * 0.5
	_grid_origin = Vector2(-half.x, -half.y)
	var region := Rect2(_grid_origin, nav_bounds_size)
	_astar.region = region
	_astar.cell_size = grid_cell_size
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	print("AStarGrid2D: region=", region, " cell_size=", grid_cell_size, " origin=", _grid_origin)
	var obstacles := get_tree().get_nodes_in_group("nav_obstacle")
	if obstacles.is_empty():
		var root := get_tree().current_scene
		if root:
			obstacles = root.find_children("", "Area2D", true, false)
			obstacles = obstacles.filter(func(node): return node.has_node("ElevationBlocker"))
	print("AStarGrid2D: obstacles=", obstacles.size())
	for obstacle in obstacles:
		var zone := obstacle as Node2D
		if not zone:
			continue
		var shape_node := zone.get_node_or_null("ElevationBlocker/CollisionShape2D")
		if not (shape_node and shape_node is CollisionShape2D):
			continue
		var rect_shape := shape_node.shape as RectangleShape2D
		if not rect_shape:
			continue
		var world_center: Vector2 = shape_node.global_transform.origin
		var scale: Vector2 = shape_node.global_transform.get_scale().abs()
		var size: Vector2 = rect_shape.size * scale
		var rect := Rect2(world_center - size * 0.5, size)
		print("AStarGrid2D: obstacle rect=", rect)
		_mark_rect_solid(rect)

func _mark_rect_solid(rect: Rect2) -> void:
	var start: Vector2i = _world_to_cell(rect.position)
	var end: Vector2i = _world_to_cell(rect.position + rect.size)
	print("AStarGrid2D: mark solid start=", start, " end=", end)
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var cell := Vector2i(x, y)
			if _astar.is_in_boundsv(cell):
				_astar.set_point_solid(cell, true)

func _world_to_cell(pos: Vector2) -> Vector2i:
	var rel := pos - _grid_origin
	return Vector2i(int(floor(rel.x / grid_cell_size.x)), int(floor(rel.y / grid_cell_size.y)))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return _grid_origin + Vector2(cell.x * grid_cell_size.x, cell.y * grid_cell_size.y) + grid_cell_size * 0.5

func get_astar_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var start: Vector2i = _world_to_cell(from_world)
	var end: Vector2i = _world_to_cell(to_world)
	print("AStarGrid2D: request from=", from_world, " to=", to_world, " start=", start, " end=", end)
	if not _astar.is_in_boundsv(start) or not _astar.is_in_boundsv(end):
		print("AStarGrid2D: out of bounds start/end")
		return PackedVector2Array()
	if _astar.is_point_solid(start) or _astar.is_point_solid(end):
		print("AStarGrid2D: start/end solid start_solid=", _astar.is_point_solid(start), " end_solid=", _astar.is_point_solid(end))
	var cell_path := _astar.get_id_path(start, end)
	var world_path := PackedVector2Array()
	for cell in cell_path:
		world_path.append(_cell_to_world(cell))
	print("AStarGrid2D: path cells=", cell_path.size(), " world_points=", world_path.size())
	return world_path

func _build_obstacle_outline(zone: Node2D) -> PackedVector2Array:
	var shape_node := zone.get_node_or_null("ElevationBlocker/CollisionShape2D")
	if shape_node and shape_node is CollisionShape2D:
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape:
			var half := rect_shape.size * 0.5
			var local_points := [
				Vector2(-half.x, -half.y),
				Vector2(half.x, -half.y),
				Vector2(half.x, half.y),
				Vector2(-half.x, half.y)
			]
			var outline := PackedVector2Array()
			for point in local_points:
				var global_point: Vector2 = shape_node.to_global(point)
				outline.append(nav_region.to_local(global_point))
			return outline
	var poly_node := zone.get_node_or_null("ZoneVisual")
	if poly_node and poly_node is Polygon2D:
		var outline := PackedVector2Array()
		for point in poly_node.polygon:
			var global_point: Vector2 = poly_node.to_global(point)
			outline.append(nav_region.to_local(global_point))
		return outline
	return PackedVector2Array()

func _polygon_signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	var count := points.size()
	if count < 3:
		return 0.0
	for i in range(count):
		var a := points[i]
		var b := points[(i + 1) % count]
		area += (a.x * b.y) - (b.x * a.y)
	return area * 0.5
