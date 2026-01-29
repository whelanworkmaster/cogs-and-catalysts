extends Node2D

@export var auto_start_combat: bool = true
@export var use_procgen: bool = true
@export var enemy_count: int = 2
@export var building_count_min: int = 4
@export var building_count_max: int = 6
@export var allow_building_spawn: bool = true
@export var vent_count_min: int = 2
@export var vent_count_max: int = 3
@export var allow_vent_spawn: bool = true
@export var min_vent_obstacle_spacing: float = 40.0
@export var min_vent_enemy_spacing: float = 80.0
@export var min_vent_player_spacing: float = 80.0
@export var min_vent_spacing: float = 80.0
@export var debug_procgen: bool = false
@export var min_enemy_spacing: float = 120.0
@export var min_player_enemy_spacing: float = 180.0
@export var min_player_obstacle_spacing: float = 80.0
@export var obstacle_spacing: float = 120.0
@export var procgen_seed: int = 0
@export var procgen_margin: Vector2 = Vector2(80, 80)
@export var nav_bounds_size: Vector2 = Vector2(1200, 840)
@export var grid_cell_size: Vector2 = Vector2(32, 32)
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
var _astar := AStarGrid2D.new()
var _grid_origin: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const STEAM_VENT_SCRIPT := preload("res://scripts/world/steam_vent.gd")
const INVALID_POS := Vector2.INF

func _ready() -> void:
	call_deferred("_post_scene_setup")

func _post_scene_setup() -> void:
	if use_procgen:
		_setup_procgen()
	_build_navigation()
	_build_astar_grid()
	if auto_start_combat:
		_start_combat()

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
	var obstacles: Array[Node] = _get_nav_obstacles()
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
	var obstacles: Array[Node] = _get_nav_obstacles()
	if obstacles.is_empty():
		var root := get_tree().current_scene
		if root:
			var found := root.find_children("", "Area2D", true, false)
			var filtered: Array[Node] = []
			for node in found:
				if node is Node and node.has_node("ElevationBlocker"):
					filtered.append(node)
			obstacles = filtered
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
		_mark_rect_solid(rect)

func _mark_rect_solid(rect: Rect2) -> void:
	var start: Vector2i = _world_to_cell(rect.position)
	var end: Vector2i = _world_to_cell(rect.position + rect.size)
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
	start = _clamp_cell_to_bounds(start)
	end = _clamp_cell_to_bounds(end)
	if not _astar.is_in_boundsv(start) or not _astar.is_in_boundsv(end):
		return PackedVector2Array()
	if _astar.is_point_solid(start):
		var fixed_start := _find_nearest_walkable(start)
		if _astar.is_in_boundsv(fixed_start):
			start = fixed_start
	if _astar.is_point_solid(end):
		var fixed_end := _find_nearest_walkable(end)
		if _astar.is_in_boundsv(fixed_end):
			end = fixed_end
	var cell_path := _astar.get_id_path(start, end)
	var world_path := PackedVector2Array()
	for cell in cell_path:
		world_path.append(_cell_to_world(cell))
	return world_path

func _clamp_cell_to_bounds(cell: Vector2i) -> Vector2i:
	if not _astar or _astar.region.size.length_squared() == 0.0:
		return cell
	var min_cell := _world_to_cell(_astar.region.position)
	var max_cell := _world_to_cell(_astar.region.position + _astar.region.size)
	return Vector2i(
		clampi(cell.x, min_cell.x, max_cell.x),
		clampi(cell.y, min_cell.y, max_cell.y)
	)

func _find_nearest_walkable(origin: Vector2i, max_radius: int = 10) -> Vector2i:
	if _astar.is_in_boundsv(origin) and not _astar.is_point_solid(origin):
		return origin
	for radius in range(1, max_radius + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if abs(x) != radius and abs(y) != radius:
					continue
				var cell := Vector2i(origin.x + x, origin.y + y)
				if _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell):
					return cell
	return origin

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

func _setup_procgen() -> void:
	_seed_rng()
	if debug_procgen:
		print("Procgen: seed=", procgen_seed, " margin=", procgen_margin, " buildings=", building_count_min, "-", building_count_max, " vents=", vent_count_min, "-", vent_count_max, " enemies=", enemy_count)
	_randomize_obstacles()
	_spawn_enemies()
	_position_player()
	_randomize_steam_vents()

func _seed_rng() -> void:
	if procgen_seed != 0:
		_rng.seed = procgen_seed
	else:
		_rng.randomize()

