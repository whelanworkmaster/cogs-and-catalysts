extends Node3D

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
@export var procgen_attempts: int = 50
@export var nav_bounds_size: Vector2 = Vector2(1200, 840)
@export var grid_cell_size: Vector2 = Vector2(32, 32)
var nav_region: Node = null  # NavigationRegion3D placeholder — pathfinding uses AStarGrid2D
var _astar := AStarGrid2D.new()
var _grid_origin: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _base_move_ap_cost: int = 1
var _toxicity_penalty_active: bool = false

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const STEAM_VENT_SCRIPT := preload("res://scripts/world/steam_vent.gd")
const INVALID_POS := Vector2.INF
const INVALID_POS_3D := Vector3.INF
const RUN_STATE_ENCOUNTER := 2
const RUN_STATE_EXTRACTION := 3
const RUN_STATE_RESULTS := 4

func _ready() -> void:
	if CombatManager:
		_base_move_ap_cost = CombatManager.move_ap_cost
		CombatManager.alert_threshold_reached.connect(_on_alert_threshold_reached)
		CombatManager.toxicity_threshold_reached.connect(_on_toxicity_threshold_reached)
	var run_controller := _get_run_controller()
	if run_controller:
		run_controller.run_state_changed.connect(_on_run_state_changed)
		run_controller.run_completed.connect(_on_run_completed)
	call_deferred("_post_scene_setup")

func _post_scene_setup() -> void:
	if use_procgen:
		_setup_procgen()
	_build_navigation()
	_build_astar_grid()
	var run_controller := _get_run_controller()
	if run_controller:
		run_controller.start_new_run()
		if auto_start_combat:
			run_controller.begin_encounter()
	elif auto_start_combat:
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

func _on_run_state_changed(new_state: int, _previous_state: int) -> void:
	if new_state == RUN_STATE_ENCOUNTER:
		_start_combat()
	elif new_state == RUN_STATE_EXTRACTION:
		print("Run state: Extraction ready.")
	elif new_state == RUN_STATE_RESULTS:
		print("Run state: Results.")

func _on_run_completed(success: bool, reason: String) -> void:
	var outcome := "SUCCESS" if success else "FAILED"
	print("Run completed: %s (%s)" % [outcome, reason])

func _on_alert_threshold_reached(_progress: int, threshold: int) -> void:
	if threshold == 5:
		_spawn_reinforcements(1)
	elif threshold == 8:
		_spawn_reinforcements(1)

func _on_toxicity_threshold_reached(_progress: int, threshold: int) -> void:
	if not CombatManager:
		return
	if threshold == 2 and not _toxicity_penalty_active:
		_toxicity_penalty_active = true
		CombatManager.move_ap_cost = _base_move_ap_cost + 1
		print("Pressure: Toxicity penalty active (+1 move AP cost).")
	elif threshold == 4:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("take_damage"):
			player.take_damage(2, self)
		CombatManager.toxicity_load.progress = 0
		_toxicity_penalty_active = false
		CombatManager.move_ap_cost = _base_move_ap_cost
		print("Pressure: Toxic burst triggered (2 damage), toxicity reset.")

func _spawn_reinforcements(count: int) -> void:
	var clamped_count := maxi(count, 0)
	if clamped_count == 0:
		return
	var player_pos: Vector2 = INVALID_POS
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D:
		var p3: Vector3 = (player as Node3D).global_position
		player_pos = Vector2(p3.x, p3.z)
	var existing_enemies := get_tree().get_nodes_in_group("enemy")
	var occupied: Array[Vector2] = []
	for enemy in existing_enemies:
		if enemy is Node3D:
			var ep: Vector3 = (enemy as Node3D).global_position
			occupied.append(Vector2(ep.x, ep.z))
	var spawned := 0
	for _i in range(clamped_count):
		var avoid := occupied.duplicate()
		if _is_valid_position(player_pos):
			avoid.append(player_pos)
		var pos: Vector2 = _pick_position(avoid, min_enemy_spacing, min_player_obstacle_spacing)
		if not _is_valid_position(pos):
			continue
		var enemy := ENEMY_SCENE.instantiate()
		add_child(enemy)
		if enemy is Node3D:
			(enemy as Node3D).global_position = Vector3(pos.x, 0, pos.y)
		occupied.append(pos)
		spawned += 1
		if CombatManager and CombatManager.active_combat:
			CombatManager.add_actor(enemy)
	if spawned > 0:
		print("Pressure: Reinforcements deployed (+%s)." % spawned)

func _get_run_controller() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	return tree.root.get_node_or_null("RunController")

