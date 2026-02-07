extends AIState

var _moved: bool = false
var _executing_turn: bool = false
var _planned_target: Vector3 = Vector3.INF
var _current_position_key: String = ""
var _previous_position_key: String = ""
var _oscillation_count: int = 0
var debug_enabled: bool = false

func enter(_owner: Node) -> void:
	_moved = false
	_executing_turn = false
	_reset_turn_navigation_state()

func on_turn_started(_owner: Node) -> void:
	_moved = false
	_executing_turn = false
	_reset_turn_navigation_state()

func tick(owner: Node, _delta: float) -> void:
	if _moved:
		return
	if _executing_turn:
		return
	if not owner.has_method("get_ai"):
		return
	var ai = owner.get_ai()
	if not ai:
		return
	var player = ai.get_player()
	if not player:
		_moved = true
		_end_turn(owner)
		return
	_executing_turn = true
	_run_enemy_turn(owner, ai, player)

func _run_enemy_turn(owner: Node, ai: Node, player: Node) -> void:
	var attack_range := 0.0
	if owner.has_method("get_ranged_attack_range"):
		attack_range = float(owner.get_ranged_attack_range())
	elif owner.has_method("can_attack_ranged"):
		attack_range = 0.0
	var ap_budget := 0
	if owner.has_method("get_max_ap"):
		ap_budget = int(floor(owner.get_max_ap() * 0.5))
	var max_steps := 12
	var steps_taken := 0
	_current_position_key = _position_key(owner.global_position)
	while steps_taken < max_steps and ap_budget > 0 and _is_turn_still_valid(owner, player):
		var shot_profile := _get_shot_profile(owner, player)
		var attack_blocked := bool(shot_profile.get("attack_blocked", false))
		var in_partial_cover := bool(shot_profile.get("self_partial_cover", false))
		var in_range := false
		if owner.has_method("can_attack_ranged"):
			in_range = owner.can_attack_ranged(player)
		elif attack_range > 0.0:
			in_range = owner.global_position.distance_to(player.global_position) <= attack_range
		if in_range:
			var should_attack := (not attack_blocked) and in_partial_cover
			if not should_attack:
				var can_move_to_fire := await _attempt_tactical_move(owner, player, ai, _oscillation_count > 0)
				if not can_move_to_fire:
					_debug(owner, "Could not reposition to firing cover; ending action loop.")
					break
				steps_taken += 1
				await _pause(owner, 0.06)
				continue
			var can_attack := true
			if CombatManager:
				var ap_cost := CombatManager.get_ap_cost("attack")
				if ap_cost > ap_budget:
					can_attack = false
				if owner.has_method("spend_ap"):
					can_attack = owner.spend_ap(ap_cost)
				if can_attack:
					ap_budget -= ap_cost
			if can_attack and owner.has_method("ranged_attack"):
				_debug(owner, "Attack action (partial cover=%s, blocked=%s)." % [in_partial_cover, attack_blocked])
				if owner.has_method("ranged_attack_async"):
					await owner.ranged_attack_async(player)
				else:
					owner.ranged_attack(player)
					await _pause(owner, 0.12)
				steps_taken += 1
				continue
			break
		var can_move := true
		if CombatManager:
			var move_cost := CombatManager.get_ap_cost("move")
			if move_cost > ap_budget:
				can_move = false
			if owner.has_method("spend_ap"):
				can_move = owner.spend_ap(move_cost)
			if can_move:
				ap_budget -= move_cost
		if not can_move:
			_debug(owner, "Cannot move: AP budget insufficient.")
			break
		if owner.has_method("move_towards"):
			var moved := await _attempt_tactical_move(owner, player, ai, _oscillation_count > 0)
			if not moved:
				_debug(owner, "Move attempt failed; ending action loop.")
				break
		steps_taken += 1
		await _pause(owner, 0.05)
	_moved = true
	_executing_turn = false
	_end_turn(owner)

func _end_turn(owner: Node) -> void:
	if owner.has_method("end_turn"):
		owner.end_turn()