func _randomize_obstacles() -> void:
	var obstacles: Array[Node] = _get_nav_obstacles()
	if obstacles.is_empty():
		if debug_procgen:
			print("Procgen: no nav_obstacle nodes found.")
		return
	if debug_procgen:
		for obstacle in obstacles:
			var zone := obstacle as Node2D
			if zone:
				print("Procgen: obstacle before ", zone.name, " pos=", zone.global_position)
	if allow_building_spawn:
		var min_count: int = max(building_count_min, 0)
		var max_count: int = max(building_count_max, 0)
		if max_count < min_count:
			var temp := max_count
			max_count = min_count
			min_count = temp
		var desired: int = _rng.randi_range(min_count, max_count)
		if desired < obstacles.size():
			for i in range(desired, obstacles.size()):
				var extra: Node = obstacles[i]
				extra.queue_free()
		elif desired > obstacles.size():
			var to_add: int = desired - obstacles.size()
			for i in range(to_add):
				var template: Node = obstacles[_rng.randi_range(0, obstacles.size() - 1)]
				var clone_any := template.duplicate()
				if not (clone_any is Node):
					continue
				var clone: Node = clone_any
				clone.name = "%s_%s" % [template.name, i + 1]
				add_child(clone)
		obstacles = _get_nav_obstacles()
	var placed_rects: Array[Rect2] = []
	for obstacle in obstacles:
		var zone := obstacle as Node2D
		if not zone:
			continue
		var rect := _get_obstacle_rect(zone)
		if rect.size == Vector2.ZERO:
			if debug_procgen:
				print("Procgen: obstacle ", zone.name, " has no rect; skipping.")
			continue
		var placed: Vector2 = _try_place_rect(rect.size, placed_rects)
		if _is_valid_position(placed):
			if debug_procgen:
				print("Procgen: obstacle moved ", zone.name, " size=", rect.size, " to=", placed)
			zone.global_position = placed
			var new_rect := Rect2(placed - rect.size * 0.5, rect.size)
			placed_rects.append(new_rect)
		elif debug_procgen:
			print("Procgen: failed to place obstacle ", zone.name, " size=", rect.size)

func _randomize_steam_vents() -> void:
	var vents: Array[Node] = _get_steam_vents()
	if vents.is_empty():
		if debug_procgen:
			print("Procgen: no steam_vent nodes found.")
		return
	if debug_procgen:
		for vent in vents:
			var node := vent as Node2D
			if node:
				print("Procgen: vent before ", node.name, " pos=", node.global_position)
	if allow_vent_spawn:
		var min_count: int = max(vent_count_min, 0)
		var max_count: int = max(vent_count_max, 0)
		if max_count < min_count:
			var temp := max_count
			max_count = min_count
			min_count = temp
		var desired: int = _rng.randi_range(min_count, max_count)
		if debug_procgen:
			print("Procgen: vents desired=", desired, " existing=", vents.size())
		if desired < vents.size():
			for i in range(desired, vents.size()):
				var extra: Node = vents[i]
				extra.queue_free()
		elif desired > vents.size():
			var to_add: int = desired - vents.size()
			for i in range(to_add):
				var template: Node = vents[_rng.randi_range(0, vents.size() - 1)]
				var clone_any := template.duplicate()
				if not (clone_any is Node):
					continue
				var clone: Node = clone_any
				clone.name = "%s_%s" % [template.name, i + 1]
				add_child(clone)
		vents = _get_steam_vents()
	var avoid_points: Array[Vector2] = []
	var player_pos: Vector2 = INVALID_POS
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		player_pos = (player as Node2D).global_position
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy is Node2D:
			avoid_points.append((enemy as Node2D).global_position)
	var placed_vents: Array[Vector2] = []
	for vent in vents:
		var node := vent as Node2D
		if not node:
			continue
		var pos: Vector2 = _pick_vent_position(avoid_points, placed_vents, player_pos)
		if _is_valid_position(pos):
			if debug_procgen:
				print("Procgen: vent moved ", node.name, " to=", pos)
			node.global_position = pos
			placed_vents.append(pos)
		elif debug_procgen:
			print("Procgen: failed to place vent ", node.name)

func _spawn_enemies() -> void:
	var existing := get_tree().get_nodes_in_group("enemy")
	for i in range(existing.size(), enemy_count):
		var enemy := ENEMY_SCENE.instantiate()
		add_child(enemy)
	for i in range(enemy_count, existing.size()):
		var extra := existing[i]
		if extra:
			extra.queue_free()
	var enemies := get_tree().get_nodes_in_group("enemy")
	var placed: Array[Vector2] = []
	for enemy in enemies:
		var node := enemy as Node2D
		if not node:
			continue
		var pos: Vector2 = _pick_position(placed, min_enemy_spacing)
		if _is_valid_position(pos):
			node.global_position = pos
			placed.append(pos)