func _build_navigation() -> void:
	# Navigation mesh not used — pathfinding is handled by AStarGrid2D.
	pass

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
			var filtered: Array[Node] = []
			var found := root.find_children("", "Area3D", true, false)
			for node in found:
				if node is Node and node.has_node("ElevationBlocker"):
					filtered.append(node)
			obstacles = filtered
	for obstacle in obstacles:
		var rect := _get_obstacle_rect_from_node(obstacle)
		if rect.size != Vector2.ZERO:
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


func _setup_procgen() -> void:
	_grid_origin = Vector2(-nav_bounds_size.x * 0.5, -nav_bounds_size.y * 0.5)
	_seed_rng()
	if debug_procgen:
		print("Procgen: seed=", procgen_seed, " margin=", procgen_margin, " buildings=", building_count_min, "-", building_count_max, " vents=", vent_count_min, "-", vent_count_max, " enemies=", enemy_count)
	_randomize_obstacles()
	_refresh_grid_overlay()
	_position_player()
	_spawn_enemies()
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
			var zone := obstacle as Node3D
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
		var zone := obstacle as Node3D
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
			zone.global_position = Vector3(placed.x, 0, placed.y)
			var new_rect := Rect2(placed - rect.size * 0.5, rect.size)
			placed_rects.append(new_rect)
		elif debug_procgen:
			print("Procgen: failed to place obstacle ", zone.name, " size=", rect.size)

func _refresh_grid_overlay() -> void:
	var grid := get_node_or_null("GridOverlay")
	if grid and grid.has_method("refresh"):
		grid.call("refresh")

func _randomize_steam_vents() -> void:
	var vents: Array[Node] = _get_steam_vents()
	if vents.is_empty():
		if debug_procgen:
			print("Procgen: no steam_vent nodes found.")
		return
	if debug_procgen:
		for vent in vents:
			var node := vent as Node3D
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
	if player is Node3D:
		var p3: Vector3 = (player as Node3D).global_position
		player_pos = Vector2(p3.x, p3.z)
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy is Node3D:
			var ep: Vector3 = (enemy as Node3D).global_position
			avoid_points.append(Vector2(ep.x, ep.z))
	var placed_vents: Array[Vector2] = []
	for vent in vents:
		var node := vent as Node3D
		if not node:
			continue
		var pos: Vector2 = _pick_vent_position(avoid_points, placed_vents, player_pos)
		if _is_valid_position(pos):
			if debug_procgen:
				print("Procgen: vent moved ", node.name, " to=", pos)
			node.global_position = Vector3(pos.x, 0, pos.y)
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
	var player_pos: Vector2 = INVALID_POS
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D:
		var p3: Vector3 = (player as Node3D).global_position
		player_pos = Vector2(p3.x, p3.z)
	for enemy in enemies:
		var node := enemy as Node3D
		if not node:
			continue
		var avoid: Array[Vector2] = placed.duplicate()
		if _is_valid_position(player_pos):
			avoid.append(player_pos)
		var pos: Vector2 = _pick_position(avoid, min_enemy_spacing, min_player_obstacle_spacing)
		if _is_valid_position(pos):
			node.global_position = Vector3(pos.x, 0, pos.y)
			placed.append(pos)

func _position_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var pos: Vector2 = _pick_position([], 0.0, min_player_obstacle_spacing)
	if _is_valid_position(pos):
		if player is Node3D:
			(player as Node3D).global_position = Vector3(pos.x, 0, pos.y)

func _try_place_rect(size: Vector2, placed_rects: Array[Rect2]) -> Vector2:
	var attempts: int = maxi(procgen_attempts, 10)
	for _i in range(attempts):
		var pos: Vector2 = _snap_to_grid(_random_position_in_bounds_for_size(size))
		var rect := Rect2(pos - size * 0.5, size)
		if _rects_overlap(rect, placed_rects, obstacle_spacing):
			continue
		return pos
	for _i in range(attempts):
		var pos_relaxed: Vector2 = _snap_to_grid(_random_position_in_bounds_for_size(size))
		var rect_relaxed := Rect2(pos_relaxed - size * 0.5, size)
		if _rects_overlap(rect_relaxed, placed_rects, 0.0):
			continue
		return pos_relaxed
	return INVALID_POS

func _rects_overlap(rect: Rect2, placed_rects: Array[Rect2], padding: float) -> bool:
	for existing in placed_rects:
		var expanded: Rect2 = existing.grow(padding)
		if expanded.intersects(rect):
			return true
	return false

