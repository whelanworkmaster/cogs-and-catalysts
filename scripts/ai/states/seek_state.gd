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
	var distance: float = owner.global_position.distance_to(player.global_position)
	var attack_distance: float = 0.0
	if owner.has_method("get_attack_contact_distance"):
		attack_distance = owner.get_attack_contact_distance()
	if attack_distance > 0.0 and distance <= attack_distance:
		if owner.has_method("attack"):
			owner.attack(player)
			print("Enemy attack for contact distance ", attack_distance)
		_moved = true
		_end_turn(owner)
		return
	if owner.has_method("move_towards"):
		owner.move_towards(player.global_position, ai.step_distance)
		print("Enemy move toward player.")
	_moved = true
	_end_turn(owner)

func _end_turn(owner: Node) -> void:
	if owner.has_method("end_turn"):
		owner.end_turn()