func _position_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var avoid: Array[Vector2] = []
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy is Node2D:
			avoid.append((enemy as Node2D).global_position)
	var pos: Vector2 = _pick_position(avoid, min_player_enemy_spacing, min_player_obstacle_spacing)
	if _is_valid_position(pos):
		player.global_position = pos

func _try_place_rect(size: Vector2, placed_rects: Array[Rect2]) -> Vector2:
	var attempts := 30
	for _i in range(attempts):
		var pos: Vector2 = _random_position_in_bounds()
		var rect := Rect2(pos - size * 0.5, size)
		if _rects_overlap(rect, placed_rects, obstacle_spacing):
			continue
		return pos
	return INVALID_POS

func _rects_overlap(rect: Rect2, placed_rects: Array[Rect2], padding: float) -> bool:
	for existing in placed_rects:
		var expanded: Rect2 = existing.grow(padding)
		if expanded.intersects(rect):
			return true
	return false

func _pick_position(avoid_points: Array[Vector2] = [], min_spacing: float = 0.0, min_obstacle_spacing: float = 0.0) -> Vector2:
	var attempts := 40
	for _i in range(attempts):
		var pos: Vector2 = _random_position_in_bounds()
		if _is_point_inside_obstacle(pos):
			continue
		if min_obstacle_spacing > 0.0 and _is_near_obstacle(pos, min_obstacle_spacing):
			continue
		if min_spacing > 0.0 and _is_near_points(pos, avoid_points, min_spacing):
			continue
		return pos
	return INVALID_POS

func _random_position_in_bounds() -> Vector2:
	var half := nav_bounds_size * 0.5
	var min_x := -half.x + procgen_margin.x
	var max_x := half.x - procgen_margin.x
	var min_y := -half.y + procgen_margin.y
	var max_y := half.y - procgen_margin.y
	return Vector2(_rng.randf_range(min_x, max_x), _rng.randf_range(min_y, max_y))

func _is_near_points(pos: Vector2, points: Array[Vector2], min_spacing: float) -> bool:
	for point in points:
		if pos.distance_to(point) < min_spacing:
			return true
	return false

func _is_valid_position(pos: Vector2) -> bool:
	return pos != INVALID_POS

func _pick_vent_position(avoid_points: Array[Vector2], placed_vents: Array[Vector2], player_pos: Vector2) -> Vector2:
	var attempts := 40
	for _i in range(attempts):
		var pos: Vector2 = _random_position_in_bounds()
		if _is_point_inside_obstacle(pos):
			continue
		if min_vent_obstacle_spacing > 0.0 and _is_near_obstacle(pos, min_vent_obstacle_spacing):
			continue
		if min_vent_enemy_spacing > 0.0 and _is_near_points(pos, avoid_points, min_vent_enemy_spacing):
			continue
		if min_vent_spacing > 0.0 and _is_near_points(pos, placed_vents, min_vent_spacing):
			continue
		if _is_valid_position(player_pos) and pos.distance_to(player_pos) < min_vent_player_spacing:
			continue
		return pos
	return INVALID_POS

func _is_point_inside_obstacle(pos: Vector2) -> bool:
	var obstacles: Array[Node] = _get_nav_obstacles()
	for obstacle in obstacles:
		var zone := obstacle as Node2D
		if not zone:
			continue
		var rect := _get_obstacle_rect(zone)
		if rect.size != Vector2.ZERO and rect.has_point(pos):
			return true
	return false

func _is_near_obstacle(pos: Vector2, min_spacing: float) -> bool:
	var obstacles: Array[Node] = _get_nav_obstacles()
	for obstacle in obstacles:
		var zone := obstacle as Node2D
		if not zone:
			continue
		var rect := _get_obstacle_rect(zone)
		if rect.size == Vector2.ZERO:
			continue
		if rect.grow(min_spacing).has_point(pos):
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

func _get_steam_vents() -> Array[Node]:
	var raw := get_tree().get_nodes_in_group("steam_vent")
	var typed: Array[Node] = []
	for node in raw:
		if node is Node:
			typed.append(node)
	if typed.is_empty():
		var root := get_tree().current_scene
		if root:
			var found := root.find_children("", "Area2D", true, false)
			for node in found:
				if node is Node and node.get_script() == STEAM_VENT_SCRIPT:
					typed.append(node)
	return typed