func _pick_position(avoid_points: Array[Vector2] = [], min_spacing: float = 0.0, min_obstacle_spacing: float = 0.0) -> Vector2:
	var attempts: int = maxi(procgen_attempts, 10)
	var best_pos: Vector2 = INVALID_POS
	var best_score := -1.0
	for _i in range(attempts):
		var pos: Vector2 = _snap_to_grid(_random_position_in_bounds())
		if _is_point_inside_obstacle(pos):
			continue
		if min_obstacle_spacing > 0.0 and _is_near_obstacle(pos, min_obstacle_spacing):
			continue
		if min_spacing > 0.0 and _is_near_points(pos, avoid_points, min_spacing):
			continue
		return pos
	for _i in range(attempts):
		var pos_relaxed: Vector2 = _snap_to_grid(_random_position_in_bounds())
		if _is_point_inside_obstacle(pos_relaxed):
			continue
		var score := _score_position(pos_relaxed, avoid_points)
		if score > best_score:
			best_score = score
			best_pos = pos_relaxed
	return best_pos

func _random_position_in_bounds() -> Vector2:
	var half := nav_bounds_size * 0.5
	var min_x := -half.x + procgen_margin.x
	var max_x := half.x - procgen_margin.x
	var min_y := -half.y + procgen_margin.y
	var max_y := half.y - procgen_margin.y
	return Vector2(_rng.randf_range(min_x, max_x), _rng.randf_range(min_y, max_y))

func _random_position_in_bounds_for_size(size: Vector2) -> Vector2:
	var half := nav_bounds_size * 0.5
	var min_x := -half.x + procgen_margin.x + size.x * 0.5
	var max_x := half.x - procgen_margin.x - size.x * 0.5
	var min_y := -half.y + procgen_margin.y + size.y * 0.5
	var max_y := half.y - procgen_margin.y - size.y * 0.5
	if min_x > max_x:
		min_x = -half.x + procgen_margin.x
		max_x = half.x - procgen_margin.x
	if min_y > max_y:
		min_y = -half.y + procgen_margin.y
		max_y = half.y - procgen_margin.y
	return Vector2(_rng.randf_range(min_x, max_x), _rng.randf_range(min_y, max_y))

func _is_near_points(pos: Vector2, points: Array[Vector2], min_spacing: float) -> bool:
	for point in points:
		if pos.distance_to(point) < min_spacing:
			return true
	return false

func _is_valid_position(pos: Vector2) -> bool:
	return pos != INVALID_POS

func _snap_to_grid(pos: Vector2) -> Vector2:
	if grid_cell_size.x <= 0.0 or grid_cell_size.y <= 0.0:
		return pos
	var cell: Vector2i = _world_to_cell(pos)
	return _cell_to_world(cell)

func snap_to_grid(pos) -> Variant:
	if pos is Vector3:
		var snapped_2d := _snap_to_grid(Vector2(pos.x, pos.z))
		return Vector3(snapped_2d.x, pos.y, snapped_2d.y)
	return _snap_to_grid(pos)

func get_astar_path_3d(from_world: Vector3, to_world: Vector3) -> PackedVector3Array:
	var from_2d := Vector2(from_world.x, from_world.z)
	var to_2d := Vector2(to_world.x, to_world.z)
	var path_2d := get_astar_path(from_2d, to_2d)
	var path_3d := PackedVector3Array()
	for point in path_2d:
		path_3d.append(Vector3(point.x, 0, point.y))
	return path_3d

func _pick_vent_position(avoid_points: Array[Vector2], placed_vents: Array[Vector2], player_pos: Vector2) -> Vector2:
	var attempts: int = maxi(procgen_attempts, 10)
	var best_pos: Vector2 = INVALID_POS
	var best_score := -1.0
	for _i in range(attempts):
		var pos: Vector2 = _snap_to_grid(_random_position_in_bounds())
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
	for _i in range(attempts):
		var pos_relaxed: Vector2 = _snap_to_grid(_random_position_in_bounds())
		if _is_point_inside_obstacle(pos_relaxed):
			continue
		if _is_valid_position(player_pos) and pos_relaxed.distance_to(player_pos) < min_vent_player_spacing * 0.5:
			continue
		var score := _score_position(pos_relaxed, avoid_points, placed_vents, player_pos)
		if score > best_score:
			best_score = score
			best_pos = pos_relaxed
	return best_pos

func _score_position(pos: Vector2, avoid_points: Array[Vector2], extra_points: Array[Vector2] = [], player_pos: Vector2 = INVALID_POS) -> float:
	var avoid_score := _min_distance_to_points(pos, avoid_points)
	var extra_score := _min_distance_to_points(pos, extra_points)
	var player_score := 99999.0
	if _is_valid_position(player_pos):
		player_score = pos.distance_to(player_pos)
	var obstacle_score := _min_distance_to_obstacles(pos)
	var edge_score := _distance_to_bounds(pos)
	return min(min(min(avoid_score, extra_score), player_score), min(obstacle_score, edge_score))

func _min_distance_to_points(pos: Vector2, points: Array[Vector2]) -> float:
	if points.is_empty():
		return 99999.0
	var best := 99999.0
	for point in points:
		var dist := pos.distance_to(point)
		if dist < best:
			best = dist
	return best