func _pause(owner: Node, duration: float) -> void:
	var tree := owner.get_tree() if owner else null
	if tree == null:
		return
	await tree.create_timer(maxf(duration, 0.0)).timeout

func _is_turn_still_valid(owner: Node, player: Node) -> bool:
	if owner == null or player == null:
		return false
	if CombatManager == null or not CombatManager.active_combat:
		return false
	if CombatManager.get_current_actor() != owner:
		return false
	if owner.has_method("get_current_hp") and owner.get_current_hp() <= 0:
		return false
	if player.has_method("get_current_hp") and player.get_current_hp() <= 0:
		return false
	return true

func _attempt_tactical_move(owner: Node, player: Node, ai: Node, force_direct: bool = false) -> bool:
	var move_target: Vector3 = player.global_position
	var world := owner.get_tree().current_scene if owner else null
	if not force_direct:
		if _is_target_reached(owner.global_position, _planned_target):
			_planned_target = Vector3.INF
		if _planned_target == Vector3.INF and world and world.has_method("find_tactical_cover_position"):
			var max_path_steps := maxi(int(round(ai.step_distance / 8.0)), 3)
			var best_pos: Variant = world.find_tactical_cover_position(owner.global_position, player.global_position, max_path_steps)
			if best_pos != Vector3.INF:
				_planned_target = best_pos as Vector3
				_debug(owner, "Committed tactical target %s" % str(_planned_target))
		if _planned_target != Vector3.INF:
			move_target = _planned_target
		else:
			move_target = player.global_position
	else:
		_planned_target = Vector3.INF
		_debug(owner, "Forced direct move due oscillation.")
	if owner.has_method("move_towards_async"):
		var moved_async: bool = await owner.move_towards_async(move_target, ai.step_distance)
		if moved_async:
			_update_position_state(owner.global_position)
		else:
			_debug(owner, "move_towards_async returned false for target %s" % str(move_target))
		return moved_async
	if owner.has_method("move_towards"):
		owner.move_towards(move_target, ai.step_distance)
		await _pause(owner, 0.08)
		_update_position_state(owner.global_position)
		return true
	return false

func _get_shot_profile(owner: Node, player: Node) -> Dictionary:
	var profile := {
		"attack_blocked": false,
		"self_partial_cover": false,
		"self_full_cover": false
	}
	var world := owner.get_tree().current_scene if owner else null
	if world == null or not world.has_method("get_shot_resolution"):
		return profile
	var attack_resolution: Dictionary = world.get_shot_resolution(owner.global_position, player.global_position)
	profile.attack_blocked = bool(attack_resolution.get("blocked", false))
	var defense_resolution: Dictionary = world.get_shot_resolution(player.global_position, owner.global_position)
	var blocked := bool(defense_resolution.get("blocked", false))
	var multiplier := float(defense_resolution.get("damage_multiplier", 1.0))
	profile.self_full_cover = blocked
	profile.self_partial_cover = (not blocked) and multiplier < 1.0
	return profile

func _reset_turn_navigation_state() -> void:
	_planned_target = Vector3.INF
	_current_position_key = ""
	_previous_position_key = ""
	_oscillation_count = 0

func _position_key(pos: Vector3) -> String:
	var cell_x := int(round(pos.x / 8.0))
	var cell_z := int(round(pos.z / 8.0))
	return "%s:%s" % [cell_x, cell_z]

func _update_position_state(world_pos: Vector3) -> void:
	var new_key := _position_key(world_pos)
	if _previous_position_key == new_key:
		_oscillation_count += 1
	else:
		_oscillation_count = 0
	_previous_position_key = _current_position_key
	_current_position_key = new_key
	if _oscillation_count >= 1:
		# Drop tactical commitment when we bounce between two tiles.
		_planned_target = Vector3.INF
		_debug(null, "Oscillation detected; clearing planned target.")

func _is_target_reached(current_pos: Vector3, target: Vector3) -> bool:
	if target == Vector3.INF:
		return false
	return current_pos.distance_to(target) <= 4.0

func _debug(owner: Node, message: String) -> void:
	if not debug_enabled:
		return
	var who: String = owner.name if owner else "EnemyAI"
	print("[AI][", who, "] ", message)
