extends AIState

var _moved: bool = false

func enter(_owner: Node) -> void:
	_moved = false

func on_turn_started(_owner: Node) -> void:
	_moved = false

func tick(owner: Node, _delta: float) -> void:
	if _moved:
		return
	if not owner.has_method("get_ai"):
		return
	var ai = owner.get_ai()
	if not ai:
		return
	var player = ai.get_player()
	if not player:
		_end_turn(owner)
		return
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
	while steps_taken < max_steps and ap_budget > 0:
		var in_range := false
		if owner.has_method("can_attack_ranged"):
			in_range = owner.can_attack_ranged(player)
		elif attack_range > 0.0:
			in_range = owner.global_position.distance_to(player.global_position) <= attack_range
		if in_range:
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
				owner.ranged_attack(player)
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
			break
		if owner.has_method("move_towards"):
			owner.move_towards(player.global_position, ai.step_distance)
		steps_taken += 1
	_moved = true
	_end_turn(owner)

func _end_turn(owner: Node) -> void:
	if owner.has_method("end_turn"):
		owner.end_turn()
