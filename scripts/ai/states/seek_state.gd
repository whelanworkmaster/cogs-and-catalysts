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
	if owner.has_method("move_towards"):
		owner.move_towards(player.global_position, ai.step_distance)
	_moved = true
	_end_turn(owner)

func _end_turn(owner: Node) -> void:
	if owner.has_method("end_turn"):
		owner.end_turn()