func _min_distance_to_obstacles(pos: Vector2) -> float:
	var obstacles: Array[Node] = _get_nav_obstacles()
	var best := 99999.0
	for obstacle in obstacles:
		var rect := _get_obstacle_rect(obstacle)
		if rect.size == Vector2.ZERO:
			continue
		var dist := _distance_to_rect(pos, rect)
		if dist < best:
			best = dist
	return best

func _distance_to_rect(pos: Vector2, rect: Rect2) -> float:
	var clamped_x := clampf(pos.x, rect.position.x, rect.position.x + rect.size.x)
	var clamped_y := clampf(pos.y, rect.position.y, rect.position.y + rect.size.y)
	return pos.distance_to(Vector2(clamped_x, clamped_y))

func _distance_to_bounds(pos: Vector2) -> float:
	var half := nav_bounds_size * 0.5
	var min_x := -half.x + procgen_margin.x
	var max_x := half.x - procgen_margin.x
	var min_y := -half.y + procgen_margin.y
	var max_y := half.y - procgen_margin.y
	var dx: float = minf(pos.x - min_x, max_x - pos.x)
	var dy: float = minf(pos.y - min_y, max_y - pos.y)
	return minf(dx, dy)

func has_clear_los(from_pos: Vector3, to_pos: Vector3) -> bool:
	var a := Vector2(from_pos.x, from_pos.z)
	var b := Vector2(to_pos.x, to_pos.z)
	var obstacles: Array[Node] = _get_nav_obstacles()
	for obstacle in obstacles:
		var rect := _los_rect_for_obstacle(obstacle)
		if rect.size == Vector2.ZERO:
			continue
		if _segment_intersects_rect(a, b, rect):
			return false
	return true

func _los_rect_for_obstacle(obstacle: Node) -> Rect2:
	if not obstacle is Node3D:
		return Rect2()
	var node := obstacle as Node3D
	var center := Vector2(node.global_position.x, node.global_position.z)
	if "building_size" in node:
		var bs: Vector3 = node.building_size
		var size := Vector2(bs.x, bs.z)
		return Rect2(center - size * 0.5, size)
	return _get_obstacle_rect(obstacle)

func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var min_pt := rect.position
	var max_pt := rect.position + rect.size
	var d := b - a
	var t_min := 0.0
	var t_max := 1.0
	# Check X slab
	if abs(d.x) < 0.0001:
		if a.x < min_pt.x or a.x > max_pt.x:
			return false
	else:
		var inv_d := 1.0 / d.x
		var t1 := (min_pt.x - a.x) * inv_d
		var t2 := (max_pt.x - a.x) * inv_d
		if t1 > t2:
			var tmp := t1
			t1 = t2
			t2 = tmp
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return false
	# Check Y slab (Z in world space)
	if abs(d.y) < 0.0001:
		if a.y < min_pt.y or a.y > max_pt.y:
			return false
	else:
		var inv_d := 1.0 / d.y
		var t1 := (min_pt.y - a.y) * inv_d
		var t2 := (max_pt.y - a.y) * inv_d
		if t1 > t2:
			var tmp := t1
			t1 = t2
			t2 = tmp
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return false
	return true

func _is_point_inside_obstacle(pos: Vector2) -> bool:
	var obstacles: Array[Node] = _get_nav_obstacles()
	for obstacle in obstacles:
		var rect := _get_obstacle_rect(obstacle)
		if rect.size != Vector2.ZERO and rect.has_point(pos):
			return true
	return false

func _is_near_obstacle(pos: Vector2, min_spacing: float) -> bool:
	var obstacles: Array[Node] = _get_nav_obstacles()
	for obstacle in obstacles:
		var rect := _get_obstacle_rect(obstacle)
		if rect.size == Vector2.ZERO:
			continue
		if rect.grow(min_spacing).has_point(pos):
			return true
	return false

func _get_obstacle_rect(zone: Node) -> Rect2:
	return _get_obstacle_rect_from_node(zone)

func _get_obstacle_rect_from_node(zone: Node) -> Rect2:
	# Read directly from node properties (reliable after procgen moves)
	if zone is Node3D and "building_size" in zone:
		var node := zone as Node3D
		var center := Vector2(node.global_position.x, node.global_position.z)
		var bs: Vector3 = zone.building_size
		var size := Vector2(bs.x, bs.z)
		return Rect2(center - size * 0.5, size)
	# Fallback: read from collision shape child
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
			var found := root.find_children("", "Area3D", true, false)
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
			var found := root.find_children("", "Area3D", true, false)
			for node in found:
				if node is Node and node.get_script() == STEAM_VENT_SCRIPT:
					typed.append(node)
	return typed
